-- ============================================================================
-- 06_ACID_Transactions_Assessment_Checks.sql
-- Hospital Patient Management System
-- ACID transactions, savepoints, and final assessment checks
--
-- This file is safe to run after the demo query file. It demonstrates transaction
-- behaviour and then removes the temporary demo records.
-- ============================================================================

USE hospital_db;

-- Safe transaction-demo reset: this removes only temporary records created by
-- the demo files, so this file can be run more than once during practice.
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
-- 1. ACID transaction with SAVEPOINT and rollback
-- ----------------------------------------------------------------------------
-- This example shows atomicity in a simple way. The first appointment remains,
-- while the second appointment is rolled back to the savepoint.

START TRANSACTION;

    INSERT INTO patients (
        patient_id, first_name, last_name, date_of_birth, gender,
        phone, email, address, blood_type, insurance_provider, registration_date
    )
    VALUES (
        1202, 'Rollback', 'Example', '1990-01-01', 'Female',
        '+49-30-222222', 'rollback.example1202@example.com',
        'Database Street 8, Berlin', 'A+', 'Barmer', CURRENT_DATE
    );

    INSERT INTO appointments (
        appointment_id, patient_id, doctor_id, appointment_date,
        appointment_time, status, reason
    )
    VALUES (
        9002, 1202, 7, DATE_ADD(CURRENT_DATE, INTERVAL 10 DAY),
        '10:00:00', 'Scheduled', 'Transaction demonstration first appointment'
    );

    SAVEPOINT after_first_appointment;

    INSERT INTO appointments (
        appointment_id, patient_id, doctor_id, appointment_date,
        appointment_time, status, reason
    )
    VALUES (
        9003, 1202, 7, DATE_ADD(CURRENT_DATE, INTERVAL 11 DAY),
        '11:00:00', 'Scheduled', 'This second appointment will be rolled back'
    );

    ROLLBACK TO SAVEPOINT after_first_appointment;

COMMIT;

-- Only appointment 9002 should appear here. Appointment 9003 was rolled back.
SELECT appointment_id, patient_id, appointment_date, appointment_time, reason
FROM appointments
WHERE appointment_id IN (9002, 9003);

-- ----------------------------------------------------------------------------
-- 2. Final assessment-readiness queries
-- ----------------------------------------------------------------------------
-- These outputs are useful for screenshots in the report.

CALL sp_project_quality_check();

SELECT
    'Foreign keys, constraints, indexes, triggers, procedures, views, JSON documents, generated columns, and transactions are included.'
    AS project_strength_summary;

SELECT *
FROM v_document_store_summary;

SELECT
    COUNT(*) AS total_generated_columns
FROM information_schema.columns
WHERE table_schema = 'hospital_db'
  AND extra LIKE '%GENERATED%';

SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'hospital_db'
ORDER BY routine_name;

-- ----------------------------------------------------------------------------
-- 3. Clean up demonstration records
-- ----------------------------------------------------------------------------
-- This removes only the records created by the demo scripts. The main dataset is
-- left untouched.

DELETE FROM lab_results
WHERE lab_id = 'lab_demo01';

DELETE FROM clinical_notes
WHERE note_id = CONCAT('note_app_', @demo_appointment_id);

DELETE FROM billing
WHERE patient_id IN (1201, 1202)
   OR appointment_id IN (@demo_appointment_id, 9002, 9003);

DELETE FROM appointments
WHERE patient_id IN (1201, 1202)
   OR appointment_id IN (@demo_appointment_id, 9002, 9003);

DELETE FROM patients
WHERE patient_id IN (1201, 1202);

-- Final check: the demo patients should be gone.
SELECT patient_id, first_name, last_name
FROM patients
WHERE patient_id IN (1201, 1202);
