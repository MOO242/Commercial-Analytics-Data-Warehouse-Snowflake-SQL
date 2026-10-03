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
AS
$$

BEGIN

    /* ========================================================================
       LOAD: CRM_CUST_INFO
       ======================================================================== */

    SYSTEM$LOG_INFO('>> Truncating SILVER.CRM_CUST_INFO');

    TRUNCATE TABLE silver.crm_cust_info;

    SYSTEM$LOG_INFO('>> Loading SILVER.CRM_CUST_INFO');

    INSERT INTO silver.crm_cust_info
    (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_gndr,
        cst_marital_status,
        cst_create_date
    )
    SELECT
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,

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

    QUALIFY ROW_NUMBER() OVER
    (
        PARTITION BY cst_id
        ORDER BY cst_create_date DESC
    ) = 1;

    SYSTEM$LOG_INFO('>> SILVER.CRM_CUST_INFO load completed');


    /* ========================================================================
       LOAD: CRM_PX_CAT_G1V2
       ======================================================================== */

    SYSTEM$LOG_INFO('>> Truncating SILVER.CRM_PX_CAT_G1V2');

    TRUNCATE TABLE silver.crm_px_cat_g1v2;

    SYSTEM$LOG_INFO('>> Loading SILVER.CRM_PX_CAT_G1V2');

    INSERT INTO silver.crm_px_cat_g1v2
    (
        cat,
        id,
        maintenance,
        subcat
    )
    SELECT
        UPPER(TRIM(cat))         AS cat,
        id,
        UPPER(TRIM(maintenance)) AS maintenance,
        UPPER(TRIM(subcat))      AS subcat

    FROM bronze.crm_px_cat_g1v2;

    SYSTEM$LOG_INFO('>> SILVER.CRM_PX_CAT_G1V2 load completed');


    /* ========================================================================
       LOAD: CRM_SALES_DETAILS
       ======================================================================== */

    SYSTEM$LOG_INFO('>> Truncating SILVER.CRM_SALES_DETAILS');

    TRUNCATE TABLE silver.crm_sales_details;

    SYSTEM$LOG_INFO('>> Loading SILVER.CRM_SALES_DETAILS');

    INSERT INTO silver.crm_sales_details
    (
        sls_cust_id,
        sls_due_dt,
        sls_order_dt,
        sls_ord_num,
        sls_prd_key,
        sls_price,
        sls_quantity,
        sls_sales,
        sls_ship_dt
    )
    SELECT
        sls_cust_id,

        TO_DATE(
            TO_VARCHAR(sls_due_dt),
            'YYYYMMDD'
        ) AS sls_due_dt,

        /* Validate order date before conversion */
        CASE
            WHEN sls_order_dt <= 0
                OR LENGTH(TO_VARCHAR(sls_order_dt)) != 8
                OR sls_order_dt > 20500101
                OR sls_order_dt < 19000101
            THEN NULL

            ELSE TO_DATE(
                TO_VARCHAR(sls_order_dt),
                'YYYYMMDD'
            )
        END AS sls_order_dt,

        sls_ord_num,
        sls_prd_key,

        /* Derive price when source price is missing or invalid */
        CASE
            WHEN sls_price IS NULL
                OR sls_price <= 0
            THEN sls_sales / NULLIF(sls_quantity, 0)

            ELSE sls_price
        END AS sls_price,

        sls_quantity,

        /* Recalculate sales when source sales value is invalid */
        CASE
            WHEN sls_sales IS NULL
                OR sls_sales <= 0
                OR sls_sales != sls_quantity * ABS(sls_price)
            THEN sls_quantity * ABS(sls_price)

            ELSE sls_sales
        END AS sls_sales,

        TO_DATE(
            TO_VARCHAR(sls_ship_dt),
            'YYYYMMDD'
        ) AS sls_ship_dt

    FROM bronze.crm_sales_details;

    SYSTEM$LOG_INFO('>> SILVER.CRM_SALES_DETAILS load completed');


    /* ========================================================================
       LOAD: ERP_CUST_AZ12
       ======================================================================== */

    SYSTEM$LOG_INFO('>> Truncating SILVER.ERP_CUST_AZ12');

    TRUNCATE TABLE silver.erp_cust_az12;

    SYSTEM$LOG_INFO('>> Loading SILVER.ERP_CUST_AZ12');

    INSERT INTO silver.erp_cust_az12
    (
        bdate,
        cid,
        gen
    )
    SELECT

        /* Remove future birth dates */
        CASE
            WHEN bdate > CURRENT_DATE() THEN NULL
            ELSE bdate
        END AS bdate,

        /* Remove NAS prefix from customer ID */
        CASE
            WHEN cid LIKE 'NAS%' THEN SUBSTR(cid, 4)
            ELSE cid
        END AS cid,

        /* Standardize gender values */
        CASE
            WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
            WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
            ELSE 'n/a'
        END AS gen

    FROM bronze.erp_cust_az12;

    SYSTEM$LOG_INFO('>> SILVER.ERP_CUST_AZ12 load completed');


    /* ========================================================================
       LOAD: ERP_LOC_A101
       ======================================================================== */

    SYSTEM$LOG_INFO('>> Truncating SILVER.ERP_LOC_A101');

    TRUNCATE TABLE silver.erp_loc_a101;

    SYSTEM$LOG_INFO('>> Loading SILVER.ERP_LOC_A101');

    INSERT INTO silver.erp_loc_a101
    (
        cid,
        cntry
    )
    SELECT

        /* Standardize customer ID */
        REPLACE(cid, '-', '') AS cid,

        /* Standardize country values */
        CASE
            WHEN cntry IS NULL
                OR TRIM(cntry) = ''
            THEN 'n/a'

            WHEN UPPER(TRIM(cntry)) IN ('USA', 'US')
            THEN 'United States'

            WHEN UPPER(TRIM(cntry)) = 'DE'
            THEN 'Germany'

            ELSE TRIM(cntry)
        END AS cntry

    FROM bronze.erp_loc_a101;

    SYSTEM$LOG_INFO('>> SILVER.ERP_LOC_A101 load completed');


    /* ========================================================================
       LOAD: ERP_PRD_INFO
       ======================================================================== */

    SYSTEM$LOG_INFO('>> Truncating SILVER.ERP_PRD_INFO');

    TRUNCATE TABLE silver.erp_prd_info;

    SYSTEM$LOG_INFO('>> Loading SILVER.ERP_PRD_INFO');

    INSERT INTO silver.erp_prd_info
    (
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt
    )
    SELECT
        prd_id,

        /* Extract and standardize category ID */
        REPLACE(
            SUBSTR(prd_key, 1, 5),
            '-',
            '_'
        ) AS cat_id,

        /* Remove category prefix from product key */
        SUBSTR(prd_key, 7) AS prd_key,

        prd_nm,

        /* Replace missing product cost */
        COALESCE(prd_cost, 0) AS prd_cost,

        /* Standardize product line */
        CASE UPPER(TRIM(prd_line))
            WHEN 'M' THEN 'Mountain'
            WHEN 'R' THEN 'Road'
            WHEN 'S' THEN 'Other Sales'
            WHEN 'T' THEN 'Touring'
            ELSE 'n/a'
        END AS prd_line,

        CAST(prd_start_dt AS DATE) AS prd_start_dt,

        /* Derive end date using the next product start date */
        DATEADD(
            DAY,
            -1,
            LEAD(CAST(prd_start_dt AS DATE))
            OVER
            (
                PARTITION BY prd_key
                ORDER BY prd_start_dt
            )
        ) AS prd_end_dt

    FROM bronze.erp_prd_info;

    SYSTEM$LOG_INFO('>> SILVER.ERP_PRD_INFO load completed');


    /* ========================================================================
       LOAD COMPLETED
       ======================================================================== */

    SYSTEM$LOG_INFO('>> SILVER layer load completed successfully');

    RETURN 'SILVER layer loaded successfully';

END;
$$;


/* =============================================================================
   EXECUTION
   =============================================================================

CALL silver.load_silver();

============================================================================= */
