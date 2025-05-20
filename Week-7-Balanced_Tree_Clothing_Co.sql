High Level Analysis:

-- 1.What was the total quantity sold for all products?
SELECT SUM(qty) AS total_quantity_sold
FROM balanced_tree.sales;

-- 2. What is the total generated revenue for all products before discounts?
SELECT SUM(qty * price) AS total_revenue_before_discounts
FROM balanced_tree.sales;

-- 3. What was the total discount amount for all products?
SELECT SUM(qty * price * discount / 100.0) AS total_discount_amount
FROM balanced_tree.sales;

Transaction Analysis:

-- 1. How many unique transactions were there?
SELECT COUNT(DISTINCT txn_id) AS unique_transactions
FROM balanced_tree.sales;

-- 2. What is the average unique products purchased in each transaction?
SELECT AVG(product_count) AS avg_unique_products_per_transaction
FROM (
    SELECT txn_id, COUNT(DISTINCT prod_id) AS product_count
    FROM balanced_tree.sales
    GROUP BY txn_id
) AS txn_products;

-- 3. What are the 25th, 50th and 75th percentile values for the revenue per transaction?
SELECT
  percentile_cont(0.25) WITHIN GROUP (ORDER BY txn_revenue) AS percentile_25,
  percentile_cont(0.50) WITHIN GROUP (ORDER BY txn_revenue) AS percentile_50,
  percentile_cont(0.75) WITHIN GROUP (ORDER BY txn_revenue) AS percentile_75
FROM (
    SELECT txn_id,
           SUM(price * qty) AS txn_revenue
    FROM balanced_tree.sales
    GROUP BY txn_id
) AS txn_revenue_data;

-- 4. What is the average discount value per transaction?
SELECT
  AVG(discount_value) AS avg_discount_per_transaction
FROM (
    SELECT
      txn_id,
      SUM((price * qty) * (discount / 100.0)) AS discount_value
    FROM balanced_tree.sales
    GROUP BY txn_id
) AS txn_discounts;

-- 5. What is the percentage split of all transactions for members vs non-members?
SELECT
  member,
  COUNT(DISTINCT txn_id) * 100.0 /
    (SELECT COUNT(DISTINCT txn_id) FROM balanced_tree.sales) AS percentage_split
FROM balanced_tree.sales
GROUP BY member;

-- 6. What is the average revenue for member transactions and non-member transactions?
SELECT
  member,
  ROUND(SUM(price * qty * (1 - discount / 100.0)) / COUNT(DISTINCT txn_id), 2) AS avg_revenue_per_transaction
FROM balanced_tree.sales
GROUP BY member;

Product Analysis:

-- 1. What are the top 3 products by total revenue before discount?
SELECT
  pd.product_name,
  SUM(s.price * s.qty) AS total_revenue_before_discount
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.product_name
ORDER BY total_revenue_before_discount DESC
LIMIT 3;

-- 2. What is the total quantity, revenue and discount for each segment?
SELECT
  pd.segment_name,
  SUM(s.qty) AS total_quantity,
  SUM(s.price * s.qty) AS total_revenue_before_discount,
  SUM(s.discount * s.qty) AS total_discount
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.segment_name;

-- 3. What is the top selling product for each segment?
WITH Segment_Sales AS (
  SELECT
    pd.segment_name,
    s.prod_id,
    SUM(s.qty) AS total_quantity,
    SUM(s.price * s.qty) AS total_revenue_before_discount
  FROM balanced_tree.sales s
  JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
  GROUP BY pd.segment_name, s.prod_id
)
SELECT
  segment_name,
  prod_id,
  total_quantity,
  total_revenue_before_discount
FROM (
  SELECT
    segment_name,
    prod_id,
    total_quantity,
    total_revenue_before_discount,
    RANK() OVER (PARTITION BY segment_name ORDER BY total_revenue_before_discount DESC) AS rank
  FROM Segment_Sales
) ranked_sales
WHERE rank = 1;

-- 4. What is the total quantity, revenue and discount for each category?
SELECT
  pd.category_name,
  SUM(s.qty) AS total_quantity,
  SUM(s.qty * s.price) AS total_revenue_before_discount,
  SUM(s.qty * s.discount) AS total_discount
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.category_name;

