/*
===============================================================================
Stored Procedure : silver.load_silver
===============================================================================
Purpose:
    Loads and transforms data from the Bronze layer into the Silver layer.

Process:
    1. Truncate target Silver tables.
    2. Clean and standardize source data.
    3. Apply business transformation rules.
    4. Remove duplicates where required.
    5. Load transformed data into Silver tables.
    6. Log major load steps for observability.

Source Layer:
    BRONZE

Target Layer:
    SILVER
===============================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
    RETURNS VARCHAR
    LANGUAGE SQL
    AS $$
DECLARE
    start_time        TIMESTAMP_NTZ;
    end_time          TIMESTAMP_NTZ;
    batch_start_time  TIMESTAMP_NTZ;
    batch_end_time    TIMESTAMP_NTZ;
    log_msg           VARCHAR DEFAULT '';
BEGIN
    batch_start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '================================================\n';
    log_msg := log_msg || 'Loading Silver Layer\n';
    log_msg := log_msg || '================================================\n';
    log_msg := log_msg || '------------------------------------------------\n';
    log_msg := log_msg || 'Loading CRM Tables\n';
    log_msg := log_msg || '------------------------------------------------\n';
    /*=====================================================
      LOAD crm_cust_info
    =====================================================*/
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: silver.crm_cust_info\n';
    TRUNCATE TABLE silver.crm_cust_info;
    log_msg := log_msg || '>> Inserting Data Into: silver.crm_cust_info\n';
    INSERT INTO silver.crm_cust_info (
        cst_id, cst_key, cst_firstname, cst_lastname,
        cst_gndr, cst_marital_status, cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname)  AS cst_lastname,
        CASE UPPER(TRIM(cst_gndr))
            WHEN 'F' THEN 'Female'
            WHEN 'M' THEN 'Male'
            ELSE NULL
        END AS cst_gndr,
        CASE UPPER(TRIM(cst_marital_status))
            WHEN 'S' THEN 'Single'
            WHEN 'M' THEN 'Married'
            ELSE NULL
        END AS cst_marital_status,
        cst_create_date
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) = 1;
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';
    /*=====================================================
      LOAD crm_px_cat_g1v2
    =====================================================*/
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: silver.crm_px_cat_g1v2\n';
    TRUNCATE TABLE silver.crm_px_cat_g1v2;
    log_msg := log_msg || '>> Inserting Data Into: silver.crm_px_cat_g1v2\n';
    INSERT INTO silver.crm_px_cat_g1v2 (cat, id, maintenance, subcat)
    SELECT
        UPPER(TRIM(cat)),
        id,
        UPPER(TRIM(maintenance)),
        UPPER(TRIM(subcat))
    FROM bronze.crm_px_cat_g1v2;
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';
    /*=====================================================
      LOAD crm_sales_details
    =====================================================*/
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: silver.crm_sales_details\n';
    TRUNCATE TABLE silver.crm_sales_details;
    log_msg := log_msg || '>> Inserting Data Into: silver.crm_sales_details\n';
    INSERT INTO silver.crm_sales_details (
        sls_cust_id, sls_due_dt, sls_order_dt, sls_ord_num, sls_prd_key,
        sls_price, sls_quantity, sls_sales, sls_ship_dt
    )
    SELECT
        sls_cust_id,
        TO_DATE(TO_VARCHAR(sls_due_dt), 'YYYYMMDD') AS sls_due_dt,
        CASE
            WHEN sls_order_dt <= 0
              OR LENGTH(sls_order_dt) != 8
              OR sls_order_dt > 20500101
              OR sls_order_dt < 19000101 THEN NULL
            ELSE TO_DATE(TO_VARCHAR(sls_order_dt), 'YYYYMMDD')
        END AS sls_order_dt,
        sls_ord_num,
        sls_prd_key,
        CASE
            WHEN sls_price IS NULL OR sls_price <= 0
                THEN sls_sales / NULLIF(sls_quantity, 0)
            ELSE sls_price
        END AS sls_price,
        sls_quantity,
        CASE
            WHEN sls_sales IS NULL
              OR sls_sales <= 0
              OR sls_sales != sls_quantity * ABS(sls_price)
                THEN sls_quantity * ABS(sls_price)
            ELSE sls_sales
        END AS sls_sales,
        TO_DATE(TO_VARCHAR(sls_ship_dt), 'YYYYMMDD') AS sls_ship_dt
    FROM bronze.crm_sales_details;
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';
    log_msg := log_msg || '------------------------------------------------\n';
    log_msg := log_msg || 'Loading ERP Tables\n';
    log_msg := log_msg || '------------------------------------------------\n';
    /*=====================================================
      LOAD erp_cust_az12
    =====================================================*/
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: silver.erp_cust_az12\n';
    TRUNCATE TABLE silver.erp_cust_az12;
    log_msg := log_msg || '>> Inserting Data Into: silver.erp_cust_az12\n';
    INSERT INTO silver.erp_cust_az12 (bdate, cid, gen)
    SELECT
        CASE WHEN bdate > CURRENT_DATE() THEN NULL ELSE bdate END AS bdate,
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTR(cid, 4) ELSE cid END AS cid,   -- FIX: keep original ID
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
            ELSE 'n/a'
        END AS gen
    FROM bronze.erp_cust_az12;
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';
    /*=====================================================
      LOAD erp_loc_a101
    =====================================================*/
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: silver.erp_loc_a101\n';
    TRUNCATE TABLE silver.erp_loc_a101;
    log_msg := log_msg || '>> Inserting Data Into: silver.erp_loc_a101\n';
    INSERT INTO silver.erp_loc_a101 (cid, cntry)
    SELECT
        REPLACE(cid, '-', '') AS cid,
        CASE
            WHEN cntry IS NULL OR TRIM(cntry) = ''         THEN 'n/a'
            WHEN UPPER(TRIM(cntry)) IN ('USA', 'US')       THEN 'United States'
            WHEN UPPER(TRIM(cntry)) = 'DE'                 THEN 'Germany'
            ELSE TRIM(cntry)
        END AS cntry
    FROM bronze.erp_loc_a101;
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';
    /*=====================================================
      LOAD erp_prd_info
    =====================================================*/
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: silver.erp_prd_info\n';
    TRUNCATE TABLE silver.erp_prd_info;
    log_msg := log_msg || '>> Inserting Data Into: silver.erp_prd_info\n';
    INSERT INTO silver.erp_prd_info (
        prd_id, cat_id, prd_key, prd_nm, prd_cost,
        prd_line, prd_start_dt, prd_end_dt
    )
    SELECT
        prd_id,
        REPLACE(SUBSTR(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTR(prd_key, 7)                       AS prd_key,
        prd_nm,
        COALESCE(prd_cost, 0)                    AS prd_cost,
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        DATEADD(day, -1,
            LEAD(CAST(prd_start_dt AS DATE)) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)
        ) AS prd_end_dt
    FROM bronze.erp_prd_info;            -- FIX: was silver (truncated table)
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';
    /*=====================================================
      COMPLETED
    =====================================================*/
    batch_end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '================================================\n';
    log_msg := log_msg || 'Silver Layer loaded successfully\n';
    log_msg := log_msg || '   - Total Load Duration: ' || DATEDIFF('second', batch_start_time, batch_end_time) || ' seconds\n';
    log_msg := log_msg || '================================================\n';
    RETURN log_msg;
EXCEPTION
    WHEN OTHER THEN
        RETURN log_msg || '\n!! ERROR DURING SILVER LOAD !!\n'
                       || 'SQLCODE: ' || SQLCODE || '\n'
                       || 'Message: ' || SQLERRM || '\n';
END;
$$;


/* =============================================================================
   EXECUTION
   =============================================================================

CALL silver.load_silver();

============================================================================= */
