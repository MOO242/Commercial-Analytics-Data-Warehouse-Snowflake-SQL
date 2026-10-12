-- ############################################################
-- FILE: scripts/01_eda/01_database_exploration.sql
-- ############################################################

/* ============================================================
   01 - Database Exploration
   Purpose : List the objects and columns available in the Gold layer.
   ============================================================ */

-- All tables/views in the gold schema
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'GOLD'
ORDER BY table_name;

-- Columns of each gold object
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'GOLD'
ORDER BY table_name, ordinal_position;


-- ############################################################
-- FILE: scripts/01_eda/02_dimensions_exploration.sql
-- ############################################################

/* ============================================================
   02 - Dimensions Exploration
   Purpose : Understand the distinct values in each dimension.
   ============================================================ */

-- Countries customers come from
SELECT DISTINCT country
FROM gold.dim_customers
ORDER BY country;

-- Product hierarchy: category > sub_category > product
SELECT DISTINCT category, sub_category, product_name
FROM gold.dim_products
ORDER BY category, sub_category, product_name;


-- ############################################################
-- FILE: scripts/01_eda/03_date_exploration.sql
-- ############################################################

/* ============================================================
   03 - Date Exploration
   Purpose : Find the date coverage of sales and customer ages.
   ============================================================ */

-- First / last order and the span in months
SELECT
    MIN(order_date)                                    AS first_order_date,
    MAX(order_date)                                    AS last_order_date,
    DATEDIFF(month, MIN(order_date), MAX(order_date))  AS order_range_months
FROM gold.fact_sales;

-- Youngest and oldest customer
SELECT
    MIN(birthdate)                                 AS oldest_birthdate,
    DATEDIFF(year, MIN(birthdate), CURRENT_DATE)   AS oldest_age,
    MAX(birthdate)                                 AS youngest_birthdate,
    DATEDIFF(year, MAX(birthdate), CURRENT_DATE)   AS youngest_age
FROM gold.dim_customers;


-- ############################################################
-- FILE: scripts/01_eda/04_measures_exploration.sql
-- ############################################################

/* ============================================================
   04 - Measures Exploration
   Purpose : Key business totals in one report.
   ============================================================ */

SELECT 'Total Sales'        AS measure_name, SUM(sales)                     AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity',                     SUM(quantity)                                   FROM gold.fact_sales
UNION ALL
SELECT 'Average Price',                      ROUND(AVG(price), 2)                            FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders',                       COUNT(DISTINCT order_number)                    FROM gold.fact_sales
UNION ALL
SELECT 'Total Products',                     COUNT(DISTINCT product_key)                     FROM gold.dim_products
UNION ALL
SELECT 'Total Customers',                    COUNT(DISTINCT customer_key)                    FROM gold.dim_customers
UNION ALL
SELECT 'Customers With Orders',              COUNT(DISTINCT customer_key)                    FROM gold.fact_sales;


-- ############################################################
-- FILE: scripts/01_eda/05_magnitude_analysis.sql
-- ############################################################

/* ============================================================
   05 - Magnitude Analysis
   Purpose : Compare measures across dimensions.
   ============================================================ */

-- Customers by country
SELECT country, COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- Revenue by category
SELECT p.category, SUM(s.sales) AS total_sales
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_products AS p
    ON s.product_key = p.product_key
GROUP BY p.category
ORDER BY total_sales DESC;

-- Revenue by customer
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name AS customer_name,
    SUM(s.sales)                       AS total_sales
FROM gold.fact_sales AS s
LEFT JOIN gold.dim_customers AS c
    ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_sales DESC;


-- ############################################################
-- FILE: scripts/01_eda/06_ranking_analysis.sql
-- ############################################################

/* ============================================================
   06 - Ranking Analysis
   Purpose : Top / bottom performers using window ranking.
   ============================================================ */

-- Top 5 products by revenue
SELECT *
FROM (
    SELECT
        p.product_name,
        SUM(s.sales)                              AS total_sales,
        RANK() OVER (ORDER BY SUM(s.sales) DESC)  AS sales_rank
    FROM gold.fact_sales AS s
    JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    GROUP BY p.product_name
) t
WHERE sales_rank <= 5;

-- Bottom 5 products by revenue (Snowflake QUALIFY)
SELECT
    p.product_name,
    SUM(s.sales) AS total_sales
FROM gold.fact_sales AS s
JOIN gold.dim_products AS p
    ON s.product_key = p.product_key
GROUP BY p.product_name
QUALIFY RANK() OVER (ORDER BY SUM(s.sales) ASC) <= 5;

-- Top 10 customers by revenue
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name             AS customer_name,
    SUM(s.sales)                                   AS total_sales,
    DENSE_RANK() OVER (ORDER BY SUM(s.sales) DESC) AS sales_rank
FROM gold.fact_sales AS s
JOIN gold.dim_customers AS c
    ON s.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
QUALIFY sales_rank <= 10;


-- ############################################################
-- FILE: scripts/02_advanced_analytics/07_change_over_time.sql
-- ############################################################

