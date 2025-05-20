-- 1. How many unique nodes are there on the Data Bank system?
SELECT COUNT(DISTINCT node_id) AS distinct_nodes 
FROM customer_nodes;

-- 2. What is the number of nodes per region?
SELECT 
  regions.region_name, 
  COUNT(DISTINCT customer_nodes.node_id) AS distinct_nodes 
FROM customer_nodes
JOIN regions ON regions.region_id = customer_nodes.region_id
GROUP BY regions.region_name;

-- 3. How many customers are allocated to each region?
SELECT 
    regions.region_name, 
    COUNT(DISTINCT customer_nodes.customer_id) AS distinct_customers 
FROM customer_nodes
JOIN regions ON regions.region_id = customer_nodes.region_id
GROUP BY regions.region_name;

-- 4. How many days on average are customers reallocated to a different node?
SELECT 
    ROUND(AVG(end_date - start_date), 2) AS avg_reallocation_days
FROM customer_nodes;

-- 5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
SELECT 
    r.region_name,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY (cn.end_date - cn.start_date)), 2) AS median_days,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY (cn.end_date - cn.start_date)), 2) AS p80_days,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY (cn.end_date - cn.start_date)), 2) AS p95_days
FROM customer_nodes cn
JOIN regions r ON cn.region_id = r.region_id
GROUP BY r.region_name
ORDER BY r.region_name;

-- B. Customer Transactions
-- 1. What is the unique count and total amount for each transaction type?
SELECT 
    txn_type, 
    COUNT(*) AS transaction_count, 
    SUM(txn_amount) AS total_amount
FROM customer_transactions
GROUP BY txn_type;

-- 2. What is the average total historical deposit counts and amounts for all customers?
-- How many transactions they made for 'deposit' and how much each customer deposited 
select customer_id, count(*) as count_of_transactions, sum(txn_amount)
from customer_transactions
where txn_type = 'deposit'
group by customer_id

-- Average total historical deposit counts and amounts across all customers
SELECT 
    ROUND(AVG(deposit_count), 2) AS avg_deposit_count,
    ROUND(AVG(deposit_amount), 2) AS avg_deposit_amount
FROM (
    SELECT 
        customer_id, 
        COUNT(*) AS deposit_count, 
        SUM(txn_amount) AS deposit_amount
    FROM customer_transactions
    WHERE txn_type = 'deposit'
    GROUP BY customer_id
) AS customer_deposits;

-- 3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH monthly_activity AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS txn_month,
        SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
        SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
        SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
    FROM customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
)
SELECT 
    txn_month,
    COUNT(DISTINCT customer_id) AS qualifying_customers
FROM monthly_activity
WHERE deposit_count > 1
  AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY txn_month
ORDER BY txn_month;

-- 4. What is the closing balance for each customer at the end of the month?
WITH monthly_transactions AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS txn_month,
        SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS total_deposit,
        SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS total_withdrawal,
        SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS total_purchase
    FROM customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
)
SELECT 
    customer_id,
    txn_month,
    total_deposit - total_withdrawal - total_purchase AS closing_balance
FROM monthly_transactions
ORDER BY customer_id, txn_month;

-- 5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH monthly_transactions AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', txn_date) AS txn_month,
        SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS total_deposit,
        SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS total_withdrawal,
        SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS total_purchase
    FROM customer_transactions
    GROUP BY customer_id, DATE_TRUNC('month', txn_date)
),
closing_balances AS (
    SELECT 
        customer_id,
        txn_month,
        total_deposit - total_withdrawal - total_purchase AS closing_balance
    FROM monthly_transactions
),
balance_changes AS (
    SELECT 
        cb1.customer_id,
        cb1.txn_month,
        cb1.closing_balance,
        LAG(cb1.closing_balance) OVER (PARTITION BY cb1.customer_id ORDER BY cb1.txn_month) AS previous_month_balance
    FROM closing_balances cb1
)
SELECT 
    COUNT(DISTINCT customer_id) * 100.0 / (SELECT COUNT(DISTINCT customer_id) FROM closing_balances) AS percentage_increased_by_5
FROM balance_changes
WHERE previous_month_balance IS NOT NULL
  AND (closing_balance - previous_month_balance) / previous_month_balance > 0.05;
