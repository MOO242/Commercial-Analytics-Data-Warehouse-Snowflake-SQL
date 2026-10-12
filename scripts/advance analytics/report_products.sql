/* Product Report → VIEW gold.report_products | Grain: one row per product */

CREATE OR REPLACE VIEW gold.report_products AS

WITH product_base AS (
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

SELECT
    product_key,
    product_name,
    category,
    sub_category,
    CASE
        WHEN total_sales <= 90000  THEN 'Low Performance'
        WHEN total_sales <= 130000 THEN 'Mid Performance'
        ELSE 'High Performance'
    END                                             AS product_segment,
    last_sale_date,
    DATEDIFF(month, last_sale_date, CURRENT_DATE)   AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    lifespan,
    CASE
        WHEN total_orders = 0 THEN 0
        ELSE ROUND(total_sales / total_orders, 2)
    END                                             AS avg_order_revenue,
    CASE
        WHEN lifespan = 0 THEN total_orders
        ELSE ROUND(total_orders / lifespan, 2)
    END                                             AS avg_monthly_orders,
    CASE
        WHEN lifespan = 0 THEN total_sales
        ELSE ROUND(total_sales / lifespan, 2)
    END                                             AS avg_monthly_sales
FROM product_aggregation;