/* ============================================================
   07 - Change Over Time (Trends)
   Purpose : Sales, customers and quantity by month.
   ============================================================ */

SELECT
    DATE_TRUNC('month', order_date)  AS order_month,
    SUM(sales)                       AS total_sales,
    COUNT(DISTINCT customer_key)     AS total_customers,
    SUM(quantity)                    AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY order_month;


-- ############################################################
-- FILE: scripts/02_advanced_analytics/08_cumulative_analysis.sql
-- ############################################################

/* ============================================================
   08 - Cumulative Analysis
   Purpose : Running total of sales and moving average of price.
   Pattern : aggregate in a subquery FIRST, then apply the window.
   ============================================================ */

SELECT
    order_month,
    monthly_sales,
    SUM(monthly_sales) OVER (
        ORDER BY order_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                              AS running_total_sales,
    ROUND(AVG(avg_price) OVER (
        ORDER BY order_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                          AS moving_avg_price_3m
FROM (
    SELECT
        DATE_TRUNC('month', order_date)  AS order_month,
        SUM(sales)                       AS monthly_sales,
        AVG(price)                       AS avg_price
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)
) t
ORDER BY order_month;

-- Running total that resets every year
SELECT
    order_month,
    monthly_sales,
    SUM(monthly_sales) OVER (
        PARTITION BY YEAR(order_month)
        ORDER BY order_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ytd_sales
FROM (
    SELECT DATE_TRUNC('month', order_date) AS order_month, SUM(sales) AS monthly_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATE_TRUNC('month', order_date)
) t
ORDER BY order_month;


-- ############################################################
-- FILE: scripts/02_advanced_analytics/09_performance_analysis.sql
-- ############################################################

/* ============================================================
   09 - Performance Analysis
   Purpose : Compare each product's yearly sales to
             (a) its own average and (b) the previous year.
   ============================================================ */

WITH yearly_product_sales AS (
    SELECT
        YEAR(s.order_date)  AS order_year,
        p.product_name,
        SUM(s.sales)        AS current_sales
    FROM gold.fact_sales AS s
    LEFT JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
    GROUP BY YEAR(s.order_date), p.product_name
)
SELECT
    order_year,
    product_name,
    current_sales,

    -- vs average
    ROUND(AVG(current_sales) OVER (PARTITION BY product_name), 2)                    AS avg_sales,
    current_sales - AVG(current_sales) OVER (PARTITION BY product_name)              AS diff_avg,
    CASE
        WHEN current_sales > AVG(current_sales) OVER (PARTITION BY product_name) THEN 'Above Avg'
        WHEN current_sales < AVG(current_sales) OVER (PARTITION BY product_name) THEN 'Below Avg'
        ELSE 'Avg'
    END                                                                              AS avg_change,

    -- vs previous year
    LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)          AS py_sales,
    current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
    CASE
        WHEN LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) IS NULL THEN 'No Prior Year'
        WHEN current_sales > LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Increase'
        WHEN current_sales < LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Decrease'
        ELSE 'No Change'
    END                                                                              AS py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;


-- ############################################################
-- FILE: scripts/02_advanced_analytics/10_data_segmentation.sql
-- ############################################################

/* ============================================================
   10 - Data Segmentation
   Purpose : Group products by cost range and customers by
             spending behaviour.
   ============================================================ */

-- Products by cost range
WITH product_cost AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost < 100               THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 501 AND 1000 THEN '501-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM gold.dim_products
)
SELECT cost_range, COUNT(product_key) AS total_products
FROM product_cost
GROUP BY cost_range
ORDER BY total_products DESC;

-- Customers by spending behaviour
--   VIP     : >= 12 months history AND spending > 5,000
--   Regular : >= 12 months history AND spending <= 5,000
--   New     : < 12 months history
WITH customer_spending AS (
    SELECT
        customer_key,
        SUM(sales)                                         AS total_sales,
        DATEDIFF(month, MIN(order_date), MAX(order_date))  AS lifespan
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY customer_key
)
SELECT
    customer_segment,
    COUNT(customer_key) AS total_customers
FROM (
    SELECT
        customer_key,
        CASE
            WHEN lifespan >= 12 AND total_sales > 5000  THEN 'VIP'
            WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM customer_spending
) t
GROUP BY customer_segment
ORDER BY total_customers DESC;


-- ############################################################
-- FILE: scripts/02_advanced_analytics/11_part_to_whole.sql
-- ############################################################

/* ============================================================
   11 - Part-to-Whole (Proportional) Analysis
   Purpose : Which categories contribute most to total sales?
   ============================================================ */

WITH category_sales AS (
    SELECT
        p.category,
        SUM(s.sales) AS total_sales
    FROM gold.fact_sales AS s
    LEFT JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    GROUP BY p.category
)
SELECT
    category,
    total_sales,
    SUM(total_sales) OVER ()                                           AS overall_sales,
    ROUND(total_sales / SUM(total_sales) OVER () * 100, 2)             AS pct_of_total,
    ROUND(total_sales / SUM(total_sales) OVER () * 100, 2) || '%'      AS pct_of_total_label
