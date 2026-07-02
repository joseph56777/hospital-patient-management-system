# Hospital Patient Management System
## M605 Advanced Databases Final SQL Implementation

This project is a complete hospital patient management database for the M605 Advanced Databases assessment. The system is designed around a real healthcare situation where some data must be controlled very strictly, while other data changes from case to case.

The project does **not** remove the NoSQL part and does **not** remove the application layer. Both are included, but they are implemented completely in SQL because the tutor instruction is that only SQL should be used.

The project has three clear layers:

1. **SQL relational database layer**  
   This layer stores structured hospital data such as departments, doctors, patients, appointments, and billing. It uses primary keys, foreign keys, constraints, normalization, and ACID-safe design.

2. **NoSQL/document layer implemented in SQL**  
   This layer stores semi-structured clinical data as JSON documents inside SQL tables. The document collections are `clinical_notes`, `treatment_records`, and `lab_results`. This design keeps the implementation SQL-only while still showing NoSQL ideas such as flexible documents, embedded fields, document querying, document aggregation, and document indexing.

3. **Application layer implemented in SQL**  
   This layer uses stored procedures, triggers, transactions, and views. These procedures behave like the backend logic of the system. They book appointments, complete visits, save clinical notes, save lab results, generate a patient profile, and check the quality of the assessment dataset.

No Python, Java, JavaScript, web framework, or external application language is used.

---

## Folder structure

```text
hospital-patient-management-system/
|
|-- README.md
|
|-- data/
|   |-- 01_hospital_data.sql
|
|-- images/
|   |-- er_diagram.png
|
|-- programs/
    |-- 01_SQL_Relational_Database.sql
    |-- 02_NoSQL_Document_Layer_Using_SQL_JSON.sql
    |-- 03_Application_Layer_Using_SQL_Procedures.sql
    |-- 04_Integrity_Indexes_Optimization.sql
    |-- 05_CRUD_Joins_Aggregations_Demo.sql
    |-- 06_ACID_Transactions_Assessment_Checks.sql
```

The files are separated intentionally so the examiner can easily see each part of the assessment requirement.

---

## How to run the project

Use MySQL 8.0 or MySQL Workbench. Run the files in this exact order:

```sql
SOURCE programs/01_SQL_Relational_Database.sql;
SOURCE programs/02_NoSQL_Document_Layer_Using_SQL_JSON.sql;
SOURCE data/01_hospital_data.sql;
SOURCE programs/03_Application_Layer_Using_SQL_Procedures.sql;
SOURCE programs/04_Integrity_Indexes_Optimization.sql;
SOURCE programs/05_CRUD_Joins_Aggregations_Demo.sql;
SOURCE programs/06_ACID_Transactions_Assessment_Checks.sql;
```

In MySQL Workbench, open each file and run it one by one in the same order.

---

## Assessment requirement mapping

| Assessment requirement | Where it is satisfied in this project |
|---|---|
| SQL database for structured ACID data | `01_SQL_Relational_Database.sql` creates normalized relational tables for departments, doctors, patients, appointments, and billing. |
| NoSQL database for semi-structured data | `02_NoSQL_Document_Layer_Using_SQL_JSON.sql` creates SQL-based document collections using JSON columns. |
| Application layer | `03_Application_Layer_Using_SQL_Procedures.sql` creates stored procedures that integrate relational data and document data. |
| Database schema / document structure | `images/er_diagram.png` and the documented table definitions show the relational schema and document collections. |
| Tables, collections, indexes, and constraints | `01`, `02`, and `04` include relational constraints, JSON validation, generated columns, and indexes. |
| Minimum 100 records per table/collection | `data/01_hospital_data.sql` provides realistic sample data for the main business tables and document collections. |
| CRUD operations | `05_CRUD_Joins_Aggregations_Demo.sql` contains create, read, update, and delete examples. |
| Joins, aggregations, and complex filters | `05_CRUD_Joins_Aggregations_Demo.sql` contains patient timelines, department reports, doctor workload, JSON filtering, and lab-risk summaries. |
| ACID and transactions | `03` and `06` use `START TRANSACTION`, `COMMIT`, `SAVEPOINT`, and rollback logic. |
| Optimization | `04_Integrity_Indexes_Optimization.sql` adds relational indexes and JSON generated-column indexes. |
| Documentation and video support | This README gives the explanation and demo flow. The final report must include the GitHub and video links. |

