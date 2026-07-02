-- ============================================================================
-- 04_Integrity_Indexes_Optimization.sql
-- Hospital Patient Management System
-- Triggers, indexes, generated columns, and integration views
--
-- This file turns the database from a simple schema into a stronger advanced
-- database project. It adds protection for future changes, indexes important
-- access paths, and creates views that join relational data with JSON documents.
--
-- Run this file after 03_Application_Layer_Using_SQL_Procedures.sql.
-- ============================================================================

USE hospital_db;

DELIMITER $$

-- ----------------------------------------------------------------------------
-- 1. Data quality triggers
-- ----------------------------------------------------------------------------
-- Some validation is better placed in triggers than CHECK constraints. For
-- example, CURRENT_DATE is not always suitable inside a CHECK constraint, so the
-- date-of-birth rule is handled here.

DROP TRIGGER IF EXISTS trg_patients_dob_insert$$
CREATE TRIGGER trg_patients_dob_insert
BEFORE INSERT ON patients
FOR EACH ROW
BEGIN
    IF NEW.date_of_birth > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'date_of_birth cannot be in the future';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_patients_dob_update$$
CREATE TRIGGER trg_patients_dob_update
BEFORE UPDATE ON patients
FOR EACH ROW
BEGIN
    IF NEW.date_of_birth > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'date_of_birth cannot be in the future';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_billing_only_completed_appointments$$
CREATE TRIGGER trg_billing_only_completed_appointments
BEFORE INSERT ON billing
FOR EACH ROW
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM appointments a
        WHERE a.appointment_id = NEW.appointment_id
          AND a.patient_id = NEW.patient_id
          AND a.status = 'Completed'
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'billing can only be created for a completed appointment belonging to the same patient';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_clinical_note_requires_subjective$$
CREATE TRIGGER trg_clinical_note_requires_subjective
BEFORE INSERT ON clinical_notes
FOR EACH ROW
BEGIN
    IF JSON_EXTRACT(NEW.document, '$.subjective') IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'clinical note document must contain a subjective field';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_lab_result_requires_status$$
CREATE TRIGGER trg_lab_result_requires_status
BEFORE INSERT ON lab_results
FOR EACH ROW
BEGIN
    IF JSON_EXTRACT(NEW.document, '$.status') IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'lab result document must contain a status field';
    END IF;
END$$

DELIMITER ;

-- ----------------------------------------------------------------------------
-- 2. Relational indexes
-- ----------------------------------------------------------------------------
-- These helper procedures make the file safe to run more than once. They check
-- the information_schema first, so an index or generated column is added only
-- when it is missing.

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_add_index_if_missing$$
CREATE PROCEDURE sp_add_index_if_missing(
    IN p_table_name VARCHAR(64),
    IN p_index_name VARCHAR(64),
    IN p_create_sql TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = p_table_name
          AND index_name = p_index_name
    ) THEN
        SET @create_index_sql = p_create_sql;
        PREPARE stmt FROM @create_index_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DROP PROCEDURE IF EXISTS sp_add_column_if_missing$$
CREATE PROCEDURE sp_add_column_if_missing(
    IN p_table_name VARCHAR(64),
    IN p_column_name VARCHAR(64),
    IN p_create_sql TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = DATABASE()
          AND table_name = p_table_name
          AND column_name = p_column_name
    ) THEN
        SET @create_column_sql = p_create_sql;
        PREPARE stmt FROM @create_column_sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END IF;
END$$

DELIMITER ;

CALL sp_add_index_if_missing('doctors', 'idx_doctors_department',
    'CREATE INDEX idx_doctors_department ON doctors(department_id)');
CALL sp_add_index_if_missing('patients', 'idx_patients_insurance',
    'CREATE INDEX idx_patients_insurance ON patients(insurance_provider)');
CALL sp_add_index_if_missing('appointments', 'idx_appointments_patient',
    'CREATE INDEX idx_appointments_patient ON appointments(patient_id)');
CALL sp_add_index_if_missing('appointments', 'idx_appointments_doctor',
    'CREATE INDEX idx_appointments_doctor ON appointments(doctor_id)');
CALL sp_add_index_if_missing('appointments', 'idx_appointments_date',
    'CREATE INDEX idx_appointments_date ON appointments(appointment_date)');
CALL sp_add_index_if_missing('appointments', 'idx_appointments_status',
    'CREATE INDEX idx_appointments_status ON appointments(status)');
CALL sp_add_index_if_missing('billing', 'idx_billing_patient',
    'CREATE INDEX idx_billing_patient ON billing(patient_id)');
CALL sp_add_index_if_missing('billing', 'idx_billing_status',
    'CREATE INDEX idx_billing_status ON billing(payment_status)');
CALL sp_add_index_if_missing('clinical_notes', 'idx_notes_patient_visit',
    'CREATE INDEX idx_notes_patient_visit ON clinical_notes(patient_id, visit_date)');
CALL sp_add_index_if_missing('treatment_records', 'idx_treatments_patient',
    'CREATE INDEX idx_treatments_patient ON treatment_records(patient_id)');
CALL sp_add_index_if_missing('lab_results', 'idx_labs_patient_testdate',
    'CREATE INDEX idx_labs_patient_testdate ON lab_results(patient_id, test_date)');
CALL sp_add_index_if_missing('lab_results', 'idx_labs_test_type',
    'CREATE INDEX idx_labs_test_type ON lab_results(test_type)');

-- ----------------------------------------------------------------------------
-- 3. JSON generated columns and JSON indexes
-- ----------------------------------------------------------------------------
-- This is the performance bridge between SQL and document-style data. The JSON
-- document remains flexible, but important values are extracted into generated
-- columns so MySQL can index them.

