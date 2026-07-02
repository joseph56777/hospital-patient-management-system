-- ============================================================================
-- 05_CRUD_Joins_Aggregations_Demo.sql
-- Hospital Patient Management System
-- CRUD, joins, business reports, and JSON-document queries
--
-- This file is written for the project demonstration. Run each section and use
-- the output to explain how the database answers real hospital questions.
-- ============================================================================

USE hospital_db;

-- Safe demo reset: this allows the demonstration file to be run again without
-- duplicate patient, appointment, billing, note, or lab-result errors.
SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM lab_results
WHERE patient_id IN (1201, 1202)
   OR lab_id = 'lab_demo01';
DELETE FROM clinical_notes
WHERE patient_id IN (1201, 1202)
   OR note_id LIKE 'note_app_%';
DELETE FROM billing
WHERE patient_id IN (1201, 1202)
   OR appointment_id IN (9002, 9003)
   OR appointment_id IN (
        SELECT appointment_id
        FROM appointments
        WHERE patient_id IN (1201, 1202)
   );
DELETE FROM appointments
WHERE patient_id IN (1201, 1202)
   OR appointment_id IN (9002, 9003);
DELETE FROM patients
WHERE patient_id IN (1201, 1202);
SET FOREIGN_KEY_CHECKS = 1;


-- ----------------------------------------------------------------------------
-- 1. Quick project readiness check
-- ----------------------------------------------------------------------------

CALL sp_project_quality_check();

SELECT *
FROM v_document_store_summary;

-- ----------------------------------------------------------------------------
-- 2. Basic read queries
-- ----------------------------------------------------------------------------
-- These show how relational tables are joined into useful information.

SELECT *
FROM v_patient_timeline
ORDER BY appointment_date DESC, appointment_time DESC
LIMIT 20;

SELECT *
FROM v_department_performance
ORDER BY revenue_eur DESC, appointments DESC
LIMIT 15;

-- ----------------------------------------------------------------------------
-- 3. CRUD demonstration using the SQL application layer
-- ----------------------------------------------------------------------------
-- The demo patient is cleaned up in file 06, so the main dataset stays tidy.

START TRANSACTION;

    INSERT INTO patients (
        patient_id, first_name, last_name, date_of_birth, gender,
        phone, email, address, blood_type, insurance_provider, registration_date
    )
    VALUES (
        1201, 'Demo', 'Patient', '1998-04-12', 'Male',
        '+49-30-000000', 'demo.patient1201@example.com',
        'Training Street 12, Berlin', 'O+', 'TK', CURRENT_DATE
    );

    CALL sp_book_appointment(
        1201,
        5,
        DATE_ADD(CURRENT_DATE, INTERVAL 7 DAY),
        '09:30:00',
        'Demo consultation for M605 project walkthrough',
        @demo_appointment_id
    );

COMMIT;

SELECT @demo_appointment_id AS created_appointment_id;

CALL sp_complete_visit(@demo_appointment_id, 145.00, 'Insurance');

CALL sp_save_clinical_note(
    @demo_appointment_id,
    'Patient reports mild headache and requests a routine review.',
    '118/76',
    72,
    1,
    4,
    'No emergency signs. Follow-up is recommended after four weeks.'
);

CALL sp_save_lab_result(
    'lab_demo01',
    @demo_appointment_id,
    'Blood Test',
    'Normal - Reviewed',
    'No critical abnormality detected in the demo test.',
    '{"hemoglobin": 13.8, "wbc": 7.4, "platelets": 250}'
);

-- READ after CREATE: this is the clean patient 360 output.
CALL sp_patient_360_profile(1201);

-- UPDATE relational data.
UPDATE patients
SET phone = '+49-30-111111'
WHERE patient_id = 1201;

-- UPDATE a JSON field inside the clinical document.
UPDATE clinical_notes
SET document = JSON_SET(
    document,
    '$.doctor_comment', 'Symptoms are stable. Patient was advised about hydration and rest.',
    '$.follow_up_weeks', 2
)
WHERE note_id = CONCAT('note_app_', @demo_appointment_id);

-- READ after UPDATE.
SELECT
    note_id,
    JSON_UNQUOTE(JSON_EXTRACT(document, '$.subjective')) AS subjective,
    JSON_UNQUOTE(JSON_EXTRACT(document, '$.doctor_comment')) AS updated_comment,
    JSON_UNQUOTE(JSON_EXTRACT(document, '$.follow_up_weeks')) AS follow_up_weeks
FROM clinical_notes
WHERE note_id = CONCAT('note_app_', @demo_appointment_id);

-- ----------------------------------------------------------------------------
-- 4. Advanced relational queries
-- ----------------------------------------------------------------------------

-- 4.1 Top patients by billed amount.
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    p.insurance_provider,
    COUNT(DISTINCT a.appointment_id) AS appointments,
    ROUND(SUM(b.amount_eur), 2) AS total_billed_eur
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN billing b ON b.appointment_id = a.appointment_id
GROUP BY p.patient_id, patient_name, p.insurance_provider
ORDER BY total_billed_eur DESC
LIMIT 15;

