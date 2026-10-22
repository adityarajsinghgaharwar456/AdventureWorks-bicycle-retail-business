<div align="center">

# 🥈 Silver Layer | Data Quality & Transformation

**From raw ingested data to clean, consistent and reliable source tables**

`PostgreSQL` · `PL/pgSQL` · `Data Cleansing` · `Validation` · `Automation`

</div>

---

## 📌 Project Overview

The Silver Layer is where data loaded into Bronze is cleaned, standardised and prepared for the next stage of the warehouse. Its main focus is **data quality and consistency**, not data modelling. The six source tables remain separate while transformation rules make their values more reliable and easier to use.

| Focus area | Work performed |
|:--|:--|
| Cleansing | Trims spaces, handles missing values and removes duplicate customer IDs |
| Standardisation | Converts coded values into readable labels and standardises selected country names |
| Validation | Handles malformed date representations and future birth dates |
| Data correction | Corrects price values and recalculates sales using price × quantity |
| Data preparation | Extracts product category IDs and derives product end dates |
| Automation | Refreshes all six tables through one stored procedure with progress notices and error details |

> [!NOTE]
> Bronze handles ingestion. Silver improves the quality and consistency of the ingested data. Gold later uses the cleaned data for business-friendly dimensions and a fact view.

## 🧭 Pipeline Position

```mermaid
flowchart TD
    A["🥉 Bronze Layer<br/>Raw tables loaded"] --> B["🥈 Silver Layer<br/>Clean · Standardise · Validate"]
    B --> C["🥇 Gold Layer<br/>Dimensions and fact view"]
    B --- D["Six separate Silver tables"]
    D --- E["CRM: customer, product, sales"]
    D --- F["ERP: customer, location, product category"]
    style A fill:#fef3c7,stroke:#d97706,color:#78350f
    style B fill:#e2e8f0,stroke:#475569,color:#0f172a
    style C fill:#ede9fe,stroke:#7c3aed,color:#4c1d95
    style D fill:#dcfce7,stroke:#16a34a,color:#14532d
```

## 🗂️ Tables Processed

| Silver table | Bronze source | Main transformation focus |
|:--|:--|:--|
| `crm_cust_info` | `bronze_layer.crm_cust_info` | Duplicate customer IDs, names, gender and marital status |
| `crm_prd_info` | `bronze_layer.crm_prd_info` | Product key parsing, cost, product line and product date ranges |
| `crm_sales_details` | `bronze_layer.crm_sales_details` | Date conversion, price correction and sales recalculation |
| `erp_cust_details` | `bronze_layer.erp_cust_details` | Customer ID cleanup, birth-date validation and gender standardisation |
| `erp_location` | `bronze_layer.erp_location` | Customer ID cleanup and country standardisation |
| `erp_prd_cat` | `bronze_layer.erp_prd_cat` | Trimming and title casing |

---

## 🧼 Transformation Details & Column Dictionary

The column types below come from the `CREATE TABLE` definitions in `Silver_layer.sql`. Every table also has a `created_at DATE DEFAULT CURRENT_DATE` metadata column. The procedure omits this column from its inserts, so PostgreSQL fills it with the date of the load.

## 1. `crm_cust_info` — CRM Customer Information

**Source:** `bronze_layer.crm_cust_info`

| Column | Data type | Transformation / description |
|:--|:--|:--|
| `cst_id` | `INT` | Retained from Bronze. NULL IDs are excluded; duplicate IDs are ranked and only the row with the latest `cst_create_date` is retained. |
| `cst_key` | `VARCHAR(50)` | Customer business key retained for matching with ERP customer and location data. |
| `cst_firstname` | `VARCHAR(50)` | Leading and trailing spaces removed using `TRIM()`. |
| `cst_lastname` | `VARCHAR(50)` | Leading and trailing spaces removed using `TRIM()`. |
| `cst_marital_status` | `VARCHAR(50)` | `M` → `Married`, `S` → `Single`; other or unrecognised values become `Unknown`. |
| `cst_gndr` | `VARCHAR(50)` | `M` → `Male`, `F` → `Female`; other or unrecognised values become `Unknown`. |
| `cst_create_date` | `DATE` | Source record creation date; also used to select the latest row for a repeated customer ID. |
| `created_at` | `DATE` | Automatically populated with `CURRENT_DATE` during insertion into Silver. |

**Key rule:** `ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC)` ranks records per customer. Only `flag_latest_date = 1` is inserted, and rows with NULL `cst_id` are excluded.

---

## 2. `crm_prd_info` — CRM Product Information

**Source:** `bronze_layer.crm_prd_info`

