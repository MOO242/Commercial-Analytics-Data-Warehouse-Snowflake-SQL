-- ############################################################
-- FILE: tests/validation_checks.sql
-- ############################################################

/* ============================================================
   Validation Checks for the reporting views
   Every query states its EXPECTED result.
   ============================================================ */

-- =========================
-- CUSTOMER REPORT
-- =========================

-- 1. Grain: no duplicate customers            EXPECTED: 0 rows
SELECT customer_key, COUNT(*) AS cnt
FROM gold.report_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- 2. Completeness: rows = customers with sales  EXPECTED: diff = 0
SELECT
    (SELECT COUNT(*) FROM gold.report_customers)                         AS report_rows,
    (SELECT COUNT(DISTINCT customer_key) FROM gold.fact_sales
      WHERE order_date IS NOT NULL)                                      AS source_customers,
    report_rows - source_customers                                       AS diff;

-- 3. Reconciliation: sales match source        EXPECTED: diff = 0
SELECT
    (SELECT SUM(total_sales) FROM gold.report_customers)                 AS report_sales,
    (SELECT SUM(sales) FROM gold.fact_sales WHERE order_date IS NOT NULL) AS source_sales,
    report_sales - source_sales                                          AS diff;

-- 4. Sanity: no NULL / negative KPIs           EXPECTED: 0
SELECT COUNT(*) AS bad_rows
FROM gold.report_customers
WHERE avg_order_value   IS NULL OR avg_order_value   < 0
   OR avg_monthly_spend IS NULL OR avg_monthly_spend < 0
   OR recency < 0 OR lifespan < 0;

-- 5. Segment distribution (review)
SELECT customer_segment, COUNT(*) AS customers
FROM gold.report_customers
GROUP BY customer_segment
ORDER BY customers DESC;

-- =========================
-- PRODUCT REPORT
-- =========================

-- 6. Grain: no duplicate products              EXPECTED: 0 rows
SELECT product_key, COUNT(*) AS cnt
FROM gold.report_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- 7. Completeness: rows = products with sales  EXPECTED: diff = 0
SELECT
    (SELECT COUNT(*) FROM gold.report_products)                          AS report_rows,
    (SELECT COUNT(DISTINCT product_key) FROM gold.fact_sales
      WHERE order_date IS NOT NULL)                                      AS source_products,
    report_rows - source_products                                        AS diff;

-- 8. Reconciliation: sales match source        EXPECTED: diff = 0
--    (fact rows without a matching product are excluded by the INNER JOIN;
--     a non-zero diff means orphan product_keys in fact_sales)
SELECT
    (SELECT SUM(total_sales) FROM gold.report_products)                  AS report_sales,
    (SELECT SUM(sales) FROM gold.fact_sales WHERE order_date IS NOT NULL) AS source_sales,
    report_sales - source_sales                                          AS diff;

-- 9. Sanity: no NULL / negative KPIs           EXPECTED: 0
SELECT COUNT(*) AS bad_rows
FROM gold.report_products
WHERE avg_order_revenue  IS NULL OR avg_order_revenue  < 0
   OR avg_monthly_orders IS NULL OR avg_monthly_orders < 0
   OR avg_monthly_sales  IS NULL OR avg_monthly_sales  < 0
   OR recency < 0 OR lifespan < 0;

-- 10. Segment distribution (review)
SELECT product_segment, COUNT(*) AS products, SUM(total_sales) AS sales
FROM gold.report_products
GROUP BY product_segment
ORDER BY sales DESC;

-- 11. Referential integrity: orphan keys in fact  EXPECTED: 0 rows
SELECT s.product_key, s.customer_key
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_products  AS p ON s.product_key  = p.product_key
LEFT JOIN gold.dim_customers AS c ON s.customer_key = c.customer_key
WHERE p.product_key IS NULL OR c.customer_key IS NULL;



