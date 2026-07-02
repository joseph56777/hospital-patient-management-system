-- ============================================================================
-- 02_NoSQL_Document_Layer_Using_SQL_JSON.sql
-- Hospital Patient Management System
-- NoSQL/document layer implemented fully in SQL using MySQL JSON
--
-- THIS FILE IS THE NoSQL PART OF THE PROJECT.
-- It is not removed. It is implemented in SQL using document-style JSON
-- collections. This follows the tutor instruction that the coding should remain
-- SQL-only, while still demonstrating flexible schema design, embedded
-- document fields, JSON querying, aggregation, and JSON indexing.
--
-- Safe to run more than once. It does not delete sample data.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS hospital_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE hospital_db;
SET default_storage_engine = InnoDB;

-- Minimal parent tables are created if missing so this file cannot fail with a
-- foreign-key parent-table error during practice. In the correct run order, file
-- 01 creates the full relational core first.
CREATE TABLE IF NOT EXISTS departments (
    department_id      INT PRIMARY KEY,
    department_name    VARCHAR(100) NOT NULL UNIQUE,
    location           VARCHAR(100) NOT NULL,
    phone_extension    VARCHAR(10)
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS doctors (
    doctor_id          INT PRIMARY KEY,
    first_name         VARCHAR(50)  NOT NULL,
    last_name          VARCHAR(50)  NOT NULL,
    specialization     VARCHAR(60)  NOT NULL,
    department_id      INT          NOT NULL,
    phone              VARCHAR(25),
    email              VARCHAR(100) UNIQUE,
    years_experience   INT          NOT NULL DEFAULT 0,
    CONSTRAINT chk_doctor_experience CHECK (years_experience >= 0),
    CONSTRAINT fk_doctors_departments
        FOREIGN KEY (department_id) REFERENCES departments(department_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS patients (
    patient_id          INT PRIMARY KEY,
    first_name          VARCHAR(50) NOT NULL,
    last_name           VARCHAR(50) NOT NULL,
    date_of_birth       DATE        NOT NULL,
    gender              ENUM('Male', 'Female') NOT NULL,
    phone               VARCHAR(25),
    email               VARCHAR(100) UNIQUE,
    address             VARCHAR(255),
    blood_type          VARCHAR(3),
    insurance_provider  VARCHAR(60),
    registration_date   DATE        NOT NULL
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
    appointment_id      INT PRIMARY KEY,
    patient_id          INT NOT NULL,
    doctor_id           INT NOT NULL,
    appointment_date    DATE NOT NULL,
    appointment_time    TIME NOT NULL,
    status              ENUM('Completed', 'Scheduled', 'Cancelled', 'No-show') NOT NULL,
    reason              VARCHAR(255),
    CONSTRAINT fk_appointments_patients
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_appointments_doctors
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS document_collection_catalog (
    collection_name     VARCHAR(50) PRIMARY KEY,
    business_reason     VARCHAR(255) NOT NULL,
    example_document    JSON NOT NULL,
    modelling_choice    ENUM('Embedded JSON document', 'Referenced relational link') NOT NULL
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS clinical_notes (
    note_id             VARCHAR(20) PRIMARY KEY,
    patient_id          INT NOT NULL,
    doctor_id           INT NOT NULL,
    appointment_id      INT NOT NULL,
    visit_date          DATE NOT NULL,
    document            JSON NOT NULL,
    CONSTRAINT chk_clinical_notes_document_object CHECK (JSON_TYPE(document) = 'OBJECT'),
    CONSTRAINT fk_notes_patients
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_notes_doctors
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_notes_appointments
        FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS treatment_records (
    treatment_id        VARCHAR(20) PRIMARY KEY,
    patient_id          INT NOT NULL,
    doctor_id           INT NOT NULL,
    appointment_id      INT NOT NULL,
    treatment_type      VARCHAR(30) NOT NULL,
    document            JSON NOT NULL,
    CONSTRAINT chk_treatment_records_document_object CHECK (JSON_TYPE(document) = 'OBJECT'),
    CONSTRAINT fk_treatments_patients
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_treatments_doctors
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_treatments_appointments
        FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

CREATE TABLE IF NOT EXISTS lab_results (
    lab_id              VARCHAR(20) PRIMARY KEY,
    patient_id          INT NOT NULL,
    doctor_id           INT NOT NULL,
    appointment_id      INT NOT NULL,
    test_type           VARCHAR(50) NOT NULL,
    test_date           DATE NOT NULL,
    document            JSON NOT NULL,
    CONSTRAINT chk_lab_results_document_object CHECK (JSON_TYPE(document) = 'OBJECT'),
    CONSTRAINT fk_labs_patients
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_labs_doctors
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_labs_appointments
        FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

INSERT INTO document_collection_catalog VALUES
(
    'clinical_notes',
    'Flexible doctor notes, vitals, symptoms, follow-up decisions, and comments change from visit to visit.',
    JSON_OBJECT(
        'subjective', 'Patient reports chest discomfort during exercise.',
        'vitals', JSON_OBJECT('blood_pressure', '126/82', 'heart_rate_bpm', 84),
        'follow_up_required', JSON_EXTRACT('true', '$'),
        'doctor_comment', 'Review after medication adjustment.'
    ),
    'Referenced relational link'
),
(
    'treatment_records',
    'Treatments can contain medication arrays, procedures, therapy notes, or care plans depending on the case.',
    JSON_OBJECT(
        'status', 'Active',
        'medications', JSON_ARRAY('Amlodipine 5mg', 'Atorvastatin 10mg'),
        'care_plan', 'Monitor blood pressure weekly.'
    ),
    'Embedded JSON document'
),
(
    'lab_results',
    'Different lab tests have different result structures, so a flexible document is more natural than many nullable columns.',
    JSON_OBJECT(
        'status', 'Abnormal - Reviewed',
        'results', JSON_OBJECT('hemoglobin', 12.8, 'wbc', 9.2),
        'findings', 'Values reviewed by doctor.'
    ),
    'Embedded JSON document'
)
ON DUPLICATE KEY UPDATE
    business_reason  = VALUES(business_reason),
    example_document = VALUES(example_document),
    modelling_choice = VALUES(modelling_choice);

SELECT 'NoSQL/document layer is ready. Clinical notes, treatments, and lab results are JSON document collections written fully in SQL.' AS status_message;
