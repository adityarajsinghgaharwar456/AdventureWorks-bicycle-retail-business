-- Active: 1789844606371@@127.0.0.1@5432@adventureworks_bicycle_retail@analytics_layer
/*
========================================================================================================================
Product-wise insight reporting (Source -> Analytics_layer)
========================================================================================================================
Intro:--  
    This section prioritises more on Products and its categories performance. it aims to observe trends, pattern and its 
    impact on sale. It include framing of master table for furthur visualisation

Objective:--
  1) Create View table 'Customer_view_table'
  2) Master table that comprise multiple calulated and derive columns such as:-
        A) total_orders             C) profit               E) product_class
        B) total_units_sold         D) total_sales
  3) Statistical Data Observations
  4) Classify products by total sales range 
  5) Product Demand analysis
  6) Product Distribution - based on cheaper, mid-range and premium product segmented based on product_count
  7) Product Grading- category-wise segmentation of total products orders
  8) Product Category and sub-category performance overview 
  9) Products performance assesment
  10) Cross product Analysis

=========================================================================================================================
*/

----------------------------------------------------------------------------------------
--section: Create View - 'Product _view_table'  (to be used in each querry for analysis) 
----------------------------------------------------------------------------------------
create or replace view product_view_table as
(
SELECT
    s.order_no,
    s.product_key,
    s.order_date,
    prd.prd_line,
    prd.product_categories,
    prd.product_subcategories as sub_categories,
    prd.product_name,
    prd.product_cost,
    s.quantity,
    s.price,
    s.total_sales,
    prd.maintenance,
    prd.product_start_date
FROM
    analytics_layer.fact_sales s
    LEFT JOIN analytics_layer.dim_products prd on s.product_key = prd.product_key
)
 
----------------------------------------------------------------------------------------
/*  Small querries representing derived and transformed columns for Master table 'product_wise_analytics' mentioned below 
    in 'Section A' */
-- Aggregate calculations for segmenting products
SELECT
    product_key,
    min(order_date) as min_order_date,
    max(order_date) as max_order_date,
    sum(product_cost) as total_cost,
    count(*) as total_orders,
    sum(quantity) as total_units_sold,
    round(sum(total_sales),2) as total_sales    
FROM
    (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price FROM analytics_layer.product_view_table)
group by product_key

--  Calcualtion of production period
SELECT
    product_key,
    product_name,
    extract(year from age(max(order_date),min(order_date))) * 12 +
        extract(MONTH from age(max(order_date),min(order_date))) as production_period
FROM
    analytics_layer.product_view_table
group by product_key,product_name


-- Categorising Products based on total orders and total sales
SELECT
    CASE 
        WHEN quantity > 100 and total_sales > 100000 THEN  'Star Product'
        WHEN total_sales > 50000 THEN  'Premium Product'
        WHEN quantity > 500 THEN 'Volume driver'
        WHEN total_sales > 10000 then 'Avg. Performer'
        WHEN  total_sales < 10000  then 'Underperformer'
    END as product_class,
    count(*) as count_products
FROM
  (
    SELECT
        product_key,
        product_name,
        count(*) as total_orders,
        sum(quantity) as quantity,
        sum(total_sales) as total_sales
    FROM
        analytics_layer.product_view_table
    group by  product_key, product_name
  )
group by product_class

--calculation of profit 

SELECT
    product_key,
    product_cost,
    round(avg(price) OVER(PARTITION BY product_key),2) as price
FROM
    analytics_layer.product_view_table
group by product_key,product_cost,price

/*(Each small querry above explained now merged to become single master table to 
   be used for visualization)  */
   -- --------------------------------------------------------------------------------------------------------------------------------
   -- section: A) 'product_wise_analytics' master table  for visualization
   -- --------------------------------------------------------------------------------------------------------------------------------

