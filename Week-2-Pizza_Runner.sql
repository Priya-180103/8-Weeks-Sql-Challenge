-- Handling NULL values in customer_orders table:
SELECT 
    order_id,
    customer_id,
    pizza_id,
    COALESCE(exclusions, '') AS exclusions,  -- Replace NULL exclusions with an empty string
    COALESCE(extras, '') AS extras,          -- Replace NULL extras with an empty string
    order_time
FROM pizza_runner.customer_orders;

-- Handling NULL values in runner_orders table:
SELECT 
    order_id,
    runner_id,
    COALESCE(pickup_time, 'Unknown') AS pickup_time,  -- Replace NULL with 'Unknown'
    COALESCE(distance, '0') AS distance,              -- Replace NULL distance with '0'
    COALESCE(duration, '0') AS duration,              -- Replace NULL duration with '0'
    COALESCE(cancellation, 'No Cancellation') AS cancellation -- Replace NULL with 'No Cancellation'
FROM pizza_runner.runner_orders;


-- 1. How many pizzas were ordered?
SELECT COUNT(*) AS pizzas_ordered
FROM pizza_runner.customer_orders;


-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_customer_orders
FROM pizza_runner.customer_orders;

-- Which customer made how many distinct orders:
SELECT customer_id, COUNT(DISTINCT order_id) AS total_orders
FROM pizza_runner.customer_orders
GROUP BY customer_id;

-- 3. How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(*) AS successful_orders
FROM pizza_runner.runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id
ORDER BY runner_id;

-- 4. How many of each type of pizza was delivered?
SELECT customer_orders.pizza_id, COUNT(*) AS pizzas_delivered
FROM pizza_runner.customer_orders
JOIN pizza_runner.runner_orders 
  ON customer_orders.order_id = runner_orders.order_id
WHERE runner_orders.cancellation IS NULL
GROUP BY customer_orders.pizza_id
ORDER BY customer_orders.pizza_id;

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT 
    customer_id,
    pn.pizza_name,
    COUNT(*) AS total_pizzas
FROM customer_orders co
JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
GROUP BY customer_id, pn.pizza_name
ORDER BY customer_id, pn.pizza_name;


-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT MAX(pizza_count) AS max_pizzas_in_single_order
FROM (
    SELECT co.order_id, COUNT(*) AS pizza_count
    FROM customer_orders co
    JOIN runner_orders ro ON co.order_id = ro.order_id
    WHERE ro.cancellation IS NULL
    GROUP BY co.order_id
) sub;

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT
  co.customer_id,
  SUM(
    CASE 
      WHEN (co.exclusions IS NOT NULL AND co.exclusions != '') 
        OR (co.extras IS NOT NULL AND co.extras != '') 
      THEN 1 
      ELSE 0 
    END
  ) AS pizzas_with_changes,
  SUM(
    CASE 
      WHEN (co.exclusions IS NULL OR co.exclusions = '') 
        AND (co.extras IS NULL OR co.extras = '') 
      THEN 1 
      ELSE 0 
    END
  ) AS pizzas_without_changes
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.customer_id
ORDER BY co.customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT COUNT(*) AS pizzas_with_both_exclusions_and_extras
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
  AND co.exclusions IS NOT NULL AND co.exclusions != ''
  AND co.extras IS NOT NULL AND co.extras != '';

-- 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT 
  EXTRACT(HOUR FROM co.order_time) AS order_hour,
  COUNT(*) AS total_pizzas_ordered
FROM customer_orders co
GROUP BY order_hour
ORDER BY order_hour;

-- 10. What was the volume of orders for each day of the week?
SELECT 
  TO_CHAR(co.order_time, 'Day') AS day_of_week,
  COUNT(*) AS total_orders
FROM customer_orders co
GROUP BY day_of_week
ORDER BY CASE
           WHEN day_of_week = 'Monday' THEN 1
           WHEN day_of_week = 'Tuesday' THEN 2
           WHEN day_of_week = 'Wednesday' THEN 3
           WHEN day_of_week = 'Thursday' THEN 4
           WHEN day_of_week = 'Friday' THEN 5
           WHEN day_of_week = 'Saturday' THEN 6
           WHEN day_of_week = 'Sunday' THEN 7
         END;


B. Runner and Customer Experience
-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT 
  DATE_TRUNC('week', r.registration_date) AS week_start_date,
  COUNT(r.runner_id) AS runners_signed_up
FROM runners r
GROUP BY week_start_date
ORDER BY week_start_date;

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT 
  runner_id,
  AVG(EXTRACT(EPOCH FROM (pickup_time - order_time)) / 60) AS avg_pickup_time_minutes
