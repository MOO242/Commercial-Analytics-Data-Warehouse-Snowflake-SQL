<img width="4032" height="404" alt="image" src="https://github.com/user-attachments/assets/11f23e49-0c50-4ce3-99ee-9ad93a3d4a68" /># Commercial Analytics Data Warehouse | Snowflake + SQL

Welcome to the **Commercial Analytics Data Warehouse** repository! 🚀
This project builds a complete analytics solution on **Snowflake**: from loading raw CRM and ERP data, through a Medallion data warehouse, to exploratory and advanced SQL analytics that answer real business questions about customers, products, and sales.

> 📚![Uploading image.png…]()

> 

---

## 📌 Project Status

| Phase | Scope | Status |
| --- | --- | --- |
| 1. Data Architecture | Snowflake warehouse, database, schemas, stages | ✅ Done |
| 2. Bronze Layer | Raw CRM/ERP CSVs loaded with `PUT` + `COPY INTO` via `bronze.load_bronze()` | ✅ Done |
| 3. Silver Layer | Cleansing, standardization, and deduplication via `silver.load_silver()` | ✅ Done |
| 4. Gold Layer | Star schema views: `dim_customers`, `dim_products`, `fact_sales` | ✅ Done |
| 5. Data Quality | Gold checks: key uniqueness, grain, referential integrity | ✅ Done |
| 6. Exploratory Data Analysis | Database, dimensions, dates, measures, magnitude, and ranking | ✅ Done |
| 7. Advanced Analytics | Trends, cumulative, performance, part-to-whole, segmentation | 🔄 In progress |
| 8. Reporting Views | `gold.report_customers`, `gold.report_products` | 🔄 In progress |

---

## 🏗️ Data Architecture

The warehouse follows the **Medallion Architecture**, with **Bronze**, **Silver**, and **Gold** layers:

```
CSV (CRM + ERP) ──► Snowflake Stage ──► BRONZE ──► SILVER ──► GOLD ──► SQL Analytics / BI
                     PUT + COPY INTO     raw        clean      star schema
```

1. **Bronze Layer**: Raw data stored as-is from the source systems. CSV files are loaded into Snowflake through an internal stage with `COPY INTO`.
2. **Silver Layer**: Cleansing, standardization, and normalization, including trimming, decoding codes to readable values, deduplicating with `QUALIFY ROW_NUMBER()`, fixing invalid dates, and deriving product end dates with `LEAD()`.
3. **Gold Layer**: Business-ready star schema views with surrogate keys, ready for reporting and analytics.

### Snowflake features used

- Warehouse, database, schemas, and internal stages (Snowsight + Snowflake CLI)
- `PUT` and `COPY INTO` for file loading
- Snowflake Scripting stored procedures (`CALL bronze.load_bronze()`, `CALL silver.load_silver()`) with `SYSTEM$LOG_INFO` logging
- `QUALIFY`, `TRY_TO_DATE`, `CREATE OR REPLACE VIEW`

---

## 📖 Project Overview

This project involves:

1. **Data Architecture**: Designing a modern data warehouse with the Medallion Architecture (**Bronze**, **Silver**, and **Gold** layers).
2. **ETL Pipelines**: Extracting, transforming, and loading CRM and ERP data with Snowflake stored procedures.
3. **Data Modeling**: Building fact and dimension views optimized for analytical queries.
4. **Data Quality**: Validating keys, grain, and relationships before analysis.
5. **Exploratory Data Analysis**: Profiling the Gold layer to understand the data’s scope, distributions, and top/bottom performers.
6. **Advanced Analytics & Reporting**: Answering business questions with window functions and delivering reporting views for BI tools.

🎯 Skills demonstrated in this project:

- SQL Development (Snowflake)
- Data Modeling (Star Schema)
- ETL / ELT Pipelines
- Data Quality & Validation
- Exploratory & Advanced Data Analytics
- Business KPI Reporting

---

## 🚀 Project Requirements

### Building the Data Warehouse (Data Engineering)

#### Objective

Develop a modern data warehouse on Snowflake to consolidate sales data, enabling analytical reporting and informed decision-making.

#### Specifications

- **Data Sources**: Import data from two source systems (ERP and CRM) provided as CSV files.
- **Data Quality**: Cleanse and resolve data quality issues prior to analysis.
- **Integration**: Combine both sources into a single, user-friendly data model designed for analytical queries.
- **Scope**: Focus on the latest dataset only; historization of data is not required.
- **Documentation**: Provide clear documentation of the data model to support both business stakeholders and analytics teams.

