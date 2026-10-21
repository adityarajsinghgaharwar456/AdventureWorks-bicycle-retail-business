# Gold Layer — Data Warehouse Documentation

> **Purpose:** Turn the cleaned Silver Layer data into a simpler, business-friendly model that can be used for reporting, analysis and dashboards.

The Gold Layer is the final modelling stage of this data warehousing project. Instead of asking a report user to join several source tables every time, it provides two dimension views and one sales fact view with clearer column names and the relationships already prepared.

---

## 1. Project at a glance

| Item | Details |
|---|---|
| Schema | `gold_layer` |
| Source schema | `silver_layer` |
| Data model | Star-schema style model |
| Dimension views | `dim_customers`, `dim_products` |
| Fact view | `fact_sales` |
| Main purpose | Make customer, product and sales data easier to understand and analyse |
| SQL features used | `CREATE VIEW`, `SELECT`, `LEFT JOIN`, `CASE`, `ROW_NUMBER()` and `WHERE` |

### What happens in the Gold Layer?

- **Customer dimension:** Combines CRM customer information with ERP customer details and location.
- **Product dimension:** Combines product information with its category and subcategory details. Products with an end date are excluded.
- **Sales fact:** Uses sales transactions as the central table and connects each sale to the customer and product dimensions.

These objects are created as **views** in the SQL script. A view stores the query definition rather than a separate, physically loaded copy of the query result.

---

## 2. Data warehouse flow in Gold_layer