| Column | Data type | Transformation / description |
|:--|:--|:--|
| `prd_id` | `INT` | Product ID retained from Bronze. |
| `prd_cat_id` | `VARCHAR(50)` | Extracted from `prd_key` with a regular expression; hyphens in the extracted category code are replaced with underscores. |
| `prd_key` | `VARCHAR(50)` | Rebuilt from `SUBSTRING(prd_key FROM 7)`, removing the leading category portion for product matching. |
| `prd_nm` | `VARCHAR(50)` | Product name retained from Bronze. |
| `prd_cost` | `INT` | NULL cost values are replaced with `0` using `COALESCE()`. |
| `prd_line` | `VARCHAR(50)` | `M` → `Mountains`, `R` → `Road`, `S` → `Other Sales`, `T` → `Touring`; other values become `Unknown`. |
| `prd_start_dt` | `DATE` | Product start date retained from Bronze. |
| `prd_end_dt` | `DATE` | Derived from the next `prd_start_dt` for the same product name using `LEAD()`, minus one day. The final version has no next start date, so its end date is NULL. |
| `created_at` | `DATE` | Automatically populated with `CURRENT_DATE` during insertion into Silver. |

**Key rule:** `LEAD()` looks at the next start date for the same product name. The previous version's end date is set to one day before that date.

---

## 3. `crm_sales_details` — CRM Sales Transactions

**Source:** `bronze_layer.crm_sales_details`

| Column | Data type | Transformation / description |
|:--|:--|:--|
| `sls_ord_num` | `VARCHAR(50)` | Sales order reference retained from Bronze. |
| `sls_prd_key` | `VARCHAR(50)` | Product reference retained for matching in later stages. |
| `sls_cust_id` | `INT` | Customer ID retained from Bronze. |
| `sls_order_dt` | `DATE` | Eight-character `YYYYMMDD` value is reformatted and cast to `DATE`; other string lengths become NULL. |
| `sls_ship_dt` | `DATE` | Eight-character `YYYYMMDD` value is reformatted and cast to `DATE`; other string lengths become NULL. |
| `sls_due_dt` | `DATE` | Eight-character `YYYYMMDD` value is reformatted and cast to `DATE`; other string lengths become NULL. |
| `sls_quantity` | `INT` | Quantity retained from Bronze; the current SQL does not apply `ABS()` or another correction to quantity. |
| `sls_price` | `NUMERIC` | If price is NULL or zero, derives it as `sls_sales / sls_quantity`. If negative, `ABS()` makes it positive; otherwise, keeps the original price. |
| `sls_sales` | `NUMERIC` | Recalculated as the cleaned price multiplied by quantity. |
| `created_at` | `DATE` | Automatically populated with `CURRENT_DATE` during insertion into Silver. |

**Sales calculation:** the SQL sets `sls_sales` to the cleaned `sls_price * sls_quantity`.

> [!IMPORTANT]
> The script checks date-string length but does not separately validate every calendar-invalid date before casting. Also, deriving price as `sls_sales / sls_quantity` can fail if quantity is zero. These are useful edge cases to test if the procedure is extended.

---

## 4. `erp_cust_details` — ERP Customer Details

**Source:** `bronze_layer.erp_cust_details`

| Column | Data type | Transformation / description |
|:--|:--|:--|
| `cid` | `VARCHAR(50)` | If the ID starts with `NAS` (case-insensitive), removes the first three characters; otherwise retains the ID. |
| `bdate` | `DATE` | Future birth dates, including today's date, become NULL using `bdate >= CURRENT_DATE`. |
| `gen` | `VARCHAR(50)` | `M` → `Male`, `F` → `Female`; blank and NULL values become `Unknown`. Other values are retained as-is. |
| `created_at` | `DATE` | Automatically populated with `CURRENT_DATE` during insertion into Silver. |

The cleaned customer ID helps align ERP identifiers with CRM customer keys.

---

## 5. `erp_location` — ERP Customer Location

**Source:** `bronze_layer.erp_location`

| Column | Data type | Transformation / description |
|:--|:--|:--|
| `cid` | `VARCHAR(50)` | Hyphens are removed from the ID using `REPLACE()`. |
| `cntry` | `VARCHAR(50)` | `USA` and `US` become `United States`; `DE` becomes `Germany`; blank and NULL values become `Unknown`. Other values are retained as supplied. |
| `created_at` | `DATE` | Automatically populated with `CURRENT_DATE` during insertion into Silver. |

The query standardises selected country codes. It does not trim or standardise every remaining country value, so additional variants may need review if they exist in the source.

---

## 6. `erp_prd_cat` — ERP Product Categories

**Source:** `bronze_layer.erp_prd_cat`

The SQL summary says this source table is already clean. The procedure still trims text fields and applies title casing to category descriptions.

| Column | Data type | Transformation / description |
|:--|:--|:--|
| `id` | `VARCHAR(50)` | Trimmed using `TRIM()`. Defined as the primary key in the Silver table. |
| `cat` | `VARCHAR(50)` | Trimmed and converted to title case using `INITCAP()`. |
| `subcat` | `VARCHAR(50)` | Trimmed and converted to title case using `INITCAP()`. |
| `maintenance` | `VARCHAR(50)` | Trimmed and converted to title case using `INITCAP()`. |
| `created_at` | `DATE` | Automatically populated with `CURRENT_DATE` during insertion into Silver. |

