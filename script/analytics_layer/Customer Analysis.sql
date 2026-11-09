-- Active: 1789844606371@@127.0.0.1@5432@adventureworks_bicycle_retail@analytics_layer
/*
========================================================================================================================
Advance Customer-segmented Analytics reports (Source -> Analytics_layer)
========================================================================================================================
Intro:--  This section prioritises more on customers influence on sale by analysisng their pattern like spending range, 
geographic distribution etc.


Objective:--
  1) Create View table 'Customer_view_table'
  2) Customer_segmented_report (master table) for visualisation and interactive dashbord.
     --> It includes multiple derive columns or measures based on business rule e.g. age-group, customer type, 
         avg_cust_spending etc
  3) Geographic customer distribution
  4) Marital influence weightage on sale
  5) Proportional anlysis
  6) Running Sum and percent
  7) Statistical observation
  8) Acquisition rate
  9) Churning Rate
=========================================================================================================================
*/


/*
=======================================================================================================================
--section:  Create View - 'customer_view_table'  (to be used in each querry for analysis)
=======================================================================================================================
*/

CREATE OR REPLACE VIEW customer_view_table AS
 SELECT s.order_no,
    s.customer_key,
    c.full_name,
    c.gender,
    c.marital_status,
    c.birth_date,
    c.cntry AS country,
    s.quantity,
    s.price,
    s.total_sales,
    s.order_date,
    c.create_date
   FROM (fact_sales s
     LEFT JOIN dim_customers c ON ((s.customer_key = c.customer_key)))
  WHERE (s.order_date IS NOT NULL);
----------------------------------------------------------------------------------------


/*  Small querries representing derived and transformed columns for Master table 'custoemr_segmented_analytics' mentioned below 
    in 'Section A' */

--Customer_aggragation Metrics

SELECT
  customer_key,
  full_name,
  gender,
  count(*) as total_orders,
  sum(quantity) as total_qty,
  sum(total_sales) as total_sales,
  round(sum(total_sales)/count(*),2) as avg_order_value
  FROM
  customer_view_table
group by customer_key,full_name,gender
order by sum(total_sales) DESC


-- calculate total lifespan customers remain ordering from store till last order
SELECT
  customer_key,
  full_name,
  gender,
  min(order_date) as First_order_date,
  max(order_date) as last_order_date,
  extract(year from age(max(order_date),min(order_date)))*12 + extract(MONTH from age(max(order_date),min(order_date))) as lifespam_month
FROM
  customer_view_table
group by customer_key,full_name,gender
order by sum(total_sales) DESC


-- Calculate recency
  SELECT
  customer_key
  full_name,
  gender,
  extract(year FROM age(current_date,max(order_date)))*12 + extract(MONTH FROM age(current_date,max(order_date))) as recency_month
FROM
  customer_view_table
group by customer_key,full_name,gender,create_date
order by sum(total_sales) DESC

-- Transform Birthdate  to age of customers
SELECT
customer_key,
age,
grouping,
CASE 
  WHEN GROUPING = 1 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  WHEN GROUPING = 2 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  WHEN GROUPING = 3 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  WHEN GROUPING = 4 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  ELSE NULL
END
FROM
(
select
  customer_key,
  full_name,
  gender,
  extract(year FROM age(current_date,birth_date)) as age,
  ntile(4) OVER(order by extract(year FROM age(current_date,birth_date))) as grouping
FROM
  customer_view_table
group by customer_key,full_name,gender,create_date,birth_date
)
order BY GROUPING



-- Framing customer type based on business rule

SELECT 
*,
round(count/sum(count)over()*100,2) as cust_proportion,
round(total_sales/sum(total_sales)over()*100,2) as sales_proportion
FROM
(
SELECT
  CASE 
    WHEN total_sales > 2500 and order_frequency > 10 THEN 'VIP'
    WHEN total_sales > 5000  then 'Big Spenders'
    WHEN total_sales > 100  and order_frequency > 1 then 'regular'
    WHEN total_sales <= 100 and order_frequency > 1 then 'Low-value customers'
    WHEN order_frequency = 1 then 'New Customers'
    ELSE 'Not Defined'  
  END as customer_type,
  round(sum(total_sales)) as total_sales,
  count(*)
FROM
(
SELECT
  customer_key,
  count(*) as order_frequency,
  sum(total_sales) as total_sales
FROM
  customer_view_table
group by customer_key
)
group by customer_type
)