+----------------------------------+
| Gold Layer                       |
|                                  |
| dim_customers  dim_products      |
|        \          /              |
|         \        /               |
|          fact_sales              |
|                                  |
| Reporting-ready views            |
+----------------------------------+
```

**Bronze** is where source data is brought in and load activity is checked. **Silver** prepares the data for use by cleaning and standardising it. **Gold** presents the prepared data in a model that is easier for business users to work with.

---



| Fact column | Dimension column | Join used in SQL | Why it matters |
|---|---|---|---|
| `fact_sales.customer_key` | `dim_customers.customer_key` | Customer key is selected after joining sales to the customer dimension | Adds customer context to each sale |
| `fact_sales.product_key` | `dim_products.product_key` | Product key is selected after joining sales to the product dimension | Adds product context to each sale |

The script creates these relationships through the joins in the `fact_sales` view; it does not define physical foreign-key constraints. The `LEFT JOIN`s preserve sales rows even when a matching dimension row is not found, although the dimension key would then be `NULL`.

**Important implementation note:** Both dimension keys are generated with `ROW_NUMBER() OVER()` in views. Row numbers are not permanent identifiers and can change if the query's row order changes. For a production model, use a deterministic ordering and preferably persist surrogate keys in tables (or use a stable key-management approach) before relying on them as long-lived foreign keys.

---

## 4. `dim_customers` — Customer dimension

**Built from:** `silver_layer.crm_cust_info`, `silver_layer.erp_cust_details` and `silver_layer.erp_location`.

The view brings together customer identity, name, gender, marital status, birth date, country and record creation date.

### Transformation rules

1. A new `customer_key` is generated with `ROW_NUMBER() OVER()`.
2. `customer_id` and `customer_number` retain the original CRM identifiers under clearer names.
3. First and last name are combined into `full_name`.
4. When CRM gender (`cst_gndr`) is `'Unknown'`, the query uses ERP gender (`gen`). Otherwise, it keeps the CRM gender.
5. Customer details and location are joined with `LEFT JOIN`, so a customer is not removed merely because a matching ERP record is missing.

### Column reference

| Column | Data type | Description / feature |
|---|---|---|
| `customer_key` | `BIGINT` (from `ROW_NUMBER()`) | Generated surrogate key used to link sales to the customer dimension. |
| `customer_id` | `INTEGER` | Original CRM customer ID. |
| `customer_number` | `VARCHAR(50)` | Business/customer reference from `cst_key`. |
| `full_name` | `TEXT`* | First and last name combined into one field. |
| `gender` | `VARCHAR(50)`* | Gender after applying the CRM-first fallback rule. |
| `marital_status` | `VARCHAR(50)`* | Customer marital status from CRM. |
| `birth_date` | `DATE` | Customer date of birth from ERP customer details. |
| `cntry` | `VARCHAR(50)`* | Country from the ERP location data. |
| `create_date` | `DATE` | Date the CRM customer record was created. |

\*Types marked with an asterisk are expected from the source columns or PostgreSQL expression behaviour; confirm the exact resulting type in the database if the column widths/types are required for formal schema documentation. `concat()` returns `TEXT` in PostgreSQL.

---

## 5. `dim_products` — Product dimension

**Built from:** `silver_layer.crm_prd_info` and `silver_layer.erp_prd_cat`.

The view combines product identifiers and attributes with product category, subcategory and maintenance information.

### Transformation rules

1. A new `product_key` is generated with `ROW_NUMBER() OVER()`.
2. Product category details are added by joining `prd_cat_id` to the category table's `id`.
3. `WHERE prd_end_dt IS NULL` keeps products whose production end date is not populated. In this project, that is being used as the rule for currently active products.
4. Product identifiers and names are renamed to more readable labels for reporting.

### Column reference

| Column | Data type | Description / feature |
|---|---|---|
| `product_key` | `BIGINT` (from `ROW_NUMBER()`) | Generated surrogate key used to link sales to the product dimension. |
| `product_id` | `INTEGER` | Original CRM product ID. |
| `product_number` | `VARCHAR(50)` | Product reference/code used to match sales to the product. |
| `category_id` | `VARCHAR(50)`* | Category identifier from the product record. |
| `prd_line` | `VARCHAR(50)`* | Product line, such as Road, Mountains or Touring. The source-style name is retained. |
| `product_categories` | `VARCHAR(50)`* | Main product category. |
| `product_subcategories` | `VARCHAR(50)`* | More specific product subcategory. |
| `product_name` | `VARCHAR(50)`* | Readable product name. |
| `product_cost` | `INTEGER`* | Product cost from the CRM product data. |
| `production_start_date` | `DATE` | Date production started. |
| `maintenance` | `VARCHAR(50)`* | Maintenance attribute from the ERP category data. |

\*Confirm the exact PostgreSQL type and length in the database, as CSV type inference does not prove the database column definition. The source model shows several text fields as `character varying(50)` and `prd_cost` as `integer`.

**Data note:** The supplied product CSV contains 295 rows. Seven rows have missing category, subcategory and maintenance values. These values should be checked against the source/category mapping if complete product classification is required.

---

## 6. `fact_sales` — Sales fact

**Built from:** `silver_layer.crm_sales_details`, joined to `gold_layer.dim_products` and `gold_layer.dim_customers`.

This view keeps the sales transaction fields and replaces the source product/customer references with the corresponding dimension surrogate keys.

### Transformation rules

1. Sales data is selected from `crm_sales_details`.
2. Sales product code (`sls_prd_key`) is matched to `dim_products.product_number`.
3. Sales customer ID (`sls_cust_id`) is matched to `dim_customers.customer_id`.
4. The matched dimension keys are selected for analysis by customer and product.
5. Order, shipping and due dates, quantity, price and sales amount are given simpler column names.

### Column reference

| Column | Data type | Description / feature |
|---|---|---|
| `order_no` | `VARCHAR(50)`* | Sales order reference from `sls_ord_num`. Multiple line items can belong to one order in a typical sales model; check the actual grain before treating this as a unique row key. |
| `product_key` | `BIGINT` (from dimension view) | Product dimension key associated with the sale. |
| `customer_key` | `BIGINT` (from dimension view) | Customer dimension key associated with the sale. |
| `order_date` | `DATE` | Date the order was placed. |
| `ship_date` | `DATE` | Date the order was shipped. |
| `due_date` | `DATE` | Expected/due date for the order. |
| `quantity` | `INTEGER` | Quantity recorded for the sales row. |
| `price` | `NUMERIC`* | Price value from `sls_price`. |
| `total_sales` | `NUMERIC`* | Sales amount from `sls_sales`; use this field for sales totals when it matches the agreed business definition. |

\*The exact type/length for fields inherited from source columns should be confirmed from the PostgreSQL schema. The source Silver model identifies the sales amount and price fields as numeric, and quantity as integer.

### Fact table grain

Based on the selected columns, each row represents a row from `crm_sales_details` after the dimension joins. Do **not** assume that one row always equals one whole order: validate the source grain, especially if an order can contain multiple products or line items.

---

## 7. SQL techniques used

| SQL feature | How it is used here | Why it is useful |
|---|---|---|
| `CREATE VIEW` | Creates the three Gold Layer views | Gives users a reusable, named query without copying the query each time. |
| `LEFT JOIN` | Combines CRM and ERP data, and connects sales to dimensions | Keeps rows from the left/source table even when a match is missing. |
| `CASE WHEN` | Uses ERP gender when CRM gender is `'Unknown'` | Applies a clear business rule to resolve duplicate/conflicting attributes. |
| `ROW_NUMBER()` | Creates `customer_key` and `product_key` | Generates sequential row numbers for use as surrogate keys in the current model. |
| `WHERE` | Filters products using `prd_end_dt IS NULL` | Applies the project's active-product selection rule. |
| Column aliases (`AS`) | Converts source codes into clearer names | Makes the views easier to read in SQL, BI tools and reports. |

---

## 8. CSV reference files and scope of validation

The CSV files supplied with this project are **reference extracts only**. They were shared to help illustrate the output structure and understand the columns; they are not complete exports of the Gold Layer views. For that reason, this README does not present their row counts, totals or missing-value counts as results for the full warehouse.

The actual output counts and data-quality results should be obtained by running validation queries against the complete database. The SQL checks in the next section are intended for that purpose.

| Reference file | How it is used in this documentation | What it should not be used to claim |
|---|---|---|
| `dim_customers.csv` | Helps illustrate customer dimension columns and example values | Full customer count or complete customer data-quality results |
| `dim_products.csv` | Helps illustrate product dimension columns and example values | Full product count or complete classification-quality results |
| `fact_sales.csv` | Helps illustrate the sales fact structure and example values | Full sales volume, revenue totals or complete relationship-validation results |

**Portfolio note:** Any figures shown from these files would describe only the supplied sample, not necessarily the complete data warehouse. This README therefore avoids treating sample figures as project-wide results.

---

## 9. Validation checklist

Before treating the Gold Layer as ready for a dashboard or portfolio presentation, these checks are worth keeping:

- [ ] Confirm all three views can be queried successfully.
- [ ] Compare row counts with the Silver source tables and explain any expected difference, especially the product end-date filter.
- [ ] Check that `customer_key` and `product_key` are unique in their respective dimensions.
- [ ] Check that all fact dimension keys match a row in the appropriate dimension.
- [ ] Review missing customer birth dates and missing product classification fields using the complete Gold Layer data, not only the reference CSV extracts.
- [ ] Confirm the business definition of `total_sales` and whether `price` is unit price or another price measure.
- [ ] Confirm the grain of `fact_sales` before using order counts or average order value.
- [ ] Replace view-generated row numbers with stable surrogate keys if the model will be refreshed and used as a persistent reporting model.
- [ ] Verify exact view column types using PostgreSQL metadata before publishing formal data contracts.

---

## 10. Useful verification queries

### View row counts

```sql
SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count
FROM gold_layer.dim_customers

UNION ALL

SELECT 'dim_products', COUNT(*)
FROM gold_layer.dim_products

UNION ALL

SELECT 'fact_sales', COUNT(*)
FROM gold_layer.fact_sales;
```

### Check dimension key uniqueness

```sql
SELECT customer_key, COUNT(*) AS row_count
FROM gold_layer.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

SELECT product_key, COUNT(*) AS row_count
FROM gold_layer.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;
```

### Check for unmatched fact dimension keys

```sql
SELECT COUNT(*) AS missing_customer_matches
FROM gold_layer.fact_sales f
LEFT JOIN gold_layer.dim_customers c
    ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;

SELECT COUNT(*) AS missing_product_matches
FROM gold_layer.fact_sales f
LEFT JOIN gold_layer.dim_products p
    ON f.product_key = p.product_key
WHERE p.product_key IS NULL;
```

### Inspect actual view column types

```sql
SELECT
    table_name,
    column_name,
    data_type,
    character_maximum_length
FROM information_schema.columns
WHERE table_schema = 'gold_layer'
  AND table_name IN ('dim_customers', 'dim_products', 'fact_sales')
ORDER BY table_name, ordinal_position;
```

---

## Final note

The Gold Layer brings the cleaned customer, product and sales data into a model that is easier to query and explain. The two dimensions provide descriptive context, while the sales fact view connects transactions to those dimensions. The main follow-up improvement is to make the surrogate keys stable across refreshes and to keep the data-quality checks as part of the loading workflow.