---

## ⚙️ Refresh Automation — `load_silver_layer_tables()`

The procedure `silver_layer.load_silver_layer_tables()` automates the refresh of all six Silver tables.

```mermaid
flowchart TD
    A["Start procedure"] --> B["Print loading notice"]
    B --> C["TRUNCATE target table"]
    C --> D["INSERT cleaned data"]
    D --> E{"More tables?"}
    E -- Yes --> C
    E -- No --> F["Finish procedure"]
    C -. error .-> G["Exception handler"]
    D -. error .-> G
    G --> H["Print SQLERRM and SQLSTATE"]
```

### Procedure behaviour

- **Refresh pattern:** Each target table is truncated and then repopulated from its Bronze source.
- **Progress messages:** `RAISE NOTICE` announces the load and individual table steps.
- **Error reporting:** The `WHEN OTHERS` handler prints `SQLERRM` (error message) and `SQLSTATE` (error code).
- **Load metadata:** `created_at` defaults to the current date when not specified in the insert.

### SQL features used

| Feature | Purpose in this script |
|:--|:--|
| `TRUNCATE` | Clears the existing target table before refresh |
| `INSERT INTO ... SELECT` | Loads transformed rows from Bronze into Silver |
| `ROW_NUMBER()` | Ranks repeated customer IDs to keep the latest record |
| `SUBSTRING()` and regex | Extracts product category/key portions |
| `COALESCE()` | Replaces NULL product costs with zero |
| `CASE WHEN` | Applies rules to coded values, dates and prices |
| `TRIM()`, `REPLACE()`, `UPPER()`, `INITCAP()` | Cleans strings and standardises labels |
| `ABS()` | Converts negative price values to positive values |
| `LEAD()` and `INTERVAL` | Derives product end dates from the next start date |
| `ILIKE` | Performs case-insensitive matching of the `NAS` ID prefix |
| `RAISE NOTICE` | Displays progress and error details |

> [!WARNING]
> The exception handler logs errors with `RAISE NOTICE` but does not re-raise them. As a result, a caller may not receive a failure status as expected. For production use, consider re-raising the exception after logging it and review whether the refresh should be atomic across all six tables.

---

## 🧪 Validation Checklist

These checks should be run against the database after the procedure. The README documents the SQL transformations; it does not claim that all checks have already passed.

- [ ] Confirm the procedure completes and all six Silver tables can be queried.
- [ ] Check repeated or NULL `cst_id` values in `crm_cust_info`.
- [ ] Review gender and marital-status values for unexpected labels.
- [ ] Check missing or negative product costs and review derived `prd_end_dt` values.
- [ ] Review sales rows with NULL dates, zero quantity, missing prices or unexpected sales amounts.
- [ ] Check ERP customer IDs against CRM customer keys before later integration.
- [ ] Check country labels for remaining spelling or formatting variants.
- [ ] Confirm `erp_prd_cat.id` values are unique and non-NULL.
- [ ] Verify `created_at` is populated as expected.
- [ ] Consider transaction and error-handling improvements before production use.

### Query 1 — Check duplicate customer IDs

```sql
SELECT cst_id, COUNT(*) AS row_count
FROM silver_layer.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;
```

### Query 2 — Review customer labels

```sql
SELECT DISTINCT cst_gndr
FROM silver_layer.crm_cust_info;

SELECT DISTINCT cst_marital_status
FROM silver_layer.crm_cust_info;
```

### Query 3 — Review potentially problematic sales rows

```sql
SELECT *
FROM silver_layer.crm_sales_details
WHERE sls_order_dt IS NULL
   OR sls_ship_dt IS NULL
   OR sls_due_dt IS NULL
   OR sls_quantity = 0
   OR sls_price IS NULL
   OR sls_sales IS NULL;
```

### Query 4 — Check product date ranges

```sql
SELECT *
FROM silver_layer.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_start_dt > prd_end_dt;
```

### Query 5 — Check category key duplicates

```sql
SELECT id, COUNT(*) AS row_count
FROM silver_layer.erp_prd_cat
GROUP BY id
HAVING COUNT(*) > 1;
```

---

## 📎 Scope & Notes

- The transformations documented here are based on the supplied `Silver_layer.sql`.
- Silver keeps the six tables separate; this layer does not create the Gold Layer dimensional model.
- `created_at` records the date the row was inserted into Silver, not the original source-record creation date.
- Column types reflect the Silver `CREATE TABLE` statements, not inferred types from CSV extracts.

---

<div align="center">

**Silver Layer: cleaner data, clearer values, and a repeatable refresh process.**

*Built with PostgreSQL · SQL · PL/pgSQL*

</div>