/*(Each small querry above explained now merged to become single master table to 
   be used for visualization)  */

-- ------------------------------------------------------------------------------------------------------------------------
-- section: A) 'customer_segmented_report' master table  for visualization
-- ------------------------------------------------------------------------------------------------------------------------

create view customer_segmented_report AS
(
with customer_segmented_report as 
(
SELECT
  s.customer_key,
  full_name,
  gender,
  marital_status,
  extract(year FROM age(current_date,birth_date)) as age,
  birth_date,
  cntry as country,
  count(*) as total_orders,
  sum(quantity) as total_qty,
  sum(total_sales) as total_sales,
  round(sum(total_sales)/count(*),2) as avg_order_value,
  min(order_date) as min_order_date,
  max(order_date) as max_order_date,
  max(create_date),
  ntile(4) OVER(order by extract(year FROM age(current_date,birth_date))) as grouping
FROM
  analytics_layer.fact_sales s 
  left join analytics_layer.dim_customers c on s.customer_key = c.customer_key
where order_date is NOT NULL
group by s.customer_key,full_name,gender,marital_status, age, birth_date, country
order by customer_key
),
-- Avg order gap (month) on previous orders
avg_order_gap as
(
SELECT
  *,  
  round(sum(cust_return_date) OVER(partition by customer_key)/count(*) OVER(partition by customer_key),2) as avg_order_gap
FROM
(
SELECT
  customer_key,
  order_date,
  lag(order_date) OVER(partition by customer_key order by order_date) as previous_order ,
  extract(YEAR from (age(order_date,lag(order_date) OVER(partition by customer_key order by order_date))))*12 + 
  extract(MONTH from (age(order_date,lag(order_date) OVER(partition by customer_key order by order_date)))) 
   as cust_return_date
FROM
  analytics_layer.customer_view_table
where order_date is not NULL
group by customer_key,order_date
order by customer_key
)
) 
select
  c.customer_key,
  full_name,
  gender,
  marital_status,
  age,
  CASE 
  WHEN GROUPING = 1 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  WHEN GROUPING = 2 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  WHEN GROUPING = 3 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  WHEN GROUPING = 4 THEN min(age) OVER(partition by GROUPING) || '-' || max(age) OVER(partition by GROUPING)
  ELSE NULL
  end as age_group,
  country,
  CASE 
    WHEN total_sales > 2500 and total_orders > 10 THEN 'VIP'
    WHEN total_sales > 5000  then 'Big Spenders'
    WHEN total_sales > 100  and total_orders > 1 then 'regular'
    WHEN total_sales <= 100 and total_orders > 1 then 'Low-value customers'
    WHEN total_orders = 1 then 'New Customers'
    ELSE 'Not Defined'  
  END as customer_type,
  total_orders,
  total_qty,
  total_sales,
  avg_order_value,
  og.avg_order_gap,
  extract(year from age(max_order_date,min_order_date))*12 + extract(MONTH from age(max_order_date,min_order_date)) as lifespam_month,
  extract(year FROM age(current_date,max_order_date))*12 + extract(MONTH FROM age(current_date,max_order_date)) as recency_month
from customer_segmented_report c
  left JOIN avg_order_gap og on c.customer_key = og.customer_key 
group by c.customer_key,full_name,gender,marital_status,age,country,total_sales,total_orders,GROUPING,total_qty,max_order_date,
        min_order_date,avg_order_value, og.avg_order_gap
order by customer_key
);

-- --------------------------------------------------------------------------------------------------------------------------------





-- --------------------------------------------------------------------------------------------------------------------------------
-- section: B) Statistical data
-- --------------------------------------------------------------------------------------------------------------------------------
SELECT
  min(total_sales),
  max(total_sales),
  avg(total_sales) as mean,
  percentile_cont(0.25) within GROUP(order by total_sales) as q1,
  percentile_cont(0.5) within GROUP(order by total_sales) as q2,
  percentile_cont(0.75) within GROUP(order by total_sales) as q3
