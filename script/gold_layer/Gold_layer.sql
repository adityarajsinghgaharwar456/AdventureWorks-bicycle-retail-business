-- Active: 1789844606371@@127.0.0.1@5432@data_warehouse@gold_layer
/*
========================================================================================================================
Data Integration,Aggregation & Business Logics: Load Gold Layer (Source -> silver)
========================================================================================================================
Intro:
  Gold_layer Schema helps in making user_friendly and easy to undertand tables for business use. i involves creation of 
  3 tables --> dim_customers, dim_products ass Dimension Table & fact_sales(fact table)
Objective:-
  A) change Column code name to simple, descriptive easy to understand name
  B) Data Modelling
  C) Combile tables into broarder and consolidated ones
  D) classify Consolidated table into "Dimmension Tables" and "Fact Table" 

Key SQL Functions & Features Used:-
  1) DDL(Create View), DQL(Select,From,where)
  2) Join
  3) Conditional Logics - Case...when()
  4) Window Function - Row_number
*/ 
---------------------------------------------------------------------------------------------------------------------------
--                                          CREATE VIEW - DIM_CUSTOMERS TABLE
---------------------------------------------------------------------------------------------------------------------------
create view gold_layer.dim_customers AS
(
SELECT
ROW_NUMBER() OVER() as customer_key,
ci.cst_id as customer_id,
ci.cst_key as customer_number,
concat(ci.cst_firstname,' ',ci.cst_lastname) as full_name,
CASE 
  WHEN ci.cst_gndr = 'Unknown' THEN cd.gen 
  ELSE ci.cst_gndr
END as gender,
ci.cst_marital_status as marital_status,
cd.bdate as birth_date,
l.cntry,
ci.cst_create_date as create_date
FROM
  silver_layer.crm_cust_info ci
  left JOIN silver_layer.erp_cust_details cd on ci.cst_key = cd.cid
  left JOIN silver_layer.erp_location l on ci.cst_key = l.cid
);




---------------------------------------------------------------------------------------------------------------------------
--                                          CREATE VIEW - DIM_PRODUCTS TABLE
---------------------------------------------------------------------------------------------------------------------------
create VIEW gold_layer.dim_products AS
(
SELECT
  ROW_NUMBER() OVER() as product_key,   --Surrogate_key
  PI.prd_id AS product_id,
  pi.prd_key as product_number,
  pi.prd_cat_id as category_id,
  pi.prd_line,
  pc.cat as product_categories,
  pc.subcat as product_subcategories,
  pi.prd_nm as product_name,
  pi.prd_cost as product_cost,
  pi.prd_start_dt as production_start_date,
  pc.maintenance as maintenance
FROM  
  silver_layer.crm_prd_info PI
  left JOIN silver_layer.erp_prd_cat pc on pi.prd_cat_id = pc.id 
where prd_end_dt is NULL
ORDER BY product_key
);

---------------------------------------------------------------------------------------------------------------------------
--                                          CREATE VIEW - FACT_SALES_DETAILS    
---------------------------------------------------------------------------------------------------------------------------
create VIEW gold_layer.fact_sales as
(
select
  sls_ord_num as order_no,
  p.product_key as product_key,
  c.customer_key as customer_key,
  sls_order_dt as order_date,
  sls_ship_dt as ship_date,
  sls_due_dt as due_date,
  sls_quantity as quantity,
  sls_price as price,
  sls_sales as total_sales
FROM
  silver_layer.crm_sales_details s
  left join gold_layer.dim_products p on s.sls_prd_key = p.product_number
  left JOIN gold_layer.dim_customers c on s.sls_cust_id = c.customer_id
);


