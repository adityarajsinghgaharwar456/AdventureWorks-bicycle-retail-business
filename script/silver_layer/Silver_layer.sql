-- Active: 1789844606371@@127.0.0.1@5432@data_warehouse@silver_layer
/*
========================================================================================================================
Data Validation and Cleansing: Load Silver Layer (Source -> Bronze)
========================================================================================================================
Intro:
  Main focus of this schema to transform data through in-depth cleaning and validating each columns of all the tables
  across silver_schema
  
Script Objectivr:
  A) Data Cleansing   
  B) Data Standardization  
  C) Data Normalization 
  D) Derived Columns 
  E) Data Enrichment

Key SQL Functions & Features Used:-
  1) Stored Procedure (PLPGSQL Language) - Begin...End, Raise Notice, When..others, SQLERRM SQLSTATE
  2) DDL(Drop,Create,Truncate), DML(Insert), DQL(Select)
  3) DQL Clause - From, Where, distinct
  4) Regex Functions - substring(), regex_replace()
  5) Conditional Logic Functions - Case...When(), Coalesce()
  6) String or Numeric Functions - trim(), upper(), initcap(), replace(), length(), ABS()
  7) Window Functions - row_number(), lead()
  8) Date & Time Functions - interval 
  9) Pattern Matching operators - ILIKE
  
=========================================================================================================================
*/
SET search_path to silver_layer;

--=======================================================================================================================
--                                                        Creating table
--=======================================================================================================================
DROP table if EXISTS silver_layer.crm_cust_info;
CREATE Table silver_layer.crm_cust_info
(
    cst_id INT,
    cst_key VARCHAR(50) ,
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE,
    created_at date DEFAULT current_date
);

DROP table if EXISTS silver_layer.crm_prd_info;
CREATE Table crm_prd_info
(
    prd_id int,
    prd_cat_id VARCHAR(50),
    prd_key varchar(50),
    prd_nm VARCHAR(50),
    prd_cost int,
    prd_line VARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt DATE,
    created_at date DEFAULT current_date

);