---

## SQL relational database layer

The relational part is used for data that must be stable and strongly controlled. In a hospital, patient records, doctor records, appointments, and billing cannot be stored loosely because one mistake can affect treatment, payments, and reporting.

The relational tables are:

- `departments`
- `doctors`
- `patients`
- `appointments`
- `billing`

Important design choices:

- Departments are stored separately from doctors to avoid repeating department details.
- Doctors are linked to departments using a foreign key.
- Appointments connect patients and doctors.
- Billing is linked to appointments and patients.
- Billing has a unique appointment link so one appointment cannot be billed twice.
- InnoDB is used so transactions and foreign keys work correctly.

---

## NoSQL/document layer implemented completely in SQL

The NoSQL requirement is handled through SQL-based JSON document collections. This is used because clinical information is often semi-structured. For example, a cardiology note may contain blood pressure and heart-rate values, while another note may contain follow-up instructions or different clinical observations.

The document collections are:

- `clinical_notes`
- `treatment_records`
- `lab_results`

Each collection has normal relational reference columns such as `patient_id`, `doctor_id`, and `appointment_id`. The flexible part of the record is stored in the `document` JSON column.

This design uses both ideas together:

- relational references keep the hospital system safe and consistent;
- JSON documents provide flexibility for clinical content;
- generated columns extract important JSON values;
- indexes on generated columns improve document-query performance.

Example NoSQL-style document idea:

```sql
JSON_OBJECT(
    'subjective', 'Patient reports chest discomfort during exercise.',
    'vitals', JSON_OBJECT('blood_pressure', '126/82', 'heart_rate_bpm', 84),
    'follow_up_required', true,
    'doctor_comment', 'Review after medication adjustment.'
)
```

This is still SQL code, but it demonstrates document modelling, embedded fields, flexible schema design, and document querying.

---

## Application layer implemented completely in SQL

The application layer is not removed. It is written as SQL stored procedures because only SQL is allowed.

The main procedures are:

- `sp_book_appointment()`  
  Checks whether the patient and doctor exist, checks doctor availability, and then books the appointment.

- `sp_complete_visit()`  
  Completes an appointment and creates or updates the billing record inside a safe transaction.

- `sp_save_clinical_note()`  
  Saves a flexible JSON clinical note and links it to the correct patient, doctor, and appointment.

- `sp_save_lab_result()`  
  Saves a flexible JSON lab result and supports different test structures.

- `sp_patient_360_profile()`  
  Combines SQL relational data and document data into one patient profile.

- `sp_project_quality_check()`  
  Checks the data volume and confirms that the main tables and document collections have enough records.

This is the SQL-only replacement for a normal backend application layer.

---

## Dataset summary

The sample data is realistic for a hospital patient management system. The main business tables and document collections have more than 100 records.

| Table / collection | Role in the system | Record status |
|---|---|---|
| departments | hospital departments and service units | 100+ records |
| doctors | doctors linked to departments | 100+ records |
| patients | registered hospital patients | 100+ records |
| appointments | patient-doctor appointment history | 100+ records |
| billing | payment and billing records | 100+ records |
| clinical_notes | JSON clinical note documents | 100+ records |
| treatment_records | JSON treatment documents | 100+ records |
| lab_results | JSON lab-result documents | 100+ records |

The table `document_collection_catalog` is only a small metadata table. It describes the document collections and is not a main business table.

Run this after loading all files:

```sql
CALL sp_project_quality_check();
```

---

## Strong demonstration queries

After running all files, these examples are useful for the video demo:

```sql
CALL sp_project_quality_check();
CALL sp_patient_360_profile(1);
SELECT * FROM v_patient_timeline WHERE patient_id = 1 ORDER BY appointment_date DESC;
SELECT * FROM v_clinical_follow_up_queue LIMIT 20;
SELECT * FROM v_lab_risk_summary WHERE lab_status LIKE '%Abnormal%' LIMIT 20;
SELECT * FROM v_department_performance ORDER BY revenue_eur DESC LIMIT 10;
SELECT * FROM v_document_store_summary;
```

