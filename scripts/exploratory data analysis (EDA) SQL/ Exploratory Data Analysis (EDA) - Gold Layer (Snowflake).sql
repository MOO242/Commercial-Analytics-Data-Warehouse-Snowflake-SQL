/*
===============================================================================
SQL Exploratory Data Analysis (EDA) - Gold Layer (Snowflake)
===============================================================================
Project:
    Commercial Analytics Data Warehouse - Snowflake SQL
    Author: Mohamed Al Razek

Script Purpose:
    Explores the Gold layer star schema (gold.fact_sales, gold.dim_customers,
    gold.dim_products) to understand the data before advanced analytics.
    The script follows six EDA steps:
        1. Database Exploration
        2. Dimensions Exploration
        3. Date Exploration
        4. Measures Exploration (Big Numbers + KPI report)
        5. Magnitude Analysis
        6. Ranking Analysis (Top / Bottom N)

Prerequisites:
    - The Gold views exist (run the Gold DDL script first).
    - Gold quality checks have passed.

SQL Functions Used:
    COUNT, COUNT(DISTINCT), SUM, AVG, MIN, MAX, DATEDIFF, CURRENT_DATE,
    UNION ALL, ROW_NUMBER(), RANK(), DENSE_RANK(), QUALIFY, ||

Credit:
    Based on the SQL EDA Project by Data with Baraa, adapted for Snowflake.
===============================================================================
*/

-- Set the context (change these names to match your account)
-- USE WAREHOUSE <your_warehouse>;
-- USE DATABASE  <your_database>;


/*
===============================================================================
1. Database Exploration
===============================================================================
Purpose:
    - List the objects in the database and check the column structure.
===============================================================================
*/

-- 1.1 All tables and views in the database
SELECT
    table_catalog,
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema <> 'INFORMATION_SCHEMA'
ORDER BY table_schema, table_name;

-- 1.2 Columns of a specific Gold view
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'GOLD'
  AND table_name   = 'DIM_CUSTOMERS'
ORDER BY ordinal_position;


/*
===============================================================================
2. Dimensions Exploration
===============================================================================
Purpose:
    - Show the distinct values of the main dimension columns.
===============================================================================
*/

-- 2.1 Countries our customers come from
SELECT DISTINCT country
FROM gold.dim_customers
ORDER BY country;

-- 2.2 Product hierarchy: category -> subcategory -> product
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY category, subcategory, product_name;


/*
===============================================================================
3. Date Exploration
===============================================================================
Purpose:
    - Find the time range covered by the data.
    - Find the youngest and oldest customers.
===============================================================================
*/

-- 3.1 First and last order date, and the span in years and months
SELECT
    MIN(order_date)                                    AS first_order_date,
    MAX(order_date)                                    AS last_order_date,
    DATEDIFF(year,  MIN(order_date), MAX(order_date))  AS order_range_years,
    DATEDIFF(month, MIN(order_date), MAX(order_date))  AS order_range_months
FROM gold.fact_sales;

-- 3.2 Youngest and oldest customer
-- Note: DATEDIFF(year, ...) counts year boundaries, so age can be 1 year high
--       before the birthday. This is fine for exploration.
SELECT
    MIN(birthdate)                                     AS oldest_birthdate,
    DATEDIFF(year, MIN(birthdate), CURRENT_DATE)       AS oldest_age,
    MAX(birthdate)                                     AS youngest_birthdate,
    DATEDIFF(year, MAX(birthdate), CURRENT_DATE)       AS youngest_age
FROM gold.dim_customers;


/*
===============================================================================
4. Measures Exploration (Big Numbers)
===============================================================================
Purpose:
    - Calculate the key business totals.
Notes:
    - fact_sales is at order-line grain, so one order can have several rows.
      Use COUNT(DISTINCT order_number) for the number of orders.
===============================================================================
*/

-- 4.1 Total sales
SELECT SUM(sales_amount) AS total_sales FROM gold.fact_sales;

-- 4.2 Total items sold
SELECT SUM(quantity) AS total_quantity FROM gold.fact_sales;

-- 4.3 Average selling price
SELECT AVG(price) AS avg_price FROM gold.fact_sales;

-- 4.4 Total orders (line count vs distinct orders)
SELECT
    COUNT(order_number)           AS total_order_lines,
    COUNT(DISTINCT order_number)  AS total_orders
FROM gold.fact_sales;

-- 4.5 Total products
SELECT COUNT(DISTINCT product_key) AS total_products FROM gold.dim_products;

-- 4.6 Total customers
SELECT COUNT(DISTINCT customer_key) AS total_customers FROM gold.dim_customers;

-- 4.7 Customers who have placed at least one order
SELECT COUNT(DISTINCT customer_key) AS total_ordering_customers FROM gold.fact_sales;

-- 4.8 KPI report: all key metrics in one result
SELECT 'Total Sales'        AS measure_name, SUM(sales_amount)            AS measure_value FROM gold.fact_sales
UNION ALL
SELECT 'Total Quantity',                     SUM(quantity)                                 FROM gold.fact_sales
UNION ALL
SELECT 'Average Price',                      ROUND(AVG(price), 2)                          FROM gold.fact_sales
UNION ALL
SELECT 'Total Orders',                       COUNT(DISTINCT order_number)                  FROM gold.fact_sales
UNION ALL
SELECT 'Total Products',                     COUNT(DISTINCT product_key)                   FROM gold.dim_products
UNION ALL
SELECT 'Total Customers',                    COUNT(DISTINCT customer_key)                  FROM gold.dim_customers
UNION ALL
SELECT 'Ordering Customers',                 COUNT(DISTINCT customer_key)                  FROM gold.fact_sales;


