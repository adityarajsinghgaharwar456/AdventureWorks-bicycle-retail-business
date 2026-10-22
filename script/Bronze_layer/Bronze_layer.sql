-- Active: 1789844606371@@127.0.0.1@5432@adventureworks_bicycle_retail
/*
======================================================================================================================
Stored Procedure & Functions to Load Raw CSV file from source: Load Bronze Layer (Source -> CSV file)
======================================================================================================================
This project would start with bronze layer where bases will be prepared and structure are defined. firstly, it begins with creation
of Database and then 3 schemas --> bronze_layer, silver_layer, Gold_layer. In this layer no transformations are allowed as it only
mean for ingestion of raw data from source system
objective:
  1) database and schema building
  2) Creation of tables
  3) Batch processing and loading
  4) Buillt stored procedure to automate data import process
===============================================================================
*/
--                                ---------------------------------------------------------------
--                                                        Creating Database and Schemas
--                                ---------------------------------------------------------------




-- Creating Data base
create DATABASE adventureworks_bicyle_retail;


--Create Schemas
create SCHEMA bronze_layer;
GO
create SCHEMA silver_layer;
GO
create SCHEMA gold_layer;
GO 

set search_path to bronze_layer, adventureworks_bicyle_retail;


--                                ---------------------------------------------------------------
--                                                        Creating table
--                                ---------------------------------------------------------------

CREATE Table crm_cust_info
(
    cst_id INT ,
    cst_key VARCHAR(50),
    cst_firstname VARCHAR(50),
    cst_lastname VARCHAR(50),
    cst_marital_status VARCHAR(50),
    cst_gndr VARCHAR(50),
    cst_create_date DATE
);

CREATE Table crm_prd_info
(
    prd_id int,
    prd_key varchar(50),
    prd_nm VARCHAR(50),
    prd_cost int,
    prd_line VARCHAR(50),
    prd_start_dt DATE,
    prd_end_dt DATE

);

CREATE Table crm_sales_details
(
    sls_ord_num varchar(50),
    sls_prd_key VARCHAR(50),
    sls_cust_id int,
    sls_order_dt int,
    sls_ship_dt int,
    sls_due_dt int,
    sls_sales NUMERIC,
    sls_quantity int,
    sls_price NUMERIC
);

CREATE Table erp_location
(
    CID varchar(50),
    CNTRY VARCHAR(50)
);

create TABLE erp_cust_details
(
    CID VARCHAR(50),
    BDATE date,
    GEN VARCHAR(50)
);

create Table erp_prd_cat
(
    ID VARCHAR(50),
    CAT varchar(50),
    SUBCAT VARCHAR(50),
    MAINTENANCE varchar(50)
);


--                                ---------------------------------------------------------------
--                                                    CREATING STORED PROCEDURE
--                                ---------------------------------------------------------------

create or replace procedure load_tables()
LANGUAGE PLPGSQL as $$
BEGIN

TRUNCATE TABLE bronze_layer.crm_cust_info;
copy crm_cust_info
from 'F:\data analyst\MySQL\Project\Data Warehousing Project\sql-data-warehouse-project\datasets\source_crm\cust_info.csv' 
DELIMITER ','
csv HEADER ;

TRUNCATE TABLE bronze_layer.crm_prd_info;
copy crm_prd_info
from 'F:\data analyst\MySQL\Project\Data Warehousing Project\sql-data-warehouse-project\datasets\source_crm\prd_info.csv'
DELIMITER ','
csv HEADER;

truncate table crm_sales_details;
copy crm_sales_details
from 'F:\data analyst\MySQL\Project\Data Warehousing Project\sql-data-warehouse-project\datasets\source_crm\sales_details.csv'
DELIMITER ','
csv HEADER;

truncate table erp_location;
copy erp_location
from 'F:\data analyst\MySQL\Project\Data Warehousing Project\sql-data-warehouse-project\datasets\source_erp\LOC_A101.csv'
DELIMITER ','
csv HEADER;

TRUNCATE table erp_cust_details;
copy erp_cust_details
from 'F:\data analyst\MySQL\Project\Data Warehousing Project\sql-data-warehouse-project\datasets\source_erp\CUST_AZ12.csv'
DELIMITER ','
csv HEADER;

truncate TABLE erp_prd_cat;
copy erp_prd_cat
from 'F:\data analyst\MySQL\Project\Data Warehousing Project\sql-data-warehouse-project\datasets\source_erp\PX_CAT_G1V2.csv'
DELIMITER ','
csv HEADER;

END
$$;

--                                ---------------------------------------------------------------
--                                             CREATING stored Functions TO CHECK TABLE ROWS
--                                ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION TABLE_INFO()
RETURNs TABLE (TABLE_NAME text,TOTAL_ROWS INT)
LANGUAGE SQL 
as $$
SELECT
  'crm_cust_info',
  count(*)
FROM crm_cust_info
union all
SELECT
  'crm_prd_info',
  count(*)
from crm_prd_info
union all
select
  'crm_sales_details',
  count(*)
from crm_sales_details
UNION all
SELECT 
 'erp_cust_details',
 count(*)
 from erp_cust_details
UNION all 
SELECT
  'erp_location',
  count(*)
from erp_location
UNION all
SELECT
  'erp_prd_cat',
  count(*)
from erp_prd_cat;

$$;


select* from table_info();

call load_tables();
