/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze) in Snowflake
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external
    CSV files staged in @bronze.my_stage. It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `COPY INTO` command to load data from CSV files into bronze
      tables (Snowflake's equivalent of SQL Server's BULK INSERT).
    - Logs each step and timing into a returned STRING (Snowflake has no
      PRINT statement for stored procedures).
    - Catches and reports any error via the EXCEPTION block.

Parameters:
    None.
    This stored procedure accepts no parameters.

Returns:
    STRING - a full text log of the load run, or an error report if the
    run failed.

Usage Example:
    CALL bronze.load_bronze();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    start_time       TIMESTAMP_NTZ;
    end_time         TIMESTAMP_NTZ;
    batch_start_time TIMESTAMP_NTZ;
    batch_end_time   TIMESTAMP_NTZ;
    log_msg          STRING DEFAULT '';
BEGIN
    batch_start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '================================================\n';
    log_msg := log_msg || 'Loading Bronze Layer\n';
    log_msg := log_msg || '================================================\n';

    log_msg := log_msg || '------------------------------------------------\n';
    log_msg := log_msg || 'Loading CRM Tables\n';
    log_msg := log_msg || '------------------------------------------------\n';

    -- crm_cust_info
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: bronze.crm_cust_info\n';
    TRUNCATE TABLE IF EXISTS bronze.crm_cust_info;
    log_msg := log_msg || '>> Inserting Data Into: bronze.crm_cust_info\n';
    COPY INTO bronze.crm_cust_info
        FROM @bronze.my_stage/cust_info.csv
        FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';

    -- crm_prd_info
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: bronze.crm_prd_info\n';
    TRUNCATE TABLE IF EXISTS bronze.crm_prd_info;
    log_msg := log_msg || '>> Inserting Data Into: bronze.crm_prd_info\n';
    COPY INTO bronze.crm_prd_info
        FROM @bronze.my_stage/prd_info.csv
        FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';

    -- crm_sales_details
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: bronze.crm_sales_details\n';
    TRUNCATE TABLE IF EXISTS bronze.crm_sales_details;
    log_msg := log_msg || '>> Inserting Data Into: bronze.crm_sales_details\n';
    COPY INTO bronze.crm_sales_details
        FROM @bronze.my_stage/sales_details.csv
        FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';

    log_msg := log_msg || '------------------------------------------------\n';
    log_msg := log_msg || 'Loading ERP Tables\n';
    log_msg := log_msg || '------------------------------------------------\n';

    -- erp_loc_a101
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: bronze.erp_loc_a101\n';
    TRUNCATE TABLE IF EXISTS bronze.erp_loc_a101;
    log_msg := log_msg || '>> Inserting Data Into: bronze.erp_loc_a101\n';
    COPY INTO bronze.erp_loc_a101
        FROM @bronze.my_stage/loc_a101.csv
        FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';

    -- erp_cust_az12
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: bronze.erp_cust_az12\n';
    TRUNCATE TABLE IF EXISTS bronze.erp_cust_az12;
    log_msg := log_msg || '>> Inserting Data Into: bronze.erp_cust_az12\n';
    COPY INTO bronze.erp_cust_az12
        FROM @bronze.my_stage/cust_az12.csv
        FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';

    -- erp_px_cat_g1v2
    start_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Truncating Table: bronze.erp_px_cat_g1v2\n';
    TRUNCATE TABLE IF EXISTS bronze.erp_px_cat_g1v2;
    log_msg := log_msg || '>> Inserting Data Into: bronze.erp_px_cat_g1v2\n';
    COPY INTO bronze.erp_px_cat_g1v2
        FROM @bronze.my_stage/px_cat_g1v2.csv
        FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
    end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '>> Load Duration: ' || DATEDIFF('second', start_time, end_time) || ' seconds\n';
    log_msg := log_msg || '>> -------------\n';

    batch_end_time := CURRENT_TIMESTAMP();
    log_msg := log_msg || '==========================================\n';
    log_msg := log_msg || 'Loading Bronze Layer is Completed\n';
    log_msg := log_msg || '   - Total Load Duration: ' || DATEDIFF('second', batch_start_time, batch_end_time) || ' seconds\n';
    log_msg := log_msg || '==========================================\n';

    RETURN log_msg;

EXCEPTION
    WHEN OTHER THEN
        RETURN '==========================================\n' ||
               'ERROR OCCURRED DURING LOADING BRONZE LAYER\n' ||
               'Error Message: ' || SQLERRM || '\n' ||
               'Error Code: '    || SQLCODE || '\n' ||
               'Error State: '   || SQLSTATE || '\n' ||
               '==========================================\n';
END;
$$;