FROM
(
SELECT
  customer_key
  full_name,
  gender,
  sum(total_sales) as total_sales
FROM
  customer_view_table
group by customer_key,full_name,gender
order by sum(total_sales) DESC
);



-- --------------------------------------------------------------------------------------------------------------------------------
-- section: C) Customer Spending range- 
--          --> Total customers categorises based on their total spending range and calculate running_sum percent
-- --------------------------------------------------------------------------------------------------------------------------------   
select
*,
round((running_sum/sum(total_orders) OVER())*100,2) as running_sum_percent
FROM
(
SELECT distinct
GROUPING,
sales_range_cat,
count(*) as total_orders,
sum(count(*)) OVER(order by GROUPING) as running_sum
FROM
(
SELECT
customer_key,
total_sales,
grouping,
CASE 
  WHEN GROUPING = 1 THEN min(total_sales) OVER(partition by GROUPING) || '-' || max(total_sales) OVER(partition by GROUPING)
  WHEN GROUPING = 2 THEN min(total_sales) OVER(partition by GROUPING) || '-' || max(total_sales) OVER(partition by GROUPING)
  WHEN GROUPING = 3 THEN min(total_sales) OVER(partition by GROUPING) || '-' || max(total_sales) OVER(partition by GROUPING)
  WHEN GROUPING = 4 THEN min(total_sales) OVER(partition by GROUPING) || '-' || max(total_sales) OVER(partition by GROUPING)
  ELSE NULL
END as sales_range_cat
FROM
(
SELECT
  customer_key,
  full_name,
  gender,
  extract(year from age(max(order_date),min(order_date)))*12 + extract(MONTH from age(max(order_date),min(order_date))) as lifespam_month, --month conversion
  sum(total_sales) as total_sales,
  ntile(4) OVER(order by sum(total_sales) asc) as GROUPING
FROM
  customer_view_table
group by customer_key,full_name,gender
)
)
group by GROUPING, sales_range_cat
order by GROUPING
);


-- --------------------------------------------------------------------------------------------------------------------------------
-- section: D) Order frequency -->
-- --------------------------------------------------------------------------------------------------------------------------------  
  /*(less than 1% of customers orders more than 20 times from the store and 99% of customers return after 1st order)*/
SELECT
order_range,
total_customers,
round((sum(total_customers) OVER(order by order_range )/sum(total_customers) over())*100,2) as running_percent  
FROM
(
SELECT DISTINCT
CASE 
  WHEN order_frequency = 1 THEN 'New (<=1)'
  WHEN order_frequency  BETWEEN 2 and 10 then 'potential (2-10)'
  WHEN order_frequency  BETWEEN 11 and 20 then 'Regular (11-20)'
  ELSE 'VIP (>20)' 
END as order_range,
count(*) as total_customers
FROM
(
SELECT
  customer_key,
  count(*) as order_frequency
FROM
  customer_view_table
group by customer_key
)
group by order_range
);




----------------------------------------------------------------------------------------------------------------------------------
-- section: E) Geographic Distribution of customers -->
----------------------------------------------------------------------------------------------------------------------------------
SELECT
country,
total_orders as total_customers,
round((sum(total_orders) OVER(order by total_orders desc)/ sum(total_orders) over())*100,2) as running_customer_percent,
round((total_orders/sum(total_orders) over())*100,2) as total_cust_percent,
total_qty,
total_sales,
round(total_sales /total_orders,2) as avg_cust_spending
FROM
(
SELECT
  country,
  count(*) as total_orders,
  sum(quantity) as total_qty,
  round(sum(total_sales),0) as total_sales
FROM
  customer_view_table
where order_date is not NULL
group by country
);



-- --------------------------------------------------------------------------------------------------------------------------------
-- section: F) Customers Demographic Analysis (Age-wise)
-- --------------------------------------------------------------------------------------------------------------------------------

select*,
round(total_sales / sum(total_sales) over() * 100,2) total_sales
FROM
(
SELECT
  distinct age_group,
  count(*) as total_customers,
  sum(total_qty) as total_units_sold,
  round(sum(total_sales),2) AS total_sales
FROM
  analytics_layer.customer_segmented_report
group by age_group
)