CALL sp_add_column_if_missing('clinical_notes', 'follow_up_required',
    'ALTER TABLE clinical_notes ADD COLUMN follow_up_required TINYINT(1) GENERATED ALWAYS AS (IF(JSON_UNQUOTE(JSON_EXTRACT(document, ''$.follow_up_required'')) = ''true'', 1, 0)) STORED');
CALL sp_add_column_if_missing('clinical_notes', 'heart_rate_bpm',
    'ALTER TABLE clinical_notes ADD COLUMN heart_rate_bpm INT GENERATED ALWAYS AS (CAST(JSON_UNQUOTE(JSON_EXTRACT(document, ''$.vitals.heart_rate_bpm'')) AS UNSIGNED)) STORED');
CALL sp_add_column_if_missing('lab_results', 'lab_status',
    'ALTER TABLE lab_results ADD COLUMN lab_status VARCHAR(40) GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(document, ''$.status''))) STORED');
CALL sp_add_column_if_missing('treatment_records', 'treatment_status',
    'ALTER TABLE treatment_records ADD COLUMN treatment_status VARCHAR(40) GENERATED ALWAYS AS (JSON_UNQUOTE(JSON_EXTRACT(document, ''$.status''))) STORED');

CALL sp_add_index_if_missing('clinical_notes', 'idx_notes_follow_up',
    'CREATE INDEX idx_notes_follow_up ON clinical_notes(follow_up_required)');
CALL sp_add_index_if_missing('clinical_notes', 'idx_notes_heart_rate',
    'CREATE INDEX idx_notes_heart_rate ON clinical_notes(heart_rate_bpm)');
CALL sp_add_index_if_missing('lab_results', 'idx_labs_status',
    'CREATE INDEX idx_labs_status ON lab_results(lab_status)');
CALL sp_add_index_if_missing('treatment_records', 'idx_treatments_status',
    'CREATE INDEX idx_treatments_status ON treatment_records(treatment_status)');

DROP PROCEDURE IF EXISTS sp_add_index_if_missing;
DROP PROCEDURE IF EXISTS sp_add_column_if_missing;

-- ----------------------------------------------------------------------------
-- 4. Integration views
-- ----------------------------------------------------------------------------
-- These views are useful in the demo because they make the system feel like a
-- complete hospital database rather than separate isolated tables.

CREATE OR REPLACE VIEW v_patient_timeline AS
SELECT
    p.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    a.appointment_id,
    a.appointment_date,
    a.appointment_time,
    a.status AS appointment_status,
    a.reason,
    CONCAT(d.first_name, ' ', d.last_name) AS doctor_name,
    dep.department_name,
    b.amount_eur,
    b.payment_status
FROM patients p
JOIN appointments a ON a.patient_id = p.patient_id
JOIN doctors d ON d.doctor_id = a.doctor_id
JOIN departments dep ON dep.department_id = d.department_id
LEFT JOIN billing b ON b.appointment_id = a.appointment_id;

CREATE OR REPLACE VIEW v_clinical_follow_up_queue AS
SELECT
    cn.note_id,
    cn.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    cn.visit_date,
    CONCAT(d.first_name, ' ', d.last_name) AS doctor_name,
    JSON_UNQUOTE(JSON_EXTRACT(cn.document, '$.vitals.blood_pressure')) AS blood_pressure,
    cn.heart_rate_bpm,
    JSON_UNQUOTE(JSON_EXTRACT(cn.document, '$.follow_up_weeks')) AS follow_up_weeks,
    JSON_UNQUOTE(JSON_EXTRACT(cn.document, '$.doctor_comment')) AS doctor_comment
FROM clinical_notes cn
JOIN patients p ON p.patient_id = cn.patient_id
JOIN doctors d ON d.doctor_id = cn.doctor_id
WHERE cn.follow_up_required = 1;

CREATE OR REPLACE VIEW v_lab_risk_summary AS
SELECT
    lr.lab_id,
    lr.patient_id,
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    lr.test_type,
    lr.test_date,
    lr.lab_status,
    JSON_UNQUOTE(JSON_EXTRACT(lr.document, '$.findings')) AS findings
FROM lab_results lr
JOIN patients p ON p.patient_id = lr.patient_id;

CREATE OR REPLACE VIEW v_department_performance AS
SELECT
    dep.department_id,
    dep.department_name,
    COUNT(DISTINCT d.doctor_id) AS doctors,
    COUNT(DISTINCT a.appointment_id) AS appointments,
    SUM(CASE WHEN a.status = 'Completed' THEN 1 ELSE 0 END) AS completed_appointments,
    SUM(CASE WHEN a.status = 'No-show' THEN 1 ELSE 0 END) AS no_show_appointments,
    ROUND(COALESCE(SUM(b.amount_eur), 0), 2) AS revenue_eur
FROM departments dep
LEFT JOIN doctors d ON d.department_id = dep.department_id
LEFT JOIN appointments a ON a.doctor_id = d.doctor_id
LEFT JOIN billing b ON b.appointment_id = a.appointment_id
GROUP BY dep.department_id, dep.department_name;

CREATE OR REPLACE VIEW v_document_store_summary AS
SELECT
    c.collection_name,
    c.business_reason,
    c.modelling_choice,
    CASE c.collection_name
        WHEN 'clinical_notes' THEN (SELECT COUNT(*) FROM clinical_notes)
        WHEN 'treatment_records' THEN (SELECT COUNT(*) FROM treatment_records)
        WHEN 'lab_results' THEN (SELECT COUNT(*) FROM lab_results)
    END AS documents_stored
FROM document_collection_catalog c;