CREATE or replace view Product_segmented_report as
(
SELECT
    product_key,
    min(order_date) as min_order_date,
    max(order_date) as max_order_date,
    extract(year from age(max(order_date),min(order_date))) * 12 +
        extract(MONTH from age(max(order_date),min(order_date))) as production_period,
    prd_line,
    product_categories,
    sub_categories,
    product_name,
    product_cost,
    count(*) as total_orders,
    unit_price,
    sum(quantity) as total_units_sold,
    round(sum(total_sales) - sum(total_cost),2) as profit,
    round(sum(total_sales),2) as total_sales,
    CASE 
        WHEN sum(quantity) > 100 and sum(total_sales) > 100000 THEN  'Star Product'
        WHEN sum(total_sales) > 50000 THEN  'Premium Product'
        WHEN sum(quantity) > 500 THEN 'Volume driver'
        WHEN sum(total_sales) > 10000 then 'Avg. Performer'
        WHEN  sum(total_sales) < 10000  then 'Underperformer'
    END as product_class    
FROM
    (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price, product_cost*quantity as total_cost
     FROM analytics_layer.product_view_table)
GROUP BY
    product_key, prd_line, product_categories, sub_categories, product_name, Unit_price, product_start_date,product_cost
order by total_units_Sold DESC   
);



-- ------------------------------------------------------------------------------------------------------------------------
-- section: B) Statistical Observations
-- ------------------------------------------------------------------------------------------------------------------------
select
    'Total Sales Stat' as KPI_Head,
    min(total_sales) as min_value,
    percentile_cont(0.25) WITHIN group(order by total_sales) as Q1,
    percentile_cont(0.5) within group(order by total_sales) as median_Q2,
    percentile_cont(0.75) within group(order by total_sales) as Q3,
    round(avg(total_sales),2) as mean,
    max(total_sales) as max_value
FROM
(
SELECT
    product_key,
    product_name,
    count(*) as total_orders,
    sum(total_sales) as total_sales
FROM
    analytics_layer.product_view_table
group by  product_key, product_name
)

UNION

select
    'Total Orders Stat',
    min(total_orders),
    percentile_cont(0.25) WITHIN group(order by total_orders) as Q1,
    percentile_cont(0.5) within group(order by total_orders) as median_Q2,
    percentile_cont(0.75) within group(order by total_orders) as Q3,
    round(avg(total_orders),2) as mean,
    max(total_orders)
FROM
(
SELECT
    product_key,
    product_name,
    count(*) as total_orders,
    sum(total_sales) as total_sales
FROM
    analytics_layer.product_view_table
group by  product_key, product_name
)

UNION

select
    'Total Qty Sold Stat',
    min(quantity),
    percentile_cont(0.25) WITHIN group(order by quantity) as Q1,
    percentile_cont(0.5) within group(order by quantity) as median_Q2,
    percentile_cont(0.75) within group(order by quantity) as Q3,
    round(avg(quantity),2) as mean,
    max(quantity)
FROM
(
SELECT
    product_key,
    product_name,
    count(*) as total_orders,
    sum(quantity) as quantity,
    sum(total_sales) as total_sales
FROM
    analytics_layer.product_view_table
group by  product_key, product_name
)

     



-- ------------------------------------------------------------------------------------------------------------------------
-- section: C) Classifying products based on total sales range
-- ------------------------------------------------------------------------------------------------------------------------

SELECT
product_sales_range,
total_products,
round(total_products / sum(total_products) over() * 100,2) as products_total_percent
FROM
 (
    SELECT DISTINCT
    CASE 
        WHEN total_sales BETWEEN 0 and 50000 THEN '0-50000' 
        WHEN total_sales BETWEEN 51000 and 100000 THEN '51000 - 100000'
        WHEN total_sales BETWEEN 100001 and 500000 THEN '100001 - 500000' 
        WHEN total_sales BETWEEN 500001 and 1000000 THEN '500001 - 1000000'
        WHEN total_sales > 1000000 then '>1100000'
    END as Product_sales_range,
    CASE 
        WHEN total_sales BETWEEN 0 and 50000 THEN  count(*) over(partition by total_sales BETWEEN 0 and 50000)   
        WHEN total_sales BETWEEN 51000 and 100000 THEN count(*) over(partition by total_sales BETWEEN 51000 and 100000) 
        WHEN total_sales BETWEEN 100001 and 500000 THEN count(*) over(partition by total_sales BETWEEN 100001 and 500000) 
        WHEN total_sales BETWEEN 500001 and 1000000 THEN count(*) over(partition by total_sales BETWEEN 500001 and 1000000) 
        Else count(*) over(partition by total_sales > 1000000) 
    END as Total_Products
        FROM
        (
        SELECT
            product_key,
            product_name,
            count(*) as total_orders,
            sum(total_sales) as total_sales
        FROM
            analytics_layer.product_view_table
        group by  product_key, product_name
        )
        order by total_products desc
 )



