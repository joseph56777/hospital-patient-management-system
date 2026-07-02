-- ============================================================================
-- 01_SQL_Relational_Database.sql
-- Hospital Patient Management System
-- Relational SQL core for M605 Advanced Databases
--
-- This file creates the stable part of the hospital database. These tables are
-- deliberately relational because the data must be consistent and easy to
-- validate. A hospital cannot safely manage appointments or billing if patient,
-- doctor, and department records are duplicated or loosely connected.
--
-- Run this file first.
-- ============================================================================

DROP DATABASE IF EXISTS hospital_db;
CREATE DATABASE hospital_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE hospital_db;

SET default_storage_engine = InnoDB;

-- ----------------------------------------------------------------------------
-- 1. Departments
-- ----------------------------------------------------------------------------
-- A department is a hospital unit such as Cardiology, Neurology, or Emergency.
-- It is separated from doctors to avoid repeating department details for every
-- doctor.

CREATE TABLE departments (
    department_id      INT PRIMARY KEY,
    department_name    VARCHAR(100) NOT NULL UNIQUE,
    location           VARCHAR(100) NOT NULL,
    phone_extension    VARCHAR(10)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 2. Doctors
-- ----------------------------------------------------------------------------
-- Each doctor belongs to one department. The foreign key is restricted on
-- delete because a department should not disappear while doctors are still
-- assigned to it.

CREATE TABLE doctors (
    doctor_id          INT PRIMARY KEY,
    first_name         VARCHAR(50)  NOT NULL,
    last_name          VARCHAR(50)  NOT NULL,
    specialization     VARCHAR(60)  NOT NULL,
    department_id      INT          NOT NULL,
    phone              VARCHAR(25),
    email              VARCHAR(100) UNIQUE,
    years_experience   INT          NOT NULL DEFAULT 0,

    CONSTRAINT chk_doctor_experience
        CHECK (years_experience >= 0),

    CONSTRAINT fk_doctors_departments
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 3. Patients
-- ----------------------------------------------------------------------------
-- Patient records are kept as structured data because they are used repeatedly
-- in appointments, billing, and clinical documents.

CREATE TABLE patients (
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

-- ----------------------------------------------------------------------------
-- 4. Appointments
-- ----------------------------------------------------------------------------
-- Appointments connect patients and doctors. The status field is controlled by
-- an ENUM because only a small number of business states are valid.

CREATE TABLE appointments (
    appointment_id      INT PRIMARY KEY,
    patient_id          INT NOT NULL,
    doctor_id           INT NOT NULL,
    appointment_date    DATE NOT NULL,
    appointment_time    TIME NOT NULL,
    status              ENUM('Completed', 'Scheduled', 'Cancelled', 'No-show') NOT NULL,
    reason              VARCHAR(255),

    CONSTRAINT fk_appointments_patients
        FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_appointments_doctors
        FOREIGN KEY (doctor_id)
        REFERENCES doctors(doctor_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 5. Billing
-- ----------------------------------------------------------------------------
-- Billing is linked to one appointment. The UNIQUE constraint prevents the same
-- appointment from being billed twice.

CREATE TABLE billing (
    bill_id             INT PRIMARY KEY AUTO_INCREMENT,
    patient_id          INT NOT NULL,
    appointment_id      INT NOT NULL UNIQUE,
    amount_eur          DECIMAL(8,2) NOT NULL,
    payment_method      ENUM('Insurance', 'Credit Card', 'Cash', 'Bank Transfer') NOT NULL,
    payment_status      ENUM('Paid', 'Pending', 'Overdue', 'Partially Paid') NOT NULL,
    billing_date        DATE NOT NULL,

    CONSTRAINT chk_billing_amount
        CHECK (amount_eur >= 0),

    CONSTRAINT fk_billing_patients
        FOREIGN KEY (patient_id)
        REFERENCES patients(patient_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_billing_appointments
        FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE = InnoDB;