-- 4.2 Doctor workload and completion rate.
SELECT
    d.doctor_id,
    CONCAT(d.first_name, ' ', d.last_name) AS doctor_name,
    dep.department_name,
    COUNT(a.appointment_id) AS total_appointments,
    ROUND(100 * AVG(a.status = 'Completed'), 2) AS completed_pct,
    ROUND(COALESCE(SUM(b.amount_eur), 0), 2) AS revenue_eur
FROM doctors d
JOIN departments dep ON dep.department_id = d.department_id
LEFT JOIN appointments a ON a.doctor_id = d.doctor_id
LEFT JOIN billing b ON b.appointment_id = a.appointment_id
GROUP BY d.doctor_id, doctor_name, dep.department_name
ORDER BY total_appointments DESC, revenue_eur DESC
LIMIT 20;

-- 4.3 Monthly appointment trend.
SELECT
    DATE_FORMAT(appointment_date, '%Y-%m') AS appointment_month,
    COUNT(*) AS appointments,
    SUM(status = 'Completed') AS completed,
    SUM(status = 'Cancelled') AS cancelled,
    SUM(status = 'No-show') AS no_show
FROM appointments
GROUP BY DATE_FORMAT(appointment_date, '%Y-%m')
ORDER BY appointment_month
LIMIT 24;

-- ----------------------------------------------------------------------------
-- 5. NoSQL/document-style JSON queries written in SQL
-- ----------------------------------------------------------------------------

-- 5.1 Patients requiring clinical follow-up.
SELECT *
FROM v_clinical_follow_up_queue
ORDER BY visit_date DESC
LIMIT 15;

-- 5.2 Abnormal or pending lab results. This uses the JSON path directly,
-- so it still runs even if the generated-column index file has not been run yet.
SELECT
    lr.lab_id,
    lr.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    lr.test_type,
    lr.test_date,
    JSON_UNQUOTE(JSON_EXTRACT(lr.document, '$.status')) AS lab_status,
    JSON_UNQUOTE(JSON_EXTRACT(lr.document, '$.findings')) AS findings
FROM lab_results lr
JOIN patients p ON p.patient_id = lr.patient_id
WHERE JSON_UNQUOTE(JSON_EXTRACT(lr.document, '$.status')) IN ('Abnormal - Reviewed', 'Pending Review')
ORDER BY lr.test_date DESC
LIMIT 15;

-- 5.3 Average heart rate from JSON vitals. The CAST is written directly from
-- JSON so the query remains safe even before generated columns are added.
SELECT
    COUNT(*) AS notes_with_heart_rate,
    ROUND(AVG(CAST(JSON_UNQUOTE(JSON_EXTRACT(document, '$.vitals.heart_rate_bpm')) AS UNSIGNED)), 1) AS average_heart_rate,
    MIN(CAST(JSON_UNQUOTE(JSON_EXTRACT(document, '$.vitals.heart_rate_bpm')) AS UNSIGNED)) AS min_heart_rate,
    MAX(CAST(JSON_UNQUOTE(JSON_EXTRACT(document, '$.vitals.heart_rate_bpm')) AS UNSIGNED)) AS max_heart_rate
FROM clinical_notes
WHERE JSON_EXTRACT(document, '$.vitals.heart_rate_bpm') IS NOT NULL;

-- 5.4 Medication records where the JSON medications array contains three or more items.
SELECT
    tr.treatment_id,
    tr.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    JSON_LENGTH(JSON_EXTRACT(tr.document, '$.medications')) AS medication_count,
    JSON_EXTRACT(tr.document, '$.medications') AS medications
FROM treatment_records tr
JOIN patients p ON p.patient_id = tr.patient_id
WHERE tr.treatment_type = 'Medication'
  AND JSON_LENGTH(JSON_EXTRACT(tr.document, '$.medications')) >= 3
LIMIT 10;

-- 5.5 Lab result aggregation by test type and JSON status.
SELECT
    test_type,
    JSON_UNQUOTE(JSON_EXTRACT(document, '$.status')) AS lab_status,
    COUNT(*) AS total_results
FROM lab_results
GROUP BY test_type, JSON_UNQUOTE(JSON_EXTRACT(document, '$.status'))
ORDER BY test_type, total_results DESC;

-- ----------------------------------------------------------------------------
-- 6. Performance checks
-- ----------------------------------------------------------------------------
-- EXPLAIN statements show that the project considers index usage.

EXPLAIN SELECT *
FROM appointments
WHERE doctor_id = 5
  AND appointment_date >= CURRENT_DATE;

EXPLAIN SELECT *
FROM clinical_notes
WHERE follow_up_required = 1;

EXPLAIN SELECT *
FROM lab_results
WHERE lab_status = 'Abnormal - Reviewed';