FROM runner_orders ro
JOIN customer_orders co ON ro.order_id = co.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY runner_id
ORDER BY runner_id;

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
SELECT
  co.order_id,
  COUNT(co.pizza_id) AS num_pizzas,
  AVG(EXTRACT(EPOCH FROM (ro.pickup_time - co.order_time)) / 60) AS avg_preparation_time_minutes
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY co.order_id
ORDER BY num_pizzas DESC;

-- 4. What was the average distance travelled for each customer?
SELECT
  co.customer_id,
  AVG(CAST(REPLACE(ro.distance, 'km', '') AS DECIMAL)) AS avg_distance_km
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.distance IS NOT NULL
GROUP BY co.customer_id
ORDER BY avg_distance_km DESC;

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT 
  MAX(CAST(REPLACE(ro.duration, ' minutes', '') AS DECIMAL)) - 
  MIN(CAST(REPLACE(ro.duration, ' minutes', '') AS DECIMAL)) AS delivery_time_difference_minutes
FROM runner_orders ro
WHERE ro.duration IS NOT NULL;

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT 
  ro.runner_id,
  AVG(CAST(REPLACE(ro.distance, 'km', '') AS DECIMAL) / 
      CAST(REPLACE(ro.duration, ' minutes', '') AS DECIMAL)) AS avg_speed_km_per_min
FROM runner_orders ro
WHERE ro.distance IS NOT NULL 
  AND ro.duration IS NOT NULL
GROUP BY ro.runner_id
ORDER BY ro.runner_id;

-- 7. What is the successful delivery percentage for each runner?
SELECT 
  ro.runner_id,
  COUNT(CASE WHEN ro.cancellation IS NULL THEN 1 END) * 100.0 / COUNT(*) AS successful_delivery_percentage
FROM runner_orders ro
GROUP BY ro.runner_id
ORDER BY ro.runner_id;

C. Ingredient Optimisation
-- 1. What are the standard ingredients for each pizza?
SELECT 
  pr.pizza_id,
  pt.topping_name
FROM pizza_recipes pr
JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, pr.toppings) > 0
ORDER BY pr.pizza_id, pt.topping_name;

-- 2. What was the most commonly added extra?
SELECT 
  pt.topping_name,
  COUNT(*) AS extra_count
FROM customer_orders co
JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, co.extras) > 0
WHERE co.extras IS NOT NULL AND co.extras != ''
GROUP BY pt.topping_name
ORDER BY extra_count DESC
LIMIT 1;

-- 3. What was the most common exclusion?
SELECT 
  pt.topping_name,
  COUNT(*) AS exclusion_count
FROM customer_orders co
JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, co.exclusions) > 0
WHERE co.exclusions IS NOT NULL AND co.exclusions != ''
GROUP BY pt.topping_name
ORDER BY exclusion_count DESC
LIMIT 1;

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
-- Meat Lovers
-- Meat Lovers - Exclude Beef
-- Meat Lovers - Extra Bacon
-- Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
SELECT
  CASE
    WHEN co.exclusions IS NULL AND co.extras IS NULL THEN pn.pizza_name
    WHEN co.exclusions IS NOT NULL AND co.extras IS NULL THEN CONCAT(pn.pizza_name, ' - Exclude ', 
      GROUP_CONCAT(pt_exclusion.topping_name ORDER BY pt_exclusion.topping_name SEPARATOR ', '))
    WHEN co.exclusions IS NULL AND co.extras IS NOT NULL THEN CONCAT(pn.pizza_name, ' - Extra ', 
      GROUP_CONCAT(pt_extra.topping_name ORDER BY pt_extra.topping_name SEPARATOR ', '))
    ELSE CONCAT(pn.pizza_name, ' - Exclude ', 
      GROUP_CONCAT(pt_exclusion.topping_name ORDER BY pt_exclusion.topping_name SEPARATOR ', '), ' - Extra ', 
      GROUP_CONCAT(pt_extra.topping_name ORDER BY pt_extra.topping_name SEPARATOR ', '))
  END AS order_item
FROM customer_orders co
JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
LEFT JOIN pizza_toppings pt_exclusion ON FIND_IN_SET(pt_exclusion.topping_id, co.exclusions) > 0
LEFT JOIN pizza_toppings pt_extra ON FIND_IN_SET(pt_extra.topping_id, co.extras) > 0
GROUP BY co.order_id, co.customer_id, co.pizza_id, co.exclusions, co.extras
ORDER BY co.order_id;

-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
-- For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
SELECT
  pn.pizza_name,
  CONCAT(
    pn.pizza_name, ': ',
    GROUP_CONCAT(
      CASE 
        WHEN FIND_IN_SET(pt.topping_id, co.exclusions) > 0 THEN NULL  -- Exclusions are ignored
        WHEN FIND_IN_SET(pt.topping_id, co.extras) > 0 THEN CONCAT('2x', pt.topping_name)  -- Add "2x" for extras
        ELSE pt.topping_name  -- For regular ingredients
      END
      ORDER BY pt.topping_name SEPARATOR ', '
    )
  ) AS pizza_ingredients
