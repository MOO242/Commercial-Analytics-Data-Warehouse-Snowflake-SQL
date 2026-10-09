# 🏷️ Naming Conventions (Snowflake)

This document defines the naming conventions for databases, schemas, tables, views, columns, stored procedures, and script files in the data warehouse.

## Table of Contents

1. General Principles
2. Snowflake Identifier Rules
3. Schema Naming Conventions
4. Table and View Naming Conventions
    - Bronze Rules
    - Silver Rules
    - Gold Rules
5. Column Naming Conventions
    - Surrogate Keys
    - Business Keys
    - Technical Columns
6. Stored Procedure Naming Conventions
7. Script File Naming Conventions

---

## General Principles

- **Case style:** Use `snake_case`: lowercase letters with underscores (`_`) between words.
- **Language:** Use English for all names.
- **Reserved words:** Do not use SQL reserved words (such as `order`, `date`, `user`) as object or column names.
- **Clarity over brevity:** Prefer `customer_number` over `cust_no` in the Gold layer. Bronze and Silver keep the source names.
- **Consistency:** The same business concept uses the same column name in every Gold object (for example, `customer_key` in both `dim_customers` and `fact_sales`).

---

## Snowflake Identifier Rules

Snowflake stores **unquoted** identifiers in **uppercase**. For example, `gold.dim_customers` is stored as `GOLD.DIM_CUSTOMERS`, and both names work in queries.

| Rule | Do | Don’t |
| --- | --- | --- |
| Write identifiers unquoted | `gold.dim_customers` | `"gold"."dim_customers"` |
| Use only letters, numbers, and `_` | `erp_cust_az12` | `erp-cust-az12`, `erp cust` |
| Start names with a letter | `fact_sales` | `1_fact_sales` |

> ⚠️ Quoted identifiers are case-sensitive. `"dim_customers"` and `DIM_CUSTOMERS` are different objects. Avoid quotes so you never have to match case exactly.
> 

---

## Schema Naming Conventions

One schema per Medallion layer, named after the layer:

| Schema | Purpose | Object type |
| --- | --- | --- |
| `bronze` | Raw data loaded as-is from the source CSV files | Tables |
| `silver` | Cleaned and standardized data | Tables |
| `gold` | Business-ready star schema and reporting views | Views |

---

## Table and View Naming Conventions

### Bronze Rules

- Names start with the source system name, and the entity name matches the source **without renaming**.
- **Pattern: `<sourcesystem>_<entity>`**
    - `<sourcesystem>`: Source system (`crm`, `erp`).
    - `<entity>`: Exact table or file name from the source system.
    - Example: `bronze.crm_cust_info` → customer information from the CRM system.

### Silver Rules

- Same pattern as Bronze. Silver tables keep the source names so every table can be traced back to Bronze one-to-one.
- **Pattern: `<sourcesystem>_<entity>`**
    - Example: `silver.crm_cust_info` → cleaned customer information from the CRM system.

**Source tables in this project:**

| Source | Tables (Bronze and Silver) |
| --- | --- |
| CRM | `crm_cust_info`, `crm_sales_details`, `crm_px_cat_g1v2` |
| ERP | `erp_prd_info`, `erp_cust_az12`, `erp_loc_a101` |

### Gold Rules

- Names are business-aligned and start with a **category prefix**.
- **Pattern: `<category>_<entity>`**
    - `<category>`: The object’s role (`dim`, `fact`, `report`).
    - `<entity>`: Business name in **plural** form (`customers`, `products`, `sales`).
    - Examples:
        - `gold.dim_customers` → customer dimension.
        - `gold.fact_sales` → sales transactions fact.
        - `gold.report_customers` → one row per customer with KPIs, for BI tools.

#### Glossary of Category Patterns

| Pattern | Meaning | Examples |
| --- | --- | --- |
| `dim_` | Dimension view | `dim_customers`, `dim_products` |
| `fact_` | Fact view | `fact_sales` |
| `report_` | Reporting view (aggregated, BI-ready) | `report_customers`, `report_products` |

---

## Column Naming Conventions

### Surrogate Keys

- Every dimension’s primary key uses the suffix `_key`.
- **Pattern: `<entity>_key`** (singular entity name)
    - Example: `customer_key` → surrogate key in `gold.dim_customers`, generated with `ROW_NUMBER()`.
- Fact views use the **same name** for the foreign key (`fact_sales.customer_key`), so joins read naturally.

### Business Keys

- Identifiers that come from the source systems keep the suffix `_id` or `_number`.
    - Example: `customer_id`, `customer_number`, `product_number`.
- Business keys are kept in the Gold layer for traceability but are **not** used to join fact and dimension views.

### Technical Columns

- System-generated metadata columns start with the prefix `dwh_`.
- **Pattern: `dwh_<column_name>`**
    - `dwh`: Prefix reserved for warehouse metadata.
    - `<column_name>`: What the column records.
    - Example: `dwh_create_date` → timestamp when the row was loaded, set with `DEFAULT CURRENT_TIMESTAMP()`.

---

## Stored Procedure Naming Conventions

- Load procedures are named after the layer they load and are created **in that layer’s schema**.
- **Pattern: `<layer>.load_<layer>()`**
    - Examples:
        - `bronze.load_bronze()` → loads raw CSV data into Bronze (`TRUNCATE` + `COPY INTO`).
        - `silver.load_silver()` → loads cleaned data into Silver (`TRUNCATE` + `INSERT`).
- Run them with `CALL`:
    
    ```sql
    CALL bronze.load_bronze();
    CALL silver.load_silver();
    ```
    
- The Gold layer has no load procedure, because it is made of views.

---

## Script File Naming Conventions

- Script files use `snake_case` and live in the folder of their layer or purpose.
- Scripts that run in sequence start with a **two-digit number**.

| Folder | Pattern | Examples |
| --- | --- | --- |
| `scripts/bronze/`, `scripts/silver/` | `ddl_<layer>.sql`, `proc_load_<layer>.sql` | `ddl_silver.sql`, `proc_load_silver.sql` |
| `scripts/gold/` | `ddl_gold.sql` | `ddl_gold.sql` |
| `scripts/eda/` | `<nn>_<topic>.sql` | `01_eda_gold_layer.sql` |
| `scripts/analytics/` | `<nn>_<topic>.sql` | `01_change_over_time.sql`, `06_report_customers.sql` |
| `tests/` | `quality_checks_<layer>.sql` | `quality_checks_gold.sql`, `quality_checks_reports.sql` |