-- 5. What is the top selling product for each category?
SELECT
  pd.category_name,
  pd.product_name,
  SUM(s.qty) AS total_quantity_sold
FROM balanced_tree.sales s
JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
GROUP BY pd.category_name, pd.product_name
ORDER BY pd.category_name, total_quantity_sold DESC;

-- 6. What is the percentage split of revenue by product for each segment?
WITH total_revenue_per_segment AS (
  SELECT
    pd.segment_name,
    SUM(s.qty * s.price) AS segment_revenue
  FROM balanced_tree.sales s
  JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
  GROUP BY pd.segment_name
),
revenue_by_product AS (
  SELECT
    pd.segment_name,
    pd.product_name,
    SUM(s.qty * s.price) AS product_revenue
  FROM balanced_tree.sales s
  JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
  GROUP BY pd.segment_name, pd.product_name
)
SELECT
  r.segment_name,
  r.product_name,
  r.product_revenue,
  (r.product_revenue / t.segment_revenue) * 100 AS revenue_percentage
FROM revenue_by_product r
JOIN total_revenue_per_segment t ON r.segment_name = t.segment_name
ORDER BY r.segment_name, revenue_percentage DESC;

-- 7. What is the percentage split of revenue by segment for each category?
WITH total_revenue_per_category AS (
  SELECT
    pd.category_name,
    SUM(s.qty * s.price) AS category_revenue
  FROM balanced_tree.sales s
  JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
  GROUP BY pd.category_name
),
revenue_by_segment AS (
  SELECT
    pd.category_name,
    pd.segment_name,
    SUM(s.qty * s.price) AS segment_revenue
  FROM balanced_tree.sales s
  JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
  GROUP BY pd.category_name, pd.segment_name
)
SELECT
  r.category_name,
  r.segment_name,
  r.segment_revenue,
  (r.segment_revenue / t.category_revenue) * 100 AS revenue_percentage
FROM revenue_by_segment r
JOIN total_revenue_per_category t ON r.category_name = t.category_name
ORDER BY r.category_name, revenue_percentage DESC;

-- 8. What is the percentage split of total revenue by category?
WITH total_revenue AS (
  SELECT
    SUM(s.qty * s.price) AS total_revenue
  FROM balanced_tree.sales s
),
revenue_by_category AS (
  SELECT
    pd.category_name,
    SUM(s.qty * s.price) AS category_revenue
  FROM balanced_tree.sales s
  JOIN balanced_tree.product_details pd ON s.prod_id = pd.product_id
  GROUP BY pd.category_name
)
SELECT
  r.category_name,
  r.category_revenue,
  (r.category_revenue / t.total_revenue) * 100 AS revenue_percentage
FROM revenue_by_category r
JOIN total_revenue t
ORDER BY revenue_percentage DESC;

-- 9. What is the total transaction “penetration” for each product? (hint: penetration = number of transactions where at least 1 quantity of a product was purchased divided by total number of transactions)
WITH total_transactions AS (
  SELECT COUNT(DISTINCT txn_id) AS total_txns
  FROM balanced_tree.sales
),
transactions_per_product AS (
  SELECT
    s.prod_id,
    COUNT(DISTINCT s.txn_id) AS product_txns
  FROM balanced_tree.sales s
  GROUP BY s.prod_id
)
SELECT
  tp.prod_id,
  tp.product_txns,
  (tp.product_txns * 1.0 / tt.total_txns) AS penetration
FROM transactions_per_product tp
JOIN total_transactions tt
ORDER BY penetration DESC;

-- 10. What is the most common combination of at least 1 quantity of any 3 products in a 1 single transaction?
WITH product_combinations AS (
  SELECT
    txn_id,
    ARRAY_AGG(prod_id ORDER BY prod_id) AS products
  FROM balanced_tree.sales
  GROUP BY txn_id
  HAVING COUNT(DISTINCT prod_id) >= 3
)
SELECT
  products,
  COUNT(*) AS combination_count
FROM product_combinations
GROUP BY products
ORDER BY combination_count DESC
LIMIT 1;