-- ------------------------------------------------------------------------------------------------------------------------
-- section: D) Product Demand Analysis
-- ------------------------------------------------------------------------------------------------------------------------
SELECT
Product_demand_range,
total_products,
round(total_products / sum(total_products) over() * 100,2) as products_total_percent
FROM
 (
    SELECT DISTINCT
    CASE 
        WHEN total_orders BETWEEN 0 and 100 THEN '0-100' 
        WHEN total_orders BETWEEN 101 and 500 THEN '101 - 500'
        WHEN total_orders BETWEEN 501 and 1000 THEN '501 - 1000'
        WHEN total_orders BETWEEN 1001 and 3000 THEN '1001 - 3000'  
        WHEN total_orders > 3000 then '>3000'
    END as Product_demand_range,
    CASE 
        WHEN total_orders BETWEEN 0 and 100 THEN  count(*) over(partition by total_orders BETWEEN 0 and 100)   
        WHEN total_orders BETWEEN 101 and 500 THEN count(*) over(partition by total_orders BETWEEN 101 and 500) 
        WHEN total_orders BETWEEN 501 and 1000 THEN count(*) over(partition by total_orders BETWEEN 501 and 1000) 
        WHEN total_orders BETWEEN 1001 and 3000 THEN count(*) over(partition by total_orders BETWEEN 1001 and 3000) 
        Else count(*) over(partition by total_orders > 3000) 
    END as Total_Products
        FROM
        (
        SELECT
            product_key,
            product_name,
            count(*) as total_orders,
            sum(quantity) as quantity,
            sum(total_sales) as total_sales
        FROM
            analytics_layer.product_view_table
        group by  product_key, product_name
        )
        order by total_products desc
 )



-- ------------------------------------------------------------------------------------------------------------------------
-- section: E) Product Distribution
-- ------------------------------------------------------------------------------------------------------------------------

SELECT
product_grade as product_distribution,
Total_price as product_count,
round(Total_price / sum(Total_price) over() * 100,2) as products_total_percent
FROM
 (
    SELECT DISTINCT
    CASE 
        WHEN Unit_price BETWEEN 0 and 100 THEN 'Cheaper (0-100)' 
        WHEN Unit_price BETWEEN 101 and 1000 THEN 'Mid-Range (101 - 1000)' 
        WHEN Unit_price > 1000 then 'Premium (>1000)'
    END as product_grade,
    CASE 
        WHEN Unit_price BETWEEN 0 and 100 THEN  count(*) over(partition by Unit_price BETWEEN 0 and 100)   
        WHEN Unit_price BETWEEN 101 and 1000 THEN count(*) over(partition by Unit_price BETWEEN 101 and 1000) 
        Else count(*) over(partition by Unit_price > 1000) 
    END as Total_price
    FROM
        (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price FROM analytics_layer.product_view_table)
    group by product_key, product_name, Unit_price
 )




-- ------------------------------------------------------------------------------------------------------------------------
-- section: F) Product Grading
-- ------------------------------------------------------------------------------------------------------------------------


    SELECT DISTINCT
    CASE 
        WHEN Unit_price BETWEEN 0 and 100 THEN 'Cheaper (0-100)' 
        WHEN Unit_price BETWEEN 101 and 1000 THEN 'Mid-Range (101 - 1000)' 
        WHEN Unit_price > 1000 then 'Premium (>1000)'
    END as product_range,
    CASE 
        WHEN Unit_price BETWEEN 0 and 100 and product_categories = 'Accessories' THEN  count(*) over(partition by Unit_price BETWEEN 0 and 100 and product_categories = 'Accessories')   
        WHEN Unit_price BETWEEN 101 and 1000 and product_categories = 'Accessories' THEN count(*) over(partition by Unit_price BETWEEN 101 and 1000 and product_categories = 'Accessories') 
        else count(*) over(partition by Unit_price > 1000 and product_categories = 'Accessories') 
    END as Accessories_orders 
    FROM
        (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price FROM analytics_layer.product_view_table)



