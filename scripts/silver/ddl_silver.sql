/*
===============================================================================
DDL Script: Create Silver Layer Tables (Snowflake)
===============================================================================
Script Purpose:
    This script creates the source tables in the 'bronze' schema of the
    Snowflake Data Warehouse. `CREATE OR REPLACE TABLE` drops the table if it
    already exists and recreates it, ensuring a clean, consistent structure
    before each run.

    These tables store raw CRM and ERP data exactly as it comes from the
    source CSV files — no transformations, cleansing, or business rules are
    applied here. That happens later in the Silver layer.

Tables Created:
    - silver.crm_cust_info
    - silver.crm_prd_info
    - silver.crm_sales_details
    - silver.erp_loc_a101
    - silver.erp_cust_az12
    - silver.erp_px_cat_g1v2

Usage:
    Run this script once (or any time you need to reset the bronze layer
    structure) before calling silver.load_bronze().
===============================================================================
*/
CREATE TABLE IF NOT EXISTS silver.crm_cust_info CREATE
OR REPLACE TABLE silver.crm_cust_info (
    cst_id INT,
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE
);

-- CRM: Product master data
CREATE TABLE IF NOT EXISTS silver.crm_prd_info CREATE
OR REPLACE TABLE silver.crm_prd_info (
    prd_id INT,
    prd_key VARCHAR(50),
    prd_nm VARCHAR(50),
    prd_cost INT,
    prd_line VARCHAR(50),
    prd_start_dt TIMESTAMP_NTZ,
    prd_end_dt TIMESTAMP_NTZ
);

-- CRM: Sales transaction details
CREATE TABLE IF NOT EXISTS silver.crm_sales_details CREATE
OR REPLACE TABLE silver.crm_sales_details (
    sls_ord_num VARCHAR(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id INT,
    sls_ord_dt INT,
    sls_ship_dt INT,
    sls_due_dt INT,
    sls_sales INT,
    sls_quantity INT,
    sls_price INT
);

-- ERP: Customer location/country
CREATE TABLE IF NOT EXISTS silver.erp_loc_a101 CREATE
OR REPLACE TABLE silver.erp_loc_a101 (cid VARCHAR(50), cntry VARCHAR(50));

-- ERP: Customer demographic data (birthdate, gender)
CREATE TABLE IF NOT EXISTS silver.erp_cust_az12 CREATE
OR REPLACE TABLE silver.erp_cust_az12 (
    cid VARCHAR(50),
    bdate DATE,
    gen VARCHAR(50)
);
-- ERP: Product category, subcategory, maintenance info
CREATE TABLE IF NOT EXISTS silver.erp_px_cat_g1v2 CREATE
OR REPLACE TABLE silver.erp_px_cat_g1v2 (
    id VARCHAR(50),
    cat VARCHAR(50),
    subcat VARCHAR(50),
    maintenance VARCHAR(50)
);