--gender-wise contribution on orders --> no any major issues diagnosed in this section
select*,
round(total_male_sales / sum(total_male_sales) over() * 100,2) total_male_sales,
round(total_female_sales / sum(total_female_sales) over() * 100,2) total_female_sales
FROM
(
SELECT
  distinct country,
  count(*) filter(where gender = 'Male') as total_Male_customers,
  count(*) filter(where gender = 'Female') as total_Female_customers,
  sum(total_qty) filter(where gender = 'Male') as total_units_male,
  sum(total_qty) filter(where gender = 'Female') as total_units_Female,
  round(sum(total_sales) filter(where gender = 'Male'),2) AS total_male_sales,
  round(sum(total_sales) filter(where gender = 'Female'),2) AS total_female_sales
FROM
  analytics_layer.customer_segmented_report
group by country
)

--Observing Marrital status influence on Sale
select*,
round(total_sales / sum(total_sales) over() * 100,2) total_sales
FROM
(
SELECT
  distinct marital_status,
  count(*) as total_customers,
  sum(total_qty) as total_units_sold,
  round(sum(total_sales),2) AS total_sales
FROM
  analytics_layer.customer_segmented_report
group by marital_status
)




-- --------------------------------------------------------------------------------------------------------------------------------
-- section: G) Order Gap
-- --------------------------------------------------------------------------------------------------------------------------------
/*Number of customers placed more than 1 orders within year*/

SELECT
count(distinct customer_key) as total_customers,
count(distinct customer_key) FILTER(where order_gap <12 and order_gap != 0) as below_year_order_gap,
round(count(distinct customer_key) FILTER(where order_gap < 12 and order_gap != 0)::NUMERIC / count(distinct customer_key) *100,2) as percent_below_year_gap
FROM
(
SELECT
  customer_key,
  full_name,
  gender,
  order_date,
  lag(order_date) over(partition by customer_key order by order_date) as previous_order_date,
  extract(YEAR from age(order_date, lag(order_date) over(partition by customer_key order by order_date)))*12 + 
    extract(MONTH from age(order_date, lag(order_date) over(partition by customer_key order by order_date))) as order_gap --monthly-wise
FROM
  customer_view_table
order by customer_key
)



-- --------------------------------------------------------------------------------------------------------------------------------
-- section: H) Acquisition Rate --> 
-- --------------------------------------------------------------------------------------------------------------------------------  
/*Number of customers added every year*/
WITH new_cust_table as
(
  SELECT
    customer_key,
    min(extract(year from order_date)) as YEAR
  FROM
    analytics_layer.customer_view_table
  group by customer_key
),
new_customers as
(
SELECT
  distinct year,
  count(*) as new_customers
FROM
  new_cust_table
group by YEAR
)
SELECT
  *,
  lag(new_customers) over(order by year) as last_year_cust,
  round((new_customers::NUMERIC -  lag(new_customers) over(order by year)) / new_customers * 100,2) as acquisition_rate
FROM
  new_customers
where year not in(2010,2014);



-- --------------------------------------------------------------------------------------------------------------------------------
-- section: I) churn rate
-- --------------------------------------------------------------------------------------------------------------------------------
/*Number of customers didnt come next year after making purchase in current year*/
WITH annual_customers as
(
  SELECT
    distinct extract(year from order_date) as year,
    customer_key
  FROM
    analytics_layer.customer_view_table
  order by year, customer_key
),
churn_customers AS
(
  SELECT
    a.YEAR,
    count(*) as churn_customers
  FROM
    annual_customers a 
    left join annual_customers b 
    on a.customer_key = b.customer_key and b.YEAR = a.YEAR+1
    where b.customer_key is NULL
    group by  a.YEAR
),
total_customers AS
(
  SELECT
    year,
    count(DISTINCT customer_key) as total_customers
  FROM
    annual_customers
  group by year
)
SELECT
  t.year,
  c.churn_customers,
  t.total_customers,
  round(c.churn_customers::NUMERIC / t.total_customers * 100,2) as annual_churn_percent
FROM
  churn_customers c
  JOIN total_customers t on c.year = t.YEAR
where t.year not in(2010,2014)




