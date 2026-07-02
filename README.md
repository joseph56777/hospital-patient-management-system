# Hospital Patient Management System
### M605 Advanced Databases — Individual Project | Gisma University of Applied Sciences

---

## What this project is

This is a hybrid database system for managing hospital patient data. I built it around a real-world hospital scenario — patients booking appointments with doctors, doctors belonging to departments, billing being generated after each completed appointment, and clinical records (notes, treatments, lab results) being stored alongside the structured data.

The "hybrid" part means the system uses two different storage approaches inside the same MySQL database:

- **Relational tables** for everything that's structured and fixed: patients, doctors, departments, appointments, billing. These need proper foreign keys and ACID guarantees because data like payment status or appointment records should never end up in a broken state halfway through an update.
- **JSON-column tables** for clinical data that genuinely varies in shape record to record. A blood test result has completely different fields from an X-ray report. A medication treatment has a variable-length list of drugs. Forcing this into rigid SQL columns would mean dozens of nullable fields per row — instead, I use MySQL's native JSON column type to store flexible documents, and query them using MySQL's JSON functions. Functionally it's the same as MongoDB but stays entirely within SQL.

---

## Files in this repository

```
hospital-patient-management/
│
├── README.md                        ← you are here
│
├── diagrams/
│   └── er_diagram.png               ← ER diagram covering all 8 tables
│
├── data/
│   └── hospital_data.sql            ← all INSERT statements (all 8 tables combined)
│
└── sql/
    ├── 01_schema.sql                ← CREATE TABLE definitions + constraints
    ├── 02_stored_procedures.sql     ← stored procedures + trigger
    ├── 03_queries_sql.sql           ← CRUD + joins + aggregations (relational side)
    ├── 04_queries_nosql.sql         ← JSON column queries (NoSQL simulation side)
    ├── 05_indexes.sql               ← indexes, generated columns, performance view
    └── 06_transactions.sql          ← ACID transaction examples with rollback
```

---

## How to run it

You'll need MySQL 8.0 (the JSON functions used here aren't available in older versions).

Run the files in this order:

```sql
-- 1. create the database and all tables
SOURCE sql/01_schema.sql;

-- 2. load all the data (1200 patients, 3000 appointments, and more)
SOURCE data/hospital_data.sql;

-- 3. create stored procedures and the auto-billing trigger
SOURCE sql/02_stored_procedures.sql;

-- 4. add indexes and the performance view
SOURCE sql/05_indexes.sql;

-- 5. run the demo queries (pick either or both)
SOURCE sql/03_queries_sql.sql;
SOURCE sql/04_queries_nosql.sql;

-- 6. see the transaction examples
SOURCE sql/06_transactions.sql;
```

Or if you're using MySQL Workbench, just open each file and run it in order.

---

## What's in the data

| Table | Records | Notes |
|-------|---------|-------|
| departments | 10 | hospital departments |
| doctors | 60 | spread across all departments |
| patients | 1,200 | with demographics and insurance |
| appointments | 3,000 | linking patients to doctors |
| billing | ~1,900 | auto-generated for completed appointments |
| clinical_notes | ~1,900 | JSON documents with vitals and observations |
| treatment_records | ~1,350 | JSON documents with variable treatment types |
| lab_results | ~970 | JSON documents with test-specific result fields |

The data was synthetically generated using Python's Faker library to produce realistic but entirely fictional records. No real patient data is used anywhere.

---

## Design decisions worth noting

**Why JSON columns for clinical data?**
Lab results are the clearest example. A Complete Blood Count has WBC, RBC, haemoglobin and platelet fields. An X-Ray has a body area, a findings text, and an image reference. A Urinalysis has colour, pH, and boolean flags. These are completely different shapes — there's no single SQL schema that fits all of them without leaving most columns empty for most rows. JSON handles this cleanly, and MySQL's `JSON_VALUE()` and `JSON_EXTRACT()` let us query inside those documents efficiently.

**Why ACID for the relational side?**
Billing is the main reason. A payment record must always correspond to a real appointment — you should never get a bill with no appointment behind it, or vice versa. The transaction examples in `06_transactions.sql` show exactly what happens when something goes wrong mid-operation, and how MySQL rolls back to keep everything consistent.

**Why generated columns for JSON indexing?**
MySQL can't index directly into a JSON field, but it can index a generated column that extracts one value from it. This is what `05_indexes.sql` does for `follow_up_required` in clinical_notes and `status` in lab_results — it makes those JSON-based filters as fast as a normal indexed lookup.

---

## Project links

- **GitHub repository:** [add your link here]
- **Video demonstration:** [add your link here]
- **Report:** submitted separately on Canvas

---

*Joseph | M605 Advanced Databases Resit | Gisma University of Applied Sciences | Winter 2026*