SELECT
    DISTINCT product_categories,
    count(*) FILTER(where Unit_price BETWEEN 0 and 100) as cheaper_product_count,
    sum(total_sales::INT) FILTER(where Unit_price BETWEEN 0 and 100) as cheaper_product_sale,
    count(*) FILTER(WHERE Unit_price BETWEEN 101 and 1000) as "Mid range product count",
    sum(total_sales::INT) FILTER(WHERE Unit_price BETWEEN 101 and 1000) as "Mid range product sale",
    count(*) FILTER(WHERE Unit_price > 1000) as Premium_product_count,
    sum(total_sales::INT) FILTER(WHERE Unit_price > 1000) as Premium_product_sale
FROM
     (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price FROM analytics_layer.product_view_table)
group by product_categories


-- --------------------------------------------------------------------------------------------------------------------------------
-- section: G) Product Category performance overview
-- --------------------------------------------------------------------------------------------------------------------------------
SELECT
    product_categories,
    sub_categories,
    to_char(avg_price,'999,999,999') as avg_price,
    to_char(unit_sold,'999,999,999') as unit_sold,
    round(unit_sold / sum(unit_sold) OVER(PARTITION BY product_categories) * 100,2) as "unit sold %",
    to_char(total_sales,'999,999,999') as total_sales,
    round(total_sales / sum(total_sales) OVER(PARTITION BY product_categories) * 100,2) as "total sales %"
FROM
    (
    SELECT
        product_categories,
        sub_categories,
        round(avg(price))as avg_price,
        sum(quantity) as unit_sold,
        sum(total_sales) as total_sales
    FROM
        analytics_layer.product_view_table
    group by product_categories,sub_categories 
    order by product_categories,sum(total_sales) DESC,sum(quantity) DESC 
    )




-- --------------------------------------------------------------------------------------------------------------------------------
-- section: H) Product-line assesment
-- --------------------------------------------------------------------------------------------------------------------------------

WITH product_line_sales as
(
SELECT
    DISTINCT prd_line,
    round(avg(price),2) as avg_price,
    sum(quantity) as total_units_sold,
    round(sum(total_sales),2) as total_sales,
    sum(total_cost) as total_cost,
    round(sum(total_sales) - sum(total_cost),2) as profit
FROM
    (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price, product_cost*quantity as total_cost
        FROM analytics_layer.product_view_table)
where prd_line != 'Other Sales'
group by prd_line
)
SELECT
    prd_line,
    avg_price,
    total_units_sold,
    round(total_units_sold / sum(total_units_sold) over() * 100,2) as "% total_units_sold",
    total_sales,
    round(total_sales / sum(total_sales) over() * 100,2) as "% total_sales",
    total_cost,
    profit,
    round(profit / sum(profit) over() * 100,2) as "% profit"
FROM
    product_line_sales


-- --------------------------------------------------------------------------------------------------------------------------------
-- section: I) Product Performance Analysis
-- --------------------------------------------------------------------------------------------------------------------------------
--Profit percent
SELECT
*,
round(profit / total_sales * 100,2)  as "Profit %"
FROM
 (
    SELECT
        product_key,
        product_categories,
        sub_categories,
        product_name,
        unit_price,
        sum(quantity) as total_units_sold,
        round(sum(total_sales),2) as total_sales,  
        sum(total_cost) as total_cost,
        round(sum(total_sales) - sum(total_cost),2) as profit
    FROM
        (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price, product_cost*quantity as total_cost
        FROM analytics_layer.product_view_table)
    group BY
        product_key, product_name, unit_price,sub_categories,product_categories
 )
 order by "Profit %" DESC  

--profit margin

SELECT
*,
round(profit / total_sales * 100,2)  as "Profit %"
FROM
 (
    SELECT
        product_key,
        product_categories,
        sub_categories,
        product_name,
        unit_price,
        sum(quantity) as total_units_sold,
        round(sum(total_sales),2) as total_sales,  
        sum(total_cost) as total_cost,
        round(sum(total_sales) - sum(total_cost),2) as profit
    FROM
        (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price, product_cost*quantity as total_cost
        FROM analytics_layer.product_view_table)
    group BY
        product_key, product_name, unit_price,sub_categories,product_categories
 )
 order by profit DESC


 --Categories based profit analysis
