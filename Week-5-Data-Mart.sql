-- I. Data Cleansing Step 
create table clean_weekly_sales as
SELECT 
	TO_CHAR(TO_DATE(week_date, 'DD/MM/YY'), 'DD-MM-YYYY') AS formatted_week_date,
    case 
    	when EXTRACT(DAY FROM TO_DATE(week_date, 'DD/MM/YY')) between 1 and 7 then 1
        when EXTRACT(DAY FROM TO_DATE(week_date, 'DD/MM/YY')) between 8 and 14 then 2
        when EXTRACT(DAY FROM TO_DATE(week_date, 'DD/MM/YY')) between 15 and 21 then 3
        when EXTRACT(DAY FROM TO_DATE(week_date, 'DD/MM/YY')) between 22 and 28 then 4
        else 5
     end as week_number,
        Week number within each month
    -- or CEIL(EXTRACT(DAY FROM TO_DATE(week_date, 'DD/MM/YY')) / 7.0) AS week_number,
     EXTRACT(MONTH FROM TO_DATE(week_date, 'DD/MM/YY')) as month_number,
     EXTRACT(YEAR FROM TO_DATE(week_date, 'DD/MM/YY')) as calendar_year,
     region,
     platform,
     COALESCE(NULLIf(segment, 'null'),'unknown') as segment,
     COALESCE(
     case
     	when RIGHT(segment, 1) = '1' then 'Young Adults'
        when RIGHT(segment, 1) = '2' then 'Middle Aged'
        when RIGHT(segment, 1) = '3' or RIGHT(segment, 1) = '4' then 'Retirees'
     end, 'unknown') as age_band,
     COALESCE(
     case 
     	when LEFT(segment,1) = 'C' then 'Couples'
        else 'Families'
     end, 'unknown') as demographic,
     ROUND((sales/transactions),2) as avg_transaction,
     sales
from weekly_sales;

-- II. Data Exploration
-- 1. What day of the week is used for each week_date value?
SELECT DISTINCT 
  week_date,
  TO_CHAR(week_date, 'Day') AS day_name
FROM data_mart.clean_weekly_sales
ORDER BY week_date;
-- Monday

-- 2. What range of week numbers are missing from the dataset?
select distinct week_number
from clean_weekly_sales

-- 3. How many total transactions were there for each year in the dataset?
SELECT calendar_year, SUM(transactions) AS total_transactions
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year;

-- 4. What is the total sales for each region for each month?
SELECT region, month_number, SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales
GROUP BY region, month_number;

-- 5. What is the total count of transactions for each platform?
SELECT platform, SUM(transactions) AS total_transactions
FROM data_mart.clean_weekly_sales
GROUP BY platform;

-- 6. What is the percentage of sales for Retail vs Shopify for each month?
SELECT 
    month_number, 
    platform, 
    ROUND(SUM(sales) * 100.0 / SUM(SUM(sales)) OVER (PARTITION BY month_number), 2) AS percentage_of_sales
FROM data_mart.clean_weekly_sales
GROUP BY month_number, platform
ORDER BY month_number, platform;

-- 7. What is the percentage of sales by demographic for each year in the dataset?
select 
	calendar_year, 
    demographic,
    ROUND(sum(sales) * 100.0 / sum(sum(sales))
 	over (partition by calendar_year),2) as percentage_of_sales
from clean_weekly_sales
group by calendar_year, demographic
order by calendar_year, demographic

-- 8. Which age_band and demographic values contribute the most to Retail sales?
WITH more_retail_sales AS (
    SELECT 
        age_band, 
        demographic,
        SUM(sales) AS sum_of_sales
    FROM clean_weekly_sales
    WHERE platform = 'Retail'
    GROUP BY age_band, demographic
)
SELECT age_band, demographic, sum_of_sales
FROM more_retail_sales
ORDER BY sum_of_sales DESC
LIMIT 1;


-- 9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT 
    calendar_year, 
    platform,
    ROUND(SUM(sales) * 1.0 / SUM(transactions), 2) AS avg_transaction_size
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year, platform
ORDER BY calendar_year, platform;


-- III. Before and After Analysis

-- 1. What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
SELECT 
    CASE 
        WHEN week_date < DATE '2020-06-15' THEN 'Before'
        WHEN week_date >= DATE '2020-06-15' AND week_date < DATE '2020-07-13' THEN 'After'
    END AS period,
    SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE week_date BETWEEN DATE '2020-05-18' AND DATE '2020-07-12'
GROUP BY period;

-- 2. What about the entire 12 weeks before and after?
-- Total sales for 12 weeks before and after
SELECT 
    CASE 
        WHEN week_date < DATE '2020-06-15' THEN 'Before'
        WHEN week_date >= DATE '2020-06-15' AND week_date < DATE '2020-09-07' THEN 'After'
    END AS period,
    SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE week_date BETWEEN DATE '2020-03-23' AND DATE '2020-09-06'
GROUP BY period;

-- 3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
SELECT 
    EXTRACT(YEAR FROM week_date) AS year,
    CASE 
        WHEN week_date < DATE '2020-06-15' THEN 'Before'
        ELSE 'After'
    END AS period,
    SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE 
    (
        week_date BETWEEN DATE '2018-03-26' AND DATE '2018-09-09' OR
        week_date BETWEEN DATE '2019-03-25' AND DATE '2019-09-08' OR
        week_date BETWEEN DATE '2020-03-23' AND DATE '2020-09-06'
    )
GROUP BY year, period
ORDER BY year, period;
