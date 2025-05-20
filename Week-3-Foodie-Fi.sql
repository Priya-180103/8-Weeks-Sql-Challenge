-- 1. How many customers has Foodie-Fi ever had?
select count(distinct(subs.customer_id)) as total_customers
from subscriptions subs

-- 2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
select 
    DATE_TRUNC('month', start_date)::date as month_starts,
    count(start_date) as count_of_trail_plan_users
from subscriptions 
where plan_id = 0
group by month_starts
order by month_starts

-- 3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
select plans.plan_name, count(subscriptions.customer_id) as total_customers_for_each_plan_in_2021
from subscriptions 
join plans on plans.plan_id = subscriptions.plan_id
where subscriptions.start_date >='2021-01-01'
group by plans.plan_name
order by plans.plan_name

-- 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
select 
	count(distinct customer_id) AS total_churned_customers,
    ROUND(count(distinct customer_id) * 100.0 /(select count(distinct customer_id) from subscriptions),1) as percentage_of_churned_customers
from subscriptions
where plan_id = 4

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
select 
	count(distinct customer_id) as customers_who_churned_after_trail,
    ROUND(count(distinct customer_id) * 100.0 / (select count(distinct customer_id) from subscriptions)) as percentage_of_customers_who_churned_after_trail
from subscriptions
where customer_id in (select customer_id
                      from subscriptions
                      where plan_id = 0) 
                   and customer_id in 
                   	  (select customer_id
                      from subscriptions
                      where plan_id = 4) 
                    and customer_id not in 
                       (select customer_id
                      from subscriptions
                      where plan_id = 1) 
                    and customer_id not in 
                       (select customer_id
                      from subscriptions
                      where plan_id = 2) 
                    and customer_id not in 
                       (select customer_id
                      from subscriptions
                      where plan_id = 3) 
                      
-- Using Having, MAX, CASE
SELECT 
    COUNT(DISTINCT customer_id) AS customers_who_churned_after_trial,
    ROUND(
        COUNT(DISTINCT customer_id) * 100.0 / 
        (SELECT COUNT(DISTINCT customer_id) FROM subscriptions)
    ) AS percentage_of_customers_who_churned_after_trial
FROM subscriptions
WHERE customer_id IN (
    SELECT customer_id
    FROM subscriptions
    GROUP BY customer_id
    HAVING 
        MAX(CASE WHEN plan_id = 0 THEN 1 ELSE 0 END) = 1 AND
        MAX(CASE WHEN plan_id = 4 THEN 1 ELSE 0 END) = 1 AND
        MAX(CASE WHEN plan_id IN (1,2,3) THEN 1 ELSE 0 END) = 0
);

-- Using Having, SUM
SELECT customer_id
FROM subscriptions
GROUP BY customer_id
HAVING 
  SUM(CASE WHEN plan_id = 0 THEN 1 ELSE 0 END) > 0 -- trial
  AND SUM(CASE WHEN plan_id = 4 THEN 1 ELSE 0 END) > 0 -- churn
  AND SUM(CASE WHEN plan_id IN (1, 2, 3) THEN 1 ELSE 0 END) = 0 -- no paid plans


-- 6. What is the number and percentage of customer plans after their initial free trial?
select count(distinct customer_id) as count_of_customers,ROUND(count(distinct customer_id) * 100.0 / (select 				   count(distinct customer_id) from subscriptions), 1) as   		   percentage_of_customers
from subscriptions
where plan_id not in (0,4) and customer_id in 
	(select distinct customer_id
	from subscriptions
	where plan_id = 0)

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
-- Method - 1
select 
	count(subscriptions.customer_id) as customer_count,    		plans.plan_name, 
    count(subscriptions.customer_id) * 100.0 / (select count(distinct customer_id) from subscriptions) as percentage_breakdown
from subscriptions
join plans on subscriptions.plan_id = plans.plan_id
where subscriptions.start_date >= '2020-01-01' and subscriptions.start_date <= '2020-12-31'
group by plans.plan_name

with latest_plan_per_customer AS (
  select customer_id, plan_id
  from (
    select customer_id, plan_id, start_date,
           rank() over (partition by customer_id order by start_date desc) as rk
    from subscriptions
    where start_date <= '2020-12-31'
  ) ranked
  where rk = 1
)

-- Method - 2
select 
  p.plan_name,
  count(lpc.customer_id) as customer_count,
  ROUND(count(lpc.customer_id) * 100.0 / (select count(distinct customer_id) from subscriptions), 1) as percentage_breakdown
from latest_plan_per_customer lpc
join plans p ON lpc.plan_id = p.plan_id
group by p.plan_name
order by customer_count desc;

-- 8. How many customers have upgraded to an annual plan in 2020?
select count(distinct customer_id) as customers_upgraded_to_annual_plan_in_2020
from subscriptions
where plan_id = 3 
	and start_date >='2020-01-01' 
    and start_date <= '2020-12-31'

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
select 
	ROUND(AVG(annual_start - trial_start)) as avg_days_before_upgradation
from (
	select 
  		s1.customer_id,
  		s1.start_date as trial_start,
   	    s2.start_date as annual_start
    from subscriptions as s1 
    join subscriptions as s2 
    on s1.customer_id = s2.customer_id
    where s1.plan_id = 0
    and s2.plan_id = 3
) as trial_to_annual_plan 

-- 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
select 
    case 
      when days_to_upgrade between 0 and 30 then '0-30 days'
      when days_to_upgrade between 31 and 60 then '31-60 days'
      when days_to_upgrade between 61 and 90 then '61-90 days'
      when days_to_upgrade between 91 and 120 then '91-120 days'
      else '120+ days'
     end as upgrade_bucket,
     count(*) as customer_count
from (
	select 
  		s1.customer_id,
   	    s2.start_date - s1.start_date as days_to_upgrade
    from subscriptions as s1 
    join subscriptions as s2 
    on s1.customer_id = s2.customer_id
    where s1.plan_id = 0
    and s2.plan_id = 3
) as trial_to_annual_plan 
group by upgrade_bucket
order by MIN(days_to_upgrade);

-- 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
select count(distinct customer_id)
from (
    select s1.customer_id
	from subscriptions s1
    join subscriptions s2 on s1.customer_id = s2.customer_id
    where s1.plan_id = 2
    and   s2.plan_id = 1
    and   s1.start_date < s2.start_date
    and s1.start_date between '2020-01-01' and '2020-12-31'
    and s2.start_date between '2020-01-01' and '2020-12-31'
) as customers_moved_from_pro_monthly_to_basic_monthly

op: 0 (No one downgraded their plan from pro monthly to basic monthly) 