FROM customer_orders co
JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, (SELECT toppings FROM pizza_recipes WHERE pizza_id = co.pizza_id)) > 0
GROUP BY co.order_id, co.customer_id, co.pizza_id
ORDER BY co.order_id;

-- 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
SELECT 
  pt.topping_name,
  COUNT(*) AS total_quantity
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
JOIN pizza_toppings pt ON FIND_IN_SET(pt.topping_id, (SELECT toppings FROM pizza_recipes WHERE pizza_id = co.pizza_id)) > 0
WHERE ro.cancellation IS NULL
  AND (co.exclusions IS NULL OR co.exclusions = '')  -- Exclude orders with exclusions
GROUP BY pt.topping_name
ORDER BY total_quantity DESC;

D. Pricing and Ratings
-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT 
  SUM(CASE 
        WHEN co.pizza_id = 1 THEN 12  -- Meat Lovers costs $12
        WHEN co.pizza_id = 2 THEN 10  -- Vegetarian costs $10
        ELSE 0 
      END) AS total_revenue
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL;

-- 2. What if there was an additional $1 charge for any pizza extras?
-- Add cheese is $1 extra
SELECT 
  SUM(CASE 
        WHEN co.pizza_id = 1 THEN 12  -- Meat Lovers costs $12
        WHEN co.pizza_id = 2 THEN 10  -- Vegetarian costs $10
        ELSE 0 
      END) +
  SUM(CASE
        WHEN (co.extras IS NOT NULL AND co.extras != '') THEN 1  -- Add $1 for extras
        ELSE 0
      END) AS total_revenue
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL;

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
CREATE TABLE runner_ratings (
    rating_id SERIAL PRIMARY KEY,
    order_id INT NOT NULL,
    runner_id INT NOT NULL,
    customer_id INT NOT NULL,
    rating INT CHECK (rating >= 1 AND rating <= 5),
    rating_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES customer_orders(order_id),
    FOREIGN KEY (runner_id) REFERENCES runners(runner_id),
    FOREIGN KEY (customer_id) REFERENCES customer_orders(customer_id)
);

-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- customer_id
-- order_id
-- runner_id
-- rating
-- order_time
-- pickup_time
-- Time between order and pickup
-- Delivery duration
-- Average speed
-- Total number of pizzas
SELECT 
    co.customer_id,
    co.order_id,
    ro.runner_id,
    rr.rating,
    co.order_time,
    ro.pickup_time,
    EXTRACT(EPOCH FROM (ro.pickup_time - co.order_time)) / 60 AS time_between_order_and_pickup_minutes,  -- Time difference in minutes
    ro.duration,
    CASE 
        WHEN ro.duration IS NOT NULL AND ro.distance IS NOT NULL THEN
            -- Calculate average speed: distance (in km) / time (in minutes)
            (CAST(SUBSTRING(ro.distance FROM '^\d+') AS DECIMAL) / 
            (EXTRACT(EPOCH FROM ro.duration) / 60))
        ELSE NULL
    END AS average_speed,  -- Average speed in km/min
    COUNT(DISTINCT co.pizza_id) AS total_pizzas
FROM 
    customer_orders co
JOIN 
    runner_orders ro ON co.order_id = ro.order_id
JOIN 
    runner_ratings rr ON co.order_id = rr.order_id AND co.customer_id = rr.customer_id
LEFT JOIN 
    pizza_recipes pr ON co.pizza_id = pr.pizza_id
WHERE 
    ro.cancellation IS NULL  -- Ensuring only successful deliveries
GROUP BY 
    co.customer_id, co.order_id, ro.runner_id, rr.rating, co.order_time, ro.pickup_time, ro.duration
ORDER BY 
    co.customer_id, co.order_id;

-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
WITH pizza_revenue AS (
  SELECT 
    co.pizza_id,
    COUNT(co.pizza_id) AS pizza_count,
    SUM(CASE WHEN co.pizza_id = 1 THEN 12 ELSE 10 END) AS total_revenue  -- $12 for Meat Lovers, $10 for Vegetarian
  FROM 
    customer_orders co
  JOIN 
    runner_orders ro ON co.order_id = ro.order_id
  WHERE 
    ro.cancellation IS NULL
  GROUP BY 
    co.pizza_id
),
runner_payment AS (
  SELECT 
    ro.runner_id,
    SUM(CAST(SUBSTRING(ro.distance FROM '^\d+') AS DECIMAL)) * 0.30 AS total_payment  -- $0.30 per km
  FROM 
    runner_orders ro
  WHERE 
    ro.cancellation IS NULL
  GROUP BY 
    ro.runner_id
)
SELECT
  (SELECT SUM(total_revenue) FROM pizza_revenue) - 
  (SELECT SUM(total_payment) FROM runner_payment) AS money_leftover;