FROM category_sales
ORDER BY total_sales DESC;


-- ############################################################
-- FILE: scripts/03_reports/12_report_customers.sql
-- ############################################################

/* ============================================================
   12 - Customer Report  →  VIEW gold.report_customers
   ------------------------------------------------------------
   Purpose
     Consolidate key customer metrics and behaviours.

   Highlights
     1. Profile fields: name, age
     2. Segments: customer_segment (VIP / Regular / New), age_group
     3. Aggregates: total_orders, total_sales, total_quantity,
                    total_products, lifespan (months)
     4. KPIs: recency, avg_order_value, avg_monthly_spend

   Grain : one row per customer
   ============================================================ */

CREATE OR REPLACE VIEW gold.report_customers AS

WITH base_query AS (
    -- 1) Base: join fact to customer dimension, keep only needed columns
    SELECT
        s.order_number,
        s.product_key,
        s.order_date,
        s.sales,
        s.quantity,
        c.customer_key,
        c.customer_number,
        COALESCE(c.first_name, '') || ' ' || COALESCE(c.last_name, '') AS customer_name,
        DATEDIFF(year, c.birthdate, CURRENT_DATE)                       AS age
    FROM gold.fact_sales AS s
    LEFT JOIN gold.dim_customers AS c
        ON s.customer_key = c.customer_key
    WHERE s.order_date IS NOT NULL
),

customer_aggregation AS (
    -- 2) Aggregate to customer grain
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number)                       AS total_orders,
        SUM(sales)                                         AS total_sales,
        SUM(quantity)                                      AS total_quantity,
        COUNT(DISTINCT product_key)                        AS total_products,
        MAX(order_date)                                    AS last_order_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date))  AS lifespan
    FROM base_query
    GROUP BY customer_key, customer_number, customer_name, age
)

-- 3) Segments and KPIs (outer SELECT → portable, no alias reuse)
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age IS NULL           THEN 'Unknown'
        WHEN age < 20              THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END                                                     AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000  THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END                                                     AS customer_segment,
    last_order_date,
    DATEDIFF(month, last_order_date, CURRENT_DATE)          AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- Average order value
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END                                                     AS avg_order_value,
    -- Average monthly spend
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan, 2)
    END                                                     AS avg_monthly_spend
FROM customer_aggregation;

-- Quick look
-- SELECT * FROM gold.report_customers ORDER BY total_sales DESC LIMIT 10;


-- ############################################################
-- FILE: scripts/03_reports/13_report_products.sql
-- ############################################################

/* ============================================================
   13 - Product Report  →  VIEW gold.report_products
   ------------------------------------------------------------
   Purpose
     Consolidate key product metrics and behaviours.

   Highlights
     1. Attributes: product_name, category, sub_category
     2. Segment: product_segment (Low / Mid / High Performance)
     3. Aggregates: total_orders, total_sales, total_quantity,
                    total_customers, lifespan (months)
     4. KPIs: recency, avg_order_revenue,
              avg_monthly_orders, avg_monthly_sales

   Grain : one row per product
   ============================================================ */

CREATE OR REPLACE VIEW gold.report_products AS

WITH product_base AS (
    -- 1) Base: join fact to product dimension, keep only needed columns
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.sub_category,
        s.order_number,
        s.customer_key,
        s.order_date,
        s.sales,
        s.quantity
    FROM gold.fact_sales AS s
    JOIN gold.dim_products AS p
        ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
),

product_aggregation AS (
    -- 2) Aggregate to product grain
    SELECT
        product_key,
        product_name,
        category,
        sub_category,
        COUNT(DISTINCT order_number)                       AS total_orders,
        SUM(sales)                                         AS total_sales,
        SUM(quantity)                                      AS total_quantity,
        COUNT(DISTINCT customer_key)                       AS total_customers,
        MAX(order_date)                                    AS last_sale_date,
        DATEDIFF(month, MIN(order_date), MAX(order_date))  AS lifespan
    FROM product_base
    GROUP BY product_key, product_name, category, sub_category
)

-- 3) Segment and KPIs (outer SELECT → portable, no alias reuse)
SELECT
    product_key,
    product_name,
    category,
    sub_category,
    CASE
        WHEN total_sales <= 90000  THEN 'Low Performance'
        WHEN total_sales <= 130000 THEN 'Mid Performance'
        ELSE 'High Performance'
    END                                                     AS product_segment,
    last_sale_date,
    DATEDIFF(month, last_sale_date, CURRENT_DATE)           AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    lifespan,
    -- Average order revenue
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END                                                     AS avg_order_revenue,
    -- Average monthly orders
    CASE
        WHEN lifespan = 0 THEN total_orders
        ELSE ROUND(total_orders / lifespan, 2)
    END                                                     AS avg_monthly_orders,
    -- Average monthly sales
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan, 2)
    END                                                     AS avg_monthly_sales
FROM product_aggregation;

-- Quick look
-- SELECT * FROM gold.report_products ORDER BY total_sales DESC LIMIT 10;


