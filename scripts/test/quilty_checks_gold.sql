/*
===============================================================================
Quality Checks: Gold Layer (Snowflake)
===============================================================================
Script Purpose:
    Validates the integrity, consistency, and accuracy of the Gold layer.
    These checks ensure:
    - Surrogate keys and business keys are unique in the dimension views.
    - The fact view keeps the same grain (row count) as Silver.
    - Every fact row links to a valid customer and product (referential integrity).
    - The data model relationships are reliable for analytics (Power BI, Tableau).

Usage Notes:
    - Run after silver.load_silver() and the Gold view DDL script.
    - Every check states its expected result. Investigate any difference.
===============================================================================
*/

-- ============================================================================
-- Checking gold.dim_customers
-- ============================================================================

-- 1. Uniqueness of the surrogate key (customer_key)
-- Expectation: No results
SELECT
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- 2. Uniqueness of the business key (customer_id)
--    Duplicates here mean an ERP join (az12 / loc_a101) multiplied rows
-- Expectation: No results
SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- 3. Gender integration: review the final values (CRM first, ERP as fallback)
-- Expectation: Only 'Male', 'Female', 'n/a'
SELECT
    gender,
    COUNT(*) AS customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY customers DESC;

-- ============================================================================
-- Checking gold.dim_products
-- ============================================================================

-- 4. Uniqueness of the surrogate key (product_key)
-- Expectation: No results
SELECT
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- 5. Uniqueness of the business key (product_number)
--    Duplicates mean more than one "current" row per product (prd_end_dt IS NULL)
-- Expectation: No results
SELECT
    product_number,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- ============================================================================
-- Checking gold.fact_sales
-- ============================================================================

-- 6. Grain check: the LEFT JOINs must not add or drop rows
-- Expectation: silver_rows = gold_rows
SELECT
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_sales)          AS gold_rows;

-- 7. Referential integrity: fact rows with no matching customer or product
-- Expectation: No results
SELECT
    f.*
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
WHERE f.customer_key IS NULL
   OR f.product_key  IS NULL
   OR c.customer_key IS NULL
   OR p.product_key  IS NULL;

-- 8. Summary of unmatched rows (useful when check 7 returns many rows)
-- Expectation: Both counts = 0
SELECT
    COUNT_IF(customer_key IS NULL) AS missing_customer_key,
    COUNT_IF(product_key  IS NULL) AS missing_product_key
FROM gold.fact_sales;
