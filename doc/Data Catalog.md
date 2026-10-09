# Data Catalog: Gold Layer (Snowflake)

## Overview

The Gold layer is the business-ready layer of the warehouse. It is modeled as a **star schema** (one fact view and two dimension views) and adds two **reporting views** for BI tools such as Power BI and Tableau.

All Gold objects are **views** built on the Silver layer, so they always reflect the latest Silver load and need no separate load step.

| Object | Type | Grain (one row per…) | Built from (Silver) |
| --- | --- | --- | --- |
| `gold.dim_customers` | Dimension view | Customer | `crm_cust_info` + `erp_cust_az12` + `erp_loc_a101` |
| `gold.dim_products` | Dimension view | Current product | `erp_prd_info` + `crm_px_cat_g1v2` |
| `gold.fact_sales` | Fact view | Order line (`order_number` + `product_key`) | `crm_sales_details` + key lookups to both dimensions |
| `gold.report_customers` | Reporting view | Customer | `fact_sales` + `dim_customers` |
| `gold.report_products` | Reporting view | Product | `fact_sales` + `dim_products` |

**Key conventions**

- **Surrogate keys** (`_key`) are generated in the Gold views with `ROW_NUMBER()` and are used for all joins.
- **Business keys** (`_id`, `_number`) come from the source systems and are kept for traceability.
- Missing text values are standardized to `'n/a'`.

---

## 1. gold.dim_customers

**Purpose:** Stores customer details enriched with demographic and geographic data from the ERP system.

| Column Name | Data Type | Key | Description |
| --- | --- | --- | --- |
| customer_key | NUMBER | PK | Surrogate key uniquely identifying each customer in the dimension. |
| customer_id | NUMBER | BK | Numeric customer identifier from the CRM system. |
| customer_number | VARCHAR | BK | Alphanumeric customer code used to join CRM and ERP data (e.g., `AW00011000`). |
| first_name | VARCHAR |  | Customer’s first name, trimmed of extra spaces. |
| last_name | VARCHAR |  | Customer’s last name or family name, trimmed of extra spaces. |
| country | VARCHAR |  | Country of residence from ERP location data (e.g., `Australia`). |
| marital_status | VARCHAR |  | Marital status, decoded from source codes (`Married`, `Single`, `n/a`). |
| gender | VARCHAR |  | Gender (`Male`, `Female`, `n/a`). CRM is the primary source, and ERP is used as a fallback. |
| birthdate | DATE |  | Date of birth from ERP (e.g., `1971-10-06`). Future dates are set to NULL in Silver. |
| create_date | DATE |  | Date the customer record was created in the CRM system. |

---

## 2. gold.dim_products

**Purpose:** Provides product attributes and category hierarchy. Only **current** products are included (historical versions are filtered out with `end_date IS NULL`).

| Column Name | Data Type | Key | Description |
| --- | --- | --- | --- |
| product_key | NUMBER | PK | Surrogate key uniquely identifying each product in the dimension. |
| product_id | NUMBER | BK | Numeric product identifier from the source system. |
| product_number | VARCHAR | BK | Structured alphanumeric product code (e.g., `BK-R93R-62`). Used to link sales to products. |
| product_name | VARCHAR |  | Descriptive product name, including type, color, and size. |
| category_id | VARCHAR |  | Category code derived from the first 5 characters of the source product key (e.g., `CO_RF`). |
| category | VARCHAR |  | High-level product classification (e.g., `Bikes`, `Components`). |
| subcategory | VARCHAR |  | Detailed classification within the category (e.g., `Road Bikes`). |
| maintenance | VARCHAR |  | Whether the product requires maintenance (`Yes`, `No`). |
| cost | NUMBER |  | Base cost of the product in currency units. Missing values are set to `0` in Silver. |
| product_line | VARCHAR |  | Product line, decoded from source codes (`Mountain`, `Road`, `Touring`, `Other Sales`, `n/a`). |
| start_date | DATE |  | Date the product version became available for sale. |

---

## 3. gold.fact_sales

**Purpose:** Stores transactional sales data at order-line level for analysis.