---

### BI: Analytics & Reporting (Data Analysis)

#### Objective

Develop SQL-based analytics to deliver detailed insights into:

- **Customer Behavior**
- **Product Performance**
- **Sales Trends**

These insights give stakeholders the key business metrics they need for strategic decisions.

#### ✅ Exploratory Data Analysis (completed)

| Step | Business Question |
| --- | --- |
| Database Exploration | Which objects and columns are available? |
| Dimensions Exploration | Which countries, categories, and products exist? |
| Date Exploration | What time range does the data cover? How old are the customers? |
| Measures Exploration | What are total sales, quantity, orders, products, and customers? (single KPI report) |
| Magnitude Analysis | How do customers and revenue split by country, gender, and category? |
| Ranking Analysis | Who are the top and bottom products and customers? (`ROW_NUMBER`, `RANK`, `DENSE_RANK`) |

#### 🔄 Advanced Analytics (in progress)

| Analysis | Business Question | Key SQL |
| --- | --- | --- |
| Change Over Time | How do sales, customers, and quantity trend by year and month? | `DATE_TRUNC`, `GROUP BY` |
| Cumulative Analysis | Is the business growing over time? | `SUM() OVER`, moving `AVG()` |
| Performance Analysis | Is each product above or below its average and last year? | `AVG() OVER`, `LAG()` |
| Part-to-Whole | Which categories contribute most to total sales? | `SUM() OVER ()` |
| Data Segmentation | How do products split by cost range, and customers into VIP, Regular, and New? | `CASE`, CTEs |
| Customer Report | One row per customer with segments, recency, AOV, and monthly spend | `gold.report_customers` |
| Product Report | One row per product with performance tier, recency, and average revenue | `gold.report_products` |

---

## 📂 Repository Structure

```
Commercial-Analytics-Data-Warehouse-Snowflake-SQL/
│
├── datasets/                           # Raw datasets used for the project (ERP and CRM data)
│
├── docs/                               # Project documentation and architecture details
│   ├── etl.drawio                      # ETL techniques and methods
│   ├── data_architecture.drawio        # Project architecture
│   ├── data_catalog.md                 # Catalog of datasets, including field descriptions and metadata
│   ├── data_flow.drawio                # Data flow diagram
│   ├── data_models.drawio              # Data models (star schema)
│   ├── naming-conventions.md           # Naming guidelines for tables, columns, and files
│
├── scripts/                            # SQL scripts (Snowflake)
│   ├── init_database.sql               # Warehouse, database, schemas, and stages
│   ├── bronze/                         # DDL + load_bronze() procedure for raw data
│   ├── silver/                         # DDL + load_silver() procedure for cleansing and transformation
│   ├── gold/                           # Star schema views (dimensions and fact)
│   ├── eda/                            # Exploratory data analysis on the Gold layer
│   │   └── 01_eda_gold_layer.sql
│   └── analytics/                      # Advanced analytics and reporting views
│       ├── 01_change_over_time.sql
│       ├── 02_cumulative_analysis.sql
│       ├── 03_performance_analysis.sql
│       ├── 04_part_to_whole.sql
│       ├── 05_data_segmentation.sql
│       ├── 06_report_customers.sql
│       └── 07_report_products.sql
│
├── tests/                              # Data quality checks (Silver and Gold)
│
├── README.md                           # Project overview and instructions
└── LICENSE                             # License information for the repository
```

---

## ▶️ How to Run

1. Run `scripts/init_database.sql` to create the warehouse, database, schemas, and stages.
2. Upload the CSVs to the stage (`PUT`), then run the Bronze DDL and `CALL bronze.load_bronze();`
3. Run the Silver DDL, then `CALL silver.load_silver();`
4. Create the Gold views from `scripts/gold/`.
5. Run the quality checks in `tests/`. Every check states its expected result.
6. Run the EDA script, then the analytics scripts in numbered order.

---

## 🙏 Credits

Project design and source datasets by **Baraa Khatib Salkini** (Data With Baraa). This repository is my Snowflake implementation, with Snowflake-specific syntax, procedures, and additional validation checks.

---

## 🛡️ License

This project is licensed under the [MIT](https://github.com/MOO242/Commercial-Analytics-Data-Warehouse-Snowflake-SQL/tree/main?tab=MIT-1-ov-file#)  License. You are free to use, modify, and share this project with proper attribution.