DROP table if EXISTS silver_layer.crm_sales_details;
CREATE Table silver_layer.crm_sales_details
(
    sls_ord_num varchar(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id int,
    sls_order_dt DATE,
    sls_ship_dt DATE,
    sls_due_dt DATE,
    sls_quantity int,
    sls_price NUMERIC,
    sls_sales NUMERIC,
    created_at date DEFAULT current_date
);

DROP table if EXISTS silver_layer.erp_location;
CREATE Table silver_layer.erp_location
(
    CID varchar(50),
    CNTRY VARCHAR(50),
    created_at date DEFAULT current_date
);

DROP table if EXISTS silver_layer.erp_cust_details;
create TABLE erp_cust_details
(
    CID VARCHAR(50),
    BDATE date,
    GEN VARCHAR(50),
    created_at date DEFAULT current_date
);

DROP table if EXISTS silver_layer.erp_prd_cat;
create Table erp_prd_cat
(
    ID VARCHAR(50) primary KEY,
    CAT varchar(50),
    SUBCAT VARCHAR(50),
    MAINTENANCE varchar(50),
    created_at date DEFAULT current_date
);




--=======================================================================================================================
--                                           STORED PROCEDURE
--=======================================================================================================================
CREATE OR REPLACE PROCEDURE silver_layer.load_silver_layer_tables()
 LANGUAGE plpgsql
AS $procedure$
BEGIN

RAISE NOTICE '==================================================================================';
RAISE NOTICE 'Loading Silver_layer';
RAISE NOTICE '==================================================================================';


RAISE NOTICE '>> Truncating data from table: silver_layer.crm_cust_info';
TRUNCATE TABLE silver_layer.crm_cust_info;

RAISE NOTICE '>> Inserting data to: silver_layer.crm_cust_info';
insert into silver_layer.crm_cust_info
  (
    cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date  
  )
SELECT
  cst_id,
  cst_key,
  trim(cst_firstname) as cst_firstname,
  trim(cst_lastname) as cst_lastname,
  CASE 
    WHEN upper(trim(cst_marital_status)) = 'M'  THEN  'Married'
    WHEN upper(trim(cst_marital_status)) = 'S' then 'Single'
    ELSE 'Unknown' 
  END as cst_marital_status,
  CASE 
    WHEN upper(trim(cst_gndr)) = 'M'  THEN  'Male'
    WHEN upper(trim(cst_gndr)) = 'F' then 'Female'
    ELSE 'Unknown' 
  END as cst_gndr,
  cst_create_date
FROM 
(
SELECT
*,
ROW_NUMBER() over(partition by cst_id order by cst_create_date DESC) as flag_latest_date
FROM
 bronze_layer.crm_cust_info
)
where flag_latest_date = 1 and cst_id is not NULL;



---------------------------------------------------------------------------------------------------------------------------------
--                                     'crm_prd_info' table Cleaning
---------------------------------------------------------------------------------------------------------------------------------

RAISE NOTICE '>> Truncating data from table: silver_layer.crm_prd_info';
TRUNCATE TABLE silver_layer.crm_prd_info;

RAISE NOTICE '>> Inserting data to: silver_layer.crm_prd_info';
insert into silver_layer.crm_prd_info
  (
    prd_id, 
    prd_cat_id, 
    prd_key, 
    prd_nm, 
    prd_cost, 
    prd_line, 
    prd_start_dt, 
    prd_end_dt
)
SELECT
  prd_id,
  replace(substring(prd_key from '([A-Za-z-]{5})'),'-','_') as prd_cat_id,
  substring(prd_key from 7) as prd_cat_key,
  prd_nm,
  COALESCE(prd_cost,0) as prd_cost,
  CASE 
    WHEN upper(trim(prd_line)) = 'M'  THEN 'Mountains'
    WHEN upper(trim(prd_line)) = 'R'  THEN 'Road'
    WHEN upper(trim(prd_line)) = 'S'  THEN 'Other Sales'
    WHEN upper(trim(prd_line)) = 'T'  THEN 'Touring'  
    ELSE  'Unknown'
  END as prd_line,
  prd_start_dt,
  (lead(prd_start_dt) over(partition by prd_nm order by prd_start_dt asc) - interval '1 day')::date as prd_end_dt
FROM
  bronze_layer.crm_prd_info;




---------------------------------------------------------------------------------------------------------------------------------
--                                     'crm_sales_details' table Cleaning
---------------------------------------------------------------------------------------------------------------------------------
RAISE NOTICE '>> Truncating data from table: silver_layer.crm_sales_details';
TRUNCATE TABLE silver_layer.crm_sales_details;

RAISE NOTICE '>> Inserting data to: silver_layer.crm_sales_details';
insert into silver_layer.crm_sales_details
(
    sls_ord_num, 
    sls_prd_key,
    sls_cust_id, 
    sls_order_dt, 
    sls_ship_dt, 
    sls_due_dt,  
    sls_quantity, 
    sls_price, 
    sls_sales
)
SELECT
  sls_ord_num,
  sls_prd_key,
  sls_cust_id,
  CASE 
    WHEN length(sls_order_dt::text) = 8  THEN  (regexp_replace(sls_order_dt::text,'^([0-9]{4})([0-9]{2})([0-9]{2})$','\1-\2-\3'))::date
    ELSE NULL 
  END as sls_order_dt,
  CASE 
    WHEN length(sls_ship_dt::text) = 8  THEN  (regexp_replace(sls_ship_dt::text,'^([0-9]{4})([0-9]{2})([0-9]{2})$','\1-\2-\3'))::date
    ELSE NULL 
  END as sls_ship_dt,
  CASE 
    WHEN length(sls_due_dt::text) = 8  THEN  (regexp_replace(sls_due_dt::text,'^([0-9]{4})([0-9]{2})([0-9]{2})$','\1-\2-\3'))::date
    ELSE NULL 
  END as sls_due_dt,
  sls_quantity,
  CASE 
    WHEN sls_price is NULL or sls_price = 0 THEN sls_sales/sls_quantity
    WHEN sls_price < 0 then ABS(sls_price)  
    ELSE sls_price
  END as sls_price,
  CASE 
    WHEN sls_price is NULL or sls_price = 0 THEN sls_sales/sls_quantity
    WHEN sls_price < 0 then ABS(sls_price)  
    ELSE sls_price
  END * sls_quantity as sls_sales
FROM
  bronze_layer.crm_sales_details;






---------------------------------------------------------------------------------------------------------------------------------
--                                     'crm_sales_details' table Cleaning
---------------------------------------------------------------------------------------------------------------------------------

RAISE NOTICE '>> Truncating data from table: silver_layer.erp_cust_details';
TRUNCATE TABLE silver_layer.erp_cust_details;

RAISE NOTICE '>> Inserting data to: silver_layer.erp_cust_details';
insert into silver_layer.erp_cust_details
(
  CID,
  bdate,
  gen 
)
SELECT
  CASE 
    WHEN cid ILIKE 'NAS%' THEN substring(cid from 4) 
    ELSE cid 
  END as cid,
  CASE 
    WHEN bdate >= CURRENT_DATE THEN NULL  
    ELSE  bdate
  END as bdate,
  CASE 
    WHEN trim(upper(gen)) = 'M' THEN  'Male'
    WHEN trim(upper(gen)) = 'F' then 'Female'
    WHEN trim(upper(gen)) = ''  then 'Unknown'
    WHEN gen is NULL THEN 'Unknown'
    ELSE gen
  END as gen
FROM
  bronze_layer.erp_cust_details;



---------------------------------------------------------------------------------------------------------------------------------
--                                          'erp_location' table Cleaning
---------------------------------------------------------------------------------------------------------------------------------
RAISE NOTICE '>> Truncating data from table: silver_layer.erp_location';
TRUNCATE TABLE silver_layer.erp_location;

RAISE NOTICE '>> Inserting data to: silver_layer.erp_location';
insert into silver_layer.erp_location
(
  CID,
  CNTRY
)
SELECT
  replace(cid,'-',''),
  CASE 
    WHEN trim(upper(cntry)) in('USA','US') THEN 'United States'
    WHEN trim(upper(cntry)) = 'DE' THEN 'Germany'  
    WHEN trim(upper(cntry)) is NULL or trim(cntry) = '' THEN 'Unknown'
    ELSE cntry
  END as cntry
FROM
  bronze_layer.erp_location;






---------------------------------------------------------------------------------------------------------------------------------
--                                           'erp_prd_cat' table Cleaning
---------------------------------------------------------------------------------------------------------------------------------
RAISE NOTICE '>> Truncating data from table: silver_layer.erp_prd_cat';
TRUNCATE TABLE silver_layer.erp_prd_cat;

RAISE NOTICE '>> Inserting data to: silver_layer.erp_prd_cat';
insert into silver_layer.erp_prd_cat
(
    ID,
    CAT,
    SUBCAT,
    MAINTENANCE
)
SELECT
  trim(id) as id,
  trim(initcap(cat)) as cat,
  trim(initcap(subcat)) as subcat,
  trim(initcap(maintenance)) as maintenance
FROM
  bronze_layer.erp_prd_cat;

EXCEPTION
  when OTHERS THEN
    RAISE NOTICE '===================================================================';
    RAISE NOTICE 'Failed to load Siver_layer';
    RAISE NOTICE 'Reason of Error %:- ', SQLERRM;
    RAISE NOTICE 'Error Code %:- ', SQLSTATE;
    RAISE NOTICE '===================================================================';
END;
$procedure$


CALL load_silver_layer_tables()
