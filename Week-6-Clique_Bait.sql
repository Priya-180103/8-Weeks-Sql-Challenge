II. Digital Analysis

-- 1. How many users are there?
SELECT COUNT(DISTINCT user_id) AS total_users
FROM users;

-- 2. How many cookies does each user have on average?
SELECT AVG(cookie_count) AS average_cookies
FROM (
    SELECT user_id, COUNT(cookie_id) AS cookie_count
    FROM users
    GROUP BY user_id
) AS user_cookies;

-- 3. What is the unique number of visits by all users per month?
SELECT
    EXTRACT(YEAR FROM Events.event_time) AS year,
    EXTRACT(MONTH FROM Events.event_time) AS month,
    COUNT(DISTINCT Events.visit_id) AS unique_visits
FROM Users
JOIN Events ON Users.cookie_id = Events.cookie_id
GROUP BY year, month
ORDER BY year, month;

-- 4. What is the number of events for each event type?
SELECT Event_identifier.event_name, COUNT(Events.event_type) AS event_count
FROM Events
JOIN Event_identifier ON Events.event_type = Event_identifier.event_type
GROUP BY Event_identifier.event_name;

-- 5. What is the percentage of visits which have a purchase event?
SELECT COUNT(visit_id) * 100.0 / (SELECT COUNT(visit_id) FROM Events)
FROM Events
WHERE event_type = 3;

-- 6. What is the percentage of visits which view the checkout page but do not have a purchase event?
SELECT COUNT(DISTINCT Events.visit_id) * 100.0 /
       (SELECT COUNT(DISTINCT visit_id) FROM Events) AS checkout_no_purchase_percentage
FROM Events
JOIN Page_hierarchy ON Events.page_id = Page_hierarchy.page_id
WHERE Page_hierarchy.page_id = 12
AND Events.visit_id NOT IN (
    SELECT DISTINCT visit_id
    FROM Events
    WHERE event_type = 3
);

-- 7. What are the top 3 pages by number of views?
SELECT Page_hierarchy.page_name, COUNT(Events.page_id)
FROM Events
JOIN Page_Hierarchy ON Events.page_id = Page_hierarchy.page_id
WHERE Events.event_type = 1
GROUP BY Page_hierarchy.page_name
ORDER BY COUNT(Events.page_id) DESC
LIMIT 3;

-- 8. What is the number of views and cart adds for each product category?
SELECT
  Page_hierarchy.product_category,
  COUNT(CASE WHEN Events.event_type = 1 THEN 1 END) AS views_count,
  COUNT(CASE WHEN Events.event_type = 2 THEN 1 END) AS add_to_cart_count
FROM
  Users
JOIN
  Events ON Users.cookie_id = Events.cookie_id
JOIN
  Page_Hierarchy ON Events.page_id = Page_Hierarchy.page_id
WHERE
  Events.page_id >= 3 AND Events.page_id <= 11
GROUP BY
  Page_hierarchy.product_category
HAVING
  Page_hierarchy.product_category IS NOT NULL;

-- 9. What are the top 3 products by purchases?
SELECT
  Page_Hierarchy.product_id,
  COUNT(Events.event_type) AS purchase_count
FROM
  Users
JOIN
  Events ON Users.cookie_id = Events.cookie_id
JOIN
  Page_Hierarchy ON Events.page_id = Page_Hierarchy.page_id
WHERE
  Events.page_id >= 3 AND Events.page_id <= 11
  AND Events.event_type = 3  -- Only purchases
GROUP BY
  Page_Hierarchy.product_id
ORDER BY
  purchase_count DESC
LIMIT 3;

--------------------------------------------------------------

III Product Funnel Analysis

-- How many times was each product viewed?
-- How many times was each product added to cart?
-- How many times was each product added to a cart but not purchased (abandoned)?
-- How many times was each product purchased?
-- Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

Output table:
Product - Level Analysis Table:

