-- Active: 1789844606371@@127.0.0.1@5432@adventureworks_bicycle_retail@analytics_layer
/*
==================================================================================================================================
 Product-wise insight reporting (Source -> Analytics_layer)
==================================================================================================================================
Intro:--  
    The purpose of this analysis to examine pattern of orders perform on the basis of order timeline, product cohort,delivery days.
    Also add calculated column by creating master table for visualisation 

Objective:--
  1) Create View table 'sales_view_table' which woukd also act master table
  2) Master table that comprise multiple calulated and derive columns such as:-
        A) Delivery days (ship_date - due_date)
        B) Profit calculation (total_sales - product_cost)
  3) Annnual and Quarterly sales analysis
  4) Timeline based categories assessment
  5) Market Basket / Product Affinity Analysis

==================================================================================================================================
*/

-- --------------------------------------------------------------------------------------------------------------------------------
-- section:  Master table for visualization 
-- --------------------------------------------------------------------------------------------------------------------------------

create or replace view sales_view_table as
(
  SELECT
    s.order_no,
    s.order_date,
    s.ship_date,
    s.due_date,
    s.due_date - s.order_date as delivery_days,
    cst.full_name,
    cst.gender,
    cst.marital_status,
    cst.cntry as country,
    prd.product_categories,
    prd.product_subcategories,
    prd.product_name,
    prd.product_cost,
    s.quantity,
    s.price,
    s.total_sales,
    s.total_sales - prd.product_cost as profit
  FROM
    analytics_layer.fact_sales s
    left JOIN analytics_layer.dim_products prd on s.product_key = prd.product_key
    left join analytics_layer.dim_customers cst on s.customer_key = cst.customer_key
);



-- --------------------------------------------------------------------------------------------------------------------------------
-- section: A) Annual and Quarterly sales anlalysis
-- --------------------------------------------------------------------------------------------------------------------------------
-- Annual sales analysis
with sales_orders AS
(
SELECT
  extract(year from order_date) as YEAR,
  quantity,
  total_sales,
  profit
FROM
  analytics_layer.sales_view_table
where order_date is not null
order by order_date
),
aggregate_sum as
(
SELECT
YEAR,
sum(quantity) as total_units_sold,
round(sum(total_sales),2) as total_sales,  
round(sum(profit),2) as total_profit
FROM
  sales_orders
group by year
order by YEAR
)
SELECT
YEAR,
total_units_sold,
round(total_units_sold / sum(total_units_sold) over() * 100,2) as "quantity %",
total_sales,
round(total_sales/ sum(total_sales) over() * 100,2) as "sales %",  
total_profit,
round(total_profit / sum(total_profit) over() * 100,2) as "profit %"
FROM
  aggregate_sum
where year not in (2010, 2014)
order by YEAR



-- Quarterly sales analysis
with sales_orders AS
(
SELECT
  extract(year from order_date) as YEAR,
  extract(quarter from order_date) as quarter,
  quantity,
  total_sales,
  profit
FROM
  analytics_layer.sales_view_table
where order_date is not null
order by order_date
),
aggregate_sum as
(
SELECT
YEAR,
quarter,
sum(quantity) as total_units_sold,
round(sum(total_sales),2) as total_sales,  
round(sum(profit),2) as total_profit
FROM
  sales_orders
group by year, quarter
order by YEAR, quarter
)
SELECT
YEAR,
quarter,
total_units_sold,
round(total_units_sold / sum(total_units_sold) over() * 100,2) as "quantity %",
total_sales,
round(total_sales/ sum(total_sales) over() * 100,2) as "sales %",  
total_profit,
round(total_profit / sum(total_profit) over() * 100,2) as "profit %"
FROM
  aggregate_sum
order by YEAR, quarter


-- --------------------------------------------------------------------------------------------------------------------------------
-- section: B)  Categories assesment on the basis of diverse timeline (LInked with product category performance analysis)
-- --------------------------------------------------------------------------------------------------------------------------------

with sales_orders AS
(
SELECT
  extract(year from order_date) as YEAR,
  product_categories,
  quantity,
  total_sales,
  profit
FROM
  analytics_layer.sales_view_table
where order_date is not null
order by order_date
),
aggregate_sum as
(
SELECT
YEAR,
product_categories,
sum(quantity) as total_units_sold,
round(sum(total_sales),2) as total_sales,  
round(sum(profit),2) as total_profit
FROM
  sales_orders
group by year, product_categories 
order by YEAR
)
SELECT
YEAR,
product_categories,
total_units_sold,
round(total_units_sold / sum(total_units_sold) over() * 100,2) as "quantity %",
total_sales,
round(total_sales/ sum(total_sales) over() * 100,2) as "sales %",  
total_profit,
round(total_profit / sum(total_profit) over() * 100,2) as "profit %"
FROM
  aggregate_sum
where year not in (2010, 2014)
order by YEAR


-- --------------------------------------------------------------------------------------------------------------------------------
-- section: C) Market Basket / Product Affinity Analysis
-- --------------------------------------------------------------------------------------------------------------------------------

with multi_products_orders as
(
select
order_no,
product_name
FROM
  analytics_layer.sales_view_table
where 
  order_no IN
    (
    SELECT DISTINCT
      order_no
    FROM
      analytics_layer.sales_view_table
    group by order_no
    having count(order_no) > 1
    )
),
product_relationship as
(
SELECT
  o1.order_no,
  o1.product_name as product_A,
  o2.product_name as product_B
from
  multi_products_orders o1
  JOIN multi_products_orders o2 on o1.order_no = o2.order_no and o1.product_name < o2.product_name 
)
SELECT DISTINCT
  product_A,
  product_B,
  count(distinct order_no) as mutual_orders
FROM
  product_relationship
group by product_A, product_B
order by mutual_orders DESC



-- flagship bike products cross sales analysis

with multi_products_orders as
(
select
order_no,
product_categories,
product_name
FROM
  analytics_layer.sales_view_table
where 
  order_no IN
    (
    SELECT DISTINCT
      order_no
    FROM
      analytics_layer.sales_view_table
    group by order_no
    having count(order_no) > 1
    )
),
product_relationship as
(
SELECT
  o1.order_no,
  o1.product_categories,
  o1.product_name as product_A,
  o2.product_name as product_B
from
  multi_products_orders o1
  JOIN multi_products_orders o2 on o1.order_no = o2.order_no and o1.product_name < o2.product_name 
where o1.product_categories = 'Bikes'
)
SELECT
 sum(mutual_orders) filter(where flagship_prd ilike '%road%') as road_prd,
 sum(mutual_orders) filter(where flagship_prd ilike '%mountain%') as mountain_prd,
 sum(mutual_orders) filter(where flagship_prd ilike '%touring%') as touring_prd
from
(
SELECT DISTINCT
  product_A as flagship_prd,
  product_B as secondary_prd,
  count(distinct order_no) as mutual_orders
FROM
  product_relationship
-- where product_B ilike '%cage%'
group by flagship_prd, secondary_prd
having count(distinct order_no) > 1
order by mutual_orders DESC
);



