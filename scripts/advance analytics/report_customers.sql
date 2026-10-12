/* Customer Report → VIEW gold.report_customers | Grain: one row per customer */

CREATE OR REPLACE VIEW gold.report_customers AS

WITH base_query AS (
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
    END                                             AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000  THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END                                             AS customer_segment,
    last_order_date,
    DATEDIFF(month, last_order_date, CURRENT_DATE)  AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END                                             AS avg_order_value,
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan, 2)
    END                                             AS avg_monthly_spend
FROM customer_aggregation;