SELECT
product_categories,
round(profit / total_units_sold,2) as avg_profit,
round(profit / total_sales * 100,2)  as "cat_Profit %"
FROM
 (
    SELECT
        product_categories,
        sum(quantity) as total_units_sold,
        round(sum(total_sales),2) as total_sales,  
        sum(total_cost) as total_cost,
        round(sum(total_sales) - sum(total_cost),2) as profit
    FROM
        (SELECT*,round(avg(price) over(partition by product_key),2) as Unit_price, product_cost*quantity as total_cost
        FROM analytics_layer.product_view_table)
    group BY
        product_categories
 )
 order by profit DESC



-- --------------------------------------------------------------------------------------------------------------------------------
-- section: J) Cross-Product Analysis
-- --------------------------------------------------------------------------------------------------------------------------------

select
    round(sum(total_units_sold) FILTER(where product_categories = 'Accessories') / sum(total_units_sold) FILTER(where product_categories = 'Bikes'),0) accessories_sold,
    round(sum(total_sales) FILTER(where product_categories = 'Accessories') / sum(total_units_sold) FILTER(where product_categories = 'Bikes'),2) accessories_sold,
    round(sum(total_units_sold) FILTER(where product_categories = 'Clothing') / sum(total_units_sold) FILTER(where product_categories = 'Bikes'),0) clothing_sold,   
    round(sum(total_sales) FILTER(where product_categories = 'Clothing') / sum(total_units_sold) FILTER(where product_categories = 'Bikes'),2) clothing_sold
from
    analytics_layer.product_segmented_report


-- Monthly exploration of complementary product demand

with product_order_data AS
(
SELECT
    extract(month from order_date) as month,
    product_categories,
    sum(quantity) as total_units_sold,
    round(sum(total_sales),2) as total_sales
FROM
    analytics_layer.product_view_table
GROUP BY
    extract(month from order_date), product_categories
order by extract(month from order_date)
)
select DISTINCT
    MONTH,
    round(sum(total_units_sold) FILTER(where product_categories = 'Accessories') OVER(PARTITION BY MONTH) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY MONTH),0) accessories_unit_sold,
    round(sum(total_sales) FILTER(where product_categories = 'Accessories') OVER(PARTITION BY MONTH) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY MONTH),2) accessories_sale,
    round(sum(total_units_sold) FILTER(where product_categories = 'Clothing') OVER(PARTITION BY MONTH) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY MONTH),0) clothing_unit_sold,   
    round(sum(total_sales) FILTER(where product_categories = 'Clothing') OVER(PARTITION BY MONTH) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY MONTH),2) clothing_sale
from
    product_order_data
where month is not NULL


--Annual exploration of complementary product demand
with product_order_data AS
(
SELECT
    extract(YEAR from order_date) as YEAR,
    product_categories,
    sum(quantity) as total_units_sold,
    round(sum(total_sales),2) as total_sales
FROM
    analytics_layer.product_view_table
GROUP BY
    extract(YEAR from order_date), product_categories
order by extract(YEAR from order_date)
)
select DISTINCT
    YEAR,
    round(sum(total_units_sold) FILTER(where product_categories = 'Accessories') OVER(PARTITION BY YEAR) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY YEAR),2) accessories_unit_sold,
    round(sum(total_sales) FILTER(where product_categories = 'Accessories') OVER(PARTITION BY YEAR) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY YEAR),2) accessories_sale,
    round(sum(total_units_sold) FILTER(where product_categories = 'Clothing') OVER(PARTITION BY YEAR) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY YEAR),0) clothing_unit_sold,   
    round(sum(total_sales) FILTER(where product_categories = 'Clothing') OVER(PARTITION BY YEAR) / sum(total_units_sold) FILTER(where product_categories = 'Bikes') OVER(PARTITION BY YEAR),2) clothing_sale
from
    product_order_data
where YEAR is not NULL