| Column Name | Data Type | Key | Description |
| --- | --- | --- | --- |
| order_number | VARCHAR |  | Alphanumeric sales order identifier (e.g., `SO54496`). One order can have several lines. |
| product_key | NUMBER | FK | Links the order line to `gold.dim_products`. |
| customer_key | NUMBER | FK | Links the order line to `gold.dim_customers`. |
| order_date | DATE |  | Date the order was placed. Invalid source dates are set to NULL in Silver. |
| shipping_date | DATE |  | Date the order was shipped to the customer. |
| due_date | DATE |  | Date the order payment was due. |
| sales_amount | NUMBER |  | Total value of the order line in currency units. Recalculated in Silver as `quantity × price` when missing or inconsistent. |
| quantity | NUMBER |  | Number of units ordered on the line (e.g., `1`). |
| price | NUMBER |  | Price per unit in currency units. Derived in Silver as `sales_amount ÷ quantity` when missing or invalid. |

**Business rules:** `sales_amount = quantity × price` · `order_date ≤ shipping_date ≤ due_date`

---

## 4. gold.report_customers

**Purpose:** One row per customer with segments, aggregations, and KPIs, ready for BI dashboards.

| Column Name | Data Type | Description |
| --- | --- | --- |
| customer_key | NUMBER | Surrogate key from `dim_customers`. |
| customer_number | VARCHAR | Business customer code. |
| customer_name | VARCHAR | First and last name combined. |
| age | NUMBER | Age in years, based on `birthdate` and the current date. |
| age_group | VARCHAR | `Under 20`, `20-29`, `30-39`, `40-49`, `50 and above`, or `Unknown`. |
| customer_segment | VARCHAR | `VIP` (lifespan ≥ 12 months and sales > 5,000), `Regular` (lifespan ≥ 12 months), or `New` (lifespan < 12 months). |
| last_order_date | DATE | Date of the customer’s most recent order. |
| recency | NUMBER | Months since the last order. |
| total_orders | NUMBER | Count of distinct orders. |
| total_sales | NUMBER | Sum of sales amount. |
| total_quantity | NUMBER | Sum of units purchased. |
| total_products | NUMBER | Count of distinct products purchased. |
| lifespan | NUMBER | Months between the first and last order. |
| avg_order_value | NUMBER | `total_sales ÷ total_orders`. |
| avg_monthly_spend | NUMBER | `total_sales ÷ lifespan` (equals `total_sales` when lifespan is 0). |

---

## 5. gold.report_products

**Purpose:** One row per product with performance segment, aggregations, and KPIs, ready for BI dashboards.

| Column Name | Data Type | Description |
| --- | --- | --- |
| product_key | NUMBER | Surrogate key from `dim_products`. |
| product_name | VARCHAR | Descriptive product name. |
| category | VARCHAR | High-level product classification. |
| subcategory | VARCHAR | Detailed classification within the category. |
| cost | NUMBER | Base cost of the product. |
| last_sale_date | DATE | Date of the most recent sale. |
| recency_in_months | NUMBER | Months since the last sale. |
| product_segment | VARCHAR | `High-Performer` (sales > 50,000), `Mid-Range` (≥ 10,000), or `Low-Performer`. |
| lifespan | NUMBER | Months between the first and last sale. |
| total_orders | NUMBER | Count of distinct orders. |
| total_sales | NUMBER | Sum of sales amount. |
| total_quantity | NUMBER | Sum of units sold. |
| total_customers | NUMBER | Count of distinct customers. |
| avg_selling_price | NUMBER | Average of `sales_amount ÷ quantity`. |
| avg_order_revenue | NUMBER | `total_sales ÷ total_orders`. |
| avg_monthly_revenue | NUMBER | `total_sales ÷ lifespan` (equals `total_sales` when lifespan is 0). |

---

## ✅ Quality Checks

Gold objects are validated by the scripts in `tests/`:

- Surrogate keys are unique in both dimensions.
- Every `fact_sales` row matches a customer and a product (no orphan keys).
- Reporting views have one row per customer and per product.
- Report totals reconcile with `fact_sales`.