---

## Suggested 3 to 5 minute video flow

1. Show the folder structure and say the project is SQL-only but still includes SQL, NoSQL/document layer, and application layer.
2. Show the ER diagram and explain the relational core and document collections.
3. Open `01_SQL_Relational_Database.sql` and explain the SQL structured tables.
4. Open `02_NoSQL_Document_Layer_Using_SQL_JSON.sql` and explain that the NoSQL-style part is implemented as JSON document collections in SQL.
5. Open `03_Application_Layer_Using_SQL_Procedures.sql` and explain that stored procedures are used as the application layer.
6. Run `CALL sp_project_quality_check();` to prove the record counts.
7. Run the patient profile, follow-up queue, lab-risk report, and department performance report.
8. Show the transaction demo and explain why ACID is important in healthcare.

---

## Final report checklist

The final PDF report should be below 3000 words and should include:

- student information;
- GitHub repository link;
- video demonstration link;
- introduction and healthcare domain explanation;
- SQL relational schema explanation;
- NoSQL/document layer explanation;
- application-layer explanation;
- screenshots or outputs from the demo queries;
- indexing and optimization explanation;
- transaction/ACID explanation;
- challenges and solutions;
- conclusion and future work;
- Harvard references.

Replace these placeholders before submission:

- GitHub repository: `PASTE YOUR GITHUB LINK HERE`
- Video demonstration: `PASTE YOUR VIDEO LINK HERE`

Do not update the GitHub repository after the submission deadline.

---

## References to mention in the report

Connolly, T. and Begg, C. (2015) *Database systems: A practical approach to design, implementation, and management*. Pearson Education.

MongoDB University (2024) *Introduction to MongoDB*. Available at: MongoDB University.

MongoDB University (2024) *MongoDB for SQL Experts*. Available at: MongoDB University.

MongoDB University (2024) *Introduction to MongoDB for SQL Professionals*. Available at: MongoDB University.

---

## Author

Joseph Antony  
M605 Advanced Databases  
Gisma University of Applied Sciences

## Error-free run order in MySQL Workbench

Run the files in this exact order. Do not start from the data file in a half-created database.

1. `programs/01_SQL_Relational_Database.sql`
2. `programs/02_NoSQL_Document_Layer_Using_SQL_JSON.sql`
3. `data/01_hospital_data.sql`
4. `programs/03_Application_Layer_Using_SQL_Procedures.sql`
5. `programs/04_Integrity_Indexes_Optimization.sql`
6. `programs/05_CRUD_Joins_Aggregations_Demo.sql`
7. `programs/06_ACID_Transactions_Assessment_Checks.sql`

The data file now starts with a safe reload block. This means that if you run the data file again, it clears the project data tables first and then loads the same records again. This prevents the duplicate primary-key error such as `Duplicate entry '1' for key 'departments.PRIMARY'`.

If you want a completely fresh run, simply run file 1 again first. File 1 drops and recreates `hospital_db`, so it gives the cleanest starting point for the final demo video.

## Exact Run Order in MySQL Workbench

Use this order from a clean MySQL Workbench session:

1. `programs/01_SQL_Relational_Database.sql`
2. `programs/02_NoSQL_Document_Layer_Using_SQL_JSON.sql`
3. `data/01_hospital_data.sql`
4. `programs/03_Application_Layer_Using_SQL_Procedures.sql`
5. `programs/04_Integrity_Indexes_Optimization.sql`
6. `programs/05_CRUD_Joins_Aggregations_Demo.sql`
7. `programs/06_ACID_Transactions_Assessment_Checks.sql`

The data file is now protected against the error `Table hospital_db.lab_results doesn't exist` because it creates any missing project tables before clearing and loading data. It is also protected against duplicate primary-key errors because it reloads the project tables in the correct child-to-parent order.

Important: this project still includes all three assessment layers. The relational SQL database is in file 01, the NoSQL/document layer is in file 02 using JSON document collections, and the application layer is in file 03 using SQL stored procedures. There is no Python, Java, or web-app code in this package.