/*
===============================================================================
5. Magnitude Analysis
===============================================================================
Purpose:
    - Compare a measure across a dimension: [Measure] BY [Dimension].
===============================================================================
*/

-- 5.1 Customers by country
SELECT
    country,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY country
ORDER BY total_customers DESC;

-- 5.2 Customers by gender
SELECT
    gender,
    COUNT(customer_key) AS total_customers
FROM gold.dim_customers
GROUP BY gender
ORDER BY total_customers DESC;

-- 5.3 Products by category
SELECT
    category,
    COUNT(product_key) AS total_products
FROM gold.dim_products
GROUP BY category
ORDER BY total_products DESC;

-- 5.4 Average cost by category
SELECT
    category,
    ROUND(AVG(cost), 2) AS avg_cost
FROM gold.dim_products
GROUP BY category
ORDER BY avg_cost DESC;

-- 5.5 Revenue by category
SELECT
    p.category,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
       ON p.product_key = f.product_key
GROUP BY p.category
ORDER BY total_revenue DESC;

-- 5.6 Revenue by customer
-- Group by customer_key (not by name) so customers who share a name stay separate
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name AS full_name,
    SUM(f.sales_amount)                AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
       ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- 5.7 Items sold by country
SELECT
    c.country,
    SUM(f.quantity) AS total_sold_items
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
       ON c.customer_key = f.customer_key
GROUP BY c.country
ORDER BY total_sold_items DESC;


/*
===============================================================================
6. Ranking Analysis (Top / Bottom N)
===============================================================================
Purpose:
    - Rank products and customers by revenue and orders.
How the ranking functions handle ties:
    - ROW_NUMBER() : unique numbers (1,2,3,4).   Use for exactly N rows.
    - RANK()       : ties share a rank, then gaps (1,1,1,4).
    - DENSE_RANK() : ties share a rank, no gaps (1,1,2,3). Use for top N values.
    - Always add a tie-breaker in ORDER BY so ROW_NUMBER() is repeatable.
===============================================================================
*/

-- 6.1 Top 5 products by revenue (simple LIMIT)
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
       ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

-- 6.2 Top 5 products by revenue (window function + QUALIFY)
SELECT
    p.product_name,
    SUM(f.sales_amount)                                    AS total_revenue,
    RANK() OVER (ORDER BY SUM(f.sales_amount) DESC)        AS rank_products
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
       ON p.product_key = f.product_key
GROUP BY p.product_name
QUALIFY rank_products <= 5
ORDER BY rank_products;

-- 6.3 Bottom 5 products by revenue
SELECT
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
       ON p.product_key = f.product_key
GROUP BY p.product_name
ORDER BY total_revenue ASC
LIMIT 5;

-- 6.4 Top 10 customers by revenue
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name AS full_name,
    SUM(f.sales_amount)                AS total_revenue
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
       ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
QUALIFY ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) DESC, c.customer_key) <= 10
ORDER BY total_revenue DESC;

-- 6.5 The 3 customers with the fewest orders (exactly 3 rows)
-- COUNT(DISTINCT order_number) counts orders, not order lines.
-- ROW_NUMBER() + customer_key tie-breaker gives a repeatable result.
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name AS full_name,
    COUNT(DISTINCT f.order_number)     AS total_orders
FROM gold.fact_sales f
JOIN gold.dim_customers c
  ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
QUALIFY ROW_NUMBER() OVER (
            ORDER BY COUNT(DISTINCT f.order_number) ASC, c.customer_key
        ) <= 3
ORDER BY total_orders, c.customer_key;

-- 6.6 Customers in the 3 lowest order-count levels (keeps all ties)
-- Expect many rows: most customers have only 1 order.
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name                              AS full_name,
    COUNT(DISTINCT f.order_number)                                  AS total_orders,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT f.order_number) ASC) AS order_level
FROM gold.fact_sales f
JOIN gold.dim_customers c
  ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
QUALIFY order_level <= 3
ORDER BY order_level, full_name;

-- 6.7 Check: how big are the ties? (customers per order count)
SELECT
    total_orders,
    COUNT(*) AS customers
FROM (
    SELECT
        customer_key,
        COUNT(DISTINCT order_number) AS total_orders
    FROM gold.fact_sales
    GROUP BY customer_key
) t
GROUP BY total_orders
ORDER BY total_orders;

-- 6.8 ROW_NUMBER vs RANK vs DENSE_RANK side by side
SELECT
    c.customer_key,
    c.first_name || ' ' || c.last_name                                                    AS full_name,
    COUNT(DISTINCT f.order_number)                                                        AS total_orders,
    ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT f.order_number) DESC, c.customer_key)      AS row_num,
    RANK()       OVER (ORDER BY COUNT(DISTINCT f.order_number) DESC)                      AS rnk,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT f.order_number) DESC)                      AS dense_rnk
FROM gold.fact_sales f
JOIN gold.dim_customers c
  ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY row_num
LIMIT 20;

/*
===============================================================================
End of EDA script
===============================================================================
*/