CREATE TABLE Product_Funnel_Analysis AS
SELECT
    Page_Hierarchy.product_id,
    COUNT(CASE WHEN Events.event_type = 1 THEN 1 END) AS views_count,    -- Count of views (event_type = 1)
    COUNT(CASE WHEN Events.event_type = 2 THEN 1 END) AS add_to_cart_count,  -- Count of cart adds (event_type = 2)
    COUNT(CASE WHEN Events.event_type = 2 AND Events.visit_id NOT IN (SELECT visit_id FROM Events WHERE event_type = 3) THEN 1 END) AS abandoned_count,  -- Abandoned cart (event_type = 2 but no subsequent purchase)
    COUNT(CASE WHEN Events.event_type = 3 THEN 1 END) AS purchase_count    -- Count of purchases (event_type = 3)
FROM
    Users
JOIN
    Events ON Users.cookie_id = Events.cookie_id
JOIN
    Page_Hierarchy ON Events.page_id = Page_Hierarchy.page_id
WHERE
    Events.page_id BETWEEN 3 AND 11 -- Assuming product pages have ids in this range
GROUP BY
    Page_Hierarchy.product_id;

Product - Category Level Analysis Table:

CREATE TABLE Product_Category_Funnel_Analysis AS
SELECT
    Page_Hierarchy.product_category,
    COUNT(CASE WHEN Events.event_type = 1 THEN 1 END) AS views_count,    -- Count of views (event_type = 1)
    COUNT(CASE WHEN Events.event_type = 2 THEN 1 END) AS add_to_cart_count,  -- Count of cart adds (event_type = 2)
    COUNT(CASE WHEN Events.event_type = 2 AND Events.visit_id NOT IN (SELECT visit_id FROM Events WHERE event_type = 3) THEN 1 END) AS abandoned_count,  -- Abandoned cart (event_type = 2 but no subsequent purchase)
    COUNT(CASE WHEN Events.event_type = 3 THEN 1 END) AS purchase_count    -- Count of purchases (event_type = 3)
FROM
    Users
JOIN
    Events ON Users.cookie_id = Events.cookie_id
JOIN
    Page_Hierarchy ON Events.page_id = Page_Hierarchy.page_id
WHERE
    Events.page_id BETWEEN 3 AND 11 -- Assuming product pages have ids in this range
GROUP BY
    Page_Hierarchy.product_category;

-- 1. Which product had the most views, cart adds, and purchases?
-- Most viewed product
SELECT product_id, views_count
FROM Product_Funnel_Analysis
ORDER BY views_count DESC
LIMIT 1;

-- Most added to cart product
SELECT product_id, add_to_cart_count
FROM Product_Funnel_Analysis
ORDER BY add_to_cart_count DESC
LIMIT 1;

-- Most purchased product
SELECT product_id, purchase_count
FROM Product_Funnel_Analysis
ORDER BY purchase_count DESC
LIMIT 1;

-- 2. Which product was most likely to be abandoned?
SELECT
    product_id,
    abandoned_count,
    add_to_cart_count,
    (abandoned_count * 100.0 / add_to_cart_count) AS abandonment_rate
FROM
    Product_Funnel_Analysis
ORDER BY abandonment_rate DESC
LIMIT 1;

-- 3. Which product had the highest view to purchase percentage?
SELECT
    product_id,
    (purchase_count * 100.0 / views_count) AS view_to_purchase_percentage
FROM
    Product_Funnel_Analysis
ORDER BY view_to_purchase_percentage DESC
LIMIT 1;

-- 4. What is the average conversion rate from view to cart add?
SELECT
    AVG(add_to_cart_count * 1.0 / views_count) AS avg_view_to_cart_conversion_rate
FROM
    Product_Funnel_Analysis;

-- 5. What is the average conversion rate from cart add to purchase?
SELECT
    AVG(purchase_count * 1.0 / add_to_cart_count) AS avg_cart_to_purchase_conversion_rate
FROM