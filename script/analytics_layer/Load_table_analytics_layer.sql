-- Active: 1789844606371@@127.0.0.1@5432@adventureworks_bicycle_retail
/*
========================================================================================================================
Import table to data anlystics layer (Source -> Gold_layer)
========================================================================================================================
Intro:--  
    The aim of querries in  this page to import cleaned business-ready data to analytics_layer which would later use for
    different analysis

Objective:--
  1) Import all dimension and facct table to this layer
  2) Integrate all importing process within Stored procedure --> 'analytics_layer_data_import'
  3) No Parametere would be assigned within procedure
  4) safe handling of error appeared in case using 'sqlerrm' and 'sqlstate'
=========================================================================================================================
*/
-------------------------------------------------------------------------------------------------------------------------------
--                                           Create Dimension tables and fact tables
-------------------------------------------------------------------------------------------------------------------------------
--Create table dim_customers
create table analytics_layer.dim_customers
(
    customer_key BIGINT,
    customer_id int,
    customer_number VARCHAR(50),
    full_name TEXT,
    gender varchar(50),
    marital_status varchar(50),
    birth_date date,
    cntry varchar(50),
    create_date DATE
);

--Create table dim_products
CREATE table analytics_layer.dim_products
(
    product_key BIGINT,
    product_id int,
    product_number varchar(50),
    category_id VARCHAR(50),
    prd_line varchar(50),
    product_categories VARCHAR(50),
    product_subcategories VARCHAR(50),
    product_name VARCHAR(50),
    product_cost int,
    product_start_date DATE,
    maintenance VARCHAR(50)
);

-- Create table fact_sales
create table analytics_layer.fact_sales
(
    order_no VARCHAR(50),
    product_key BIGINT,
    customer_key bigint,
    order_date DATE,
    ship_date date,
    due_date date,
    quantity int,
    price numeric,
    total_sales NUMERIC    
);
-------------------------------------------------------------------------------------------------------------------------------
--                                 LOAD TABLES FROM GOLD_LAYER & Stored Procedure formation
-------------------------------------------------------------------------------------------------------------------------------

--Building Stored Procedure

create or replace PROCEDURE analytics_layer_data_import()
language PLPGSQL AS
$$
BEGIN

-- truncate and Load dim_customers
RAISE NOTICE '>> truncating dim_customers';
TRUNCATE TABLE analytics_layer.dim_customers;

RAISE NOTICE '>> Loading dim_customers';
INSERT INTO analytics_layer.dim_customers
SELECT*FROM gold_layer.dim_customers;

-- Truncating and Load dim_products
RAISE NOTICE '>> truncating dim_customers';
TRUNCATE table analytics_layer.dim_products;

RAISE NOTICE '>> Loading dim_customers';
insert into analytics_layer.dim_products
SELECT*from gold_layer.dim_products;

--Truncate and Load fact_sales
RAISE NOTICE '>> truncating dim_customers';
truncate table analytics_layer.fact_sales;
insert into analytics_layer.fact_sales
SELECT*from gold_layer.fact_sales;

EXCEPTION
    when OTHERS THEN
        RAISE NOTICE '===================================================================';
        RAISE NOTICE 'Failed to load analytics_layer';
        RAISE NOTICE '===================================================================';
        raise notice 'reason of error%', sqlerrm;
        raise NOTICE 'Error code%', sqlstate;
END;
$$;

-- check weather data gets imported or not
select*from analytics_layer.dim_customers;

-- Verify all data gets updated to analytics_layer.dim_products
SELECT*from analytics_layer.dim_products;

CALL analytics_layer_data_import()