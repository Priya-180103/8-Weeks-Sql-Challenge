/* --------------------
   Case Study Questions
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?

select sales.customer_id, sum(menu.price) as total_amount
from menu
join sales on sales.product_id = menu.product_id
group by sales.customer_id
order by sales.customer_id

-- 2. How many days has each customer visited the restaurant?

select customer_id, count(distinct order_date) as visited_days
from sales
group by customer_id

-- 3. What was the first item from the menu purchased by each customer?

 with first_order_by_each_customer as (
	select customer_id, product_id,
    ROW_NUMBER() over (
      partition by customer_id
      order by order_date
    ) as row
	from sales
	order by order_date 
)
select first_order_by_each_customer.customer_id, menu.product_name
from first_order_by_each_customer
join menu on menu.product_id = first_order_by_each_customer.product_id
where row = 1

 -- First Date each customer ordered the food/Visited the hotel
 select customer_id, min(order_date) 
 from sales
 group by customer_id
 order by customer_id
 
 
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

-- How many times each item was ordered?
select menu.product_name, count(sales.product_id) as ordered_times
from sales
join menu on menu.product_id = sales.product_id
group by menu.product_name
order by ordered_times desc


-- What is the most purchased item - Method 1
select menu.product_name, count(*) as purchased_count
from menu
join sales on sales.product_id = menu.product_id
group by menu.product_name
order by purchased_count desc
limit 1

-- What is the most purchased item - Method 2
select menu.product_name
from menu
join sales on sales.product_id = menu.product_id 
group by menu.product_name
order by count(*) desc
limit 1

-- 4.b What is the most purchased item on the menu and how many times was it purchased by each customer?

select sales.customer_id, menu.product_name, count(sales.product_id) as purchased_count
from menu
join sales on sales.product_id = menu.product_id
where menu.product_name = (select menu.product_name
                           from menu
                           join sales on sales.product_id = 									menu.product_id 
                           group by menu.product_name
                           order by count(*) desc
                           limit 1)
group by menu.product_name, sales.customer_id
order by sales.customer_id

-- 5. Which item was the most popular for each customer?

-- Using ROW_NUMBER()
with most_popular_item_per_customer as(
  select customer_id, product_id, count(product_id) as 		      ordered_times, 
  ROW_NUMBER() over (partition by customer_id order by count(product_id) desc) as row
  from sales
  group by customer_id, product_id
  order by customer_id
)
select customer_id, menu.product_name
from most_popular_item_per_customer
join menu on menu.product_id = most_popular_item_per_customer.product_id
where row = 1
order by customer_id

--Using RANK() and STRING_AGG() [comma separation in case of tie ]
with most_popular_item_per_customer as(
  select customer_id, product_id, count(product_id) as 		      ordered_times, 
  RANK() over (partition by customer_id order by count(product_id) desc) as rank
  from sales
  group by customer_id, product_id
  order by customer_id
)
select customer_id, 
		  STRING_AGG(menu.product_name, ',') as most_popular_items
from most_popular_item_per_customer
join menu on menu.product_id = most_popular_item_per_customer.product_id
where rank = 1
group by customer_id
order by customer_id

-- 6. Which item was purchased first by the customer after they became a member?

with first_item_purchased_by_each_customer as (
	select sales.customer_id, menu.product_name,
		ROW_NUMBER() over (
			partition by sales.customer_id
			order by sales.order_date
		) as row_number
	from menu
	join sales on sales.product_id = menu.product_id
	join members on members.customer_id = sales.customer_id
	where sales.order_date >= members.join_date
)
select customer_id, product_name
from first_item_purchased_by_each_customer
where row_number = 1


with first_order_date_after_membership as (
	select 
  		sales.customer_id , 
  		sales.order_date,
  		ROW_NUMBER() over (
         	partition by sales.customer_id
          	order by sales.order_date
        ) as row_number
	from sales
	join members on sales.customer_id = members.customer_id
	where sales.order_date >= members.join_date
)
select customer_id, order_date
from first_order_date_after_membership 
where row_number = 1

-- 7. Which item was purchased just before the customer became a member?
with last_item_purchased_as_a_non_member as (
	select 
  		sales.customer_id, 
  		menu.product_name,
        sales.order_date,
  		RANK() over(
        	partition by sales.customer_id
          	order by sales.order_date desc
        ) as rank
  	from sales
  	join menu on menu.product_id = sales.product_id
  	join members on members.customer_id = sales.customer_id
    where sales.order_date < members.join_date 	
)
select customer_id, 
	   STRING_AGG(product_name, ',') as product_name  
from last_item_purchased_as_a_non_member
where rank = 1
group by customer_id

-- 8. What is the total items and amount spent for each member before they became a member?

select sales.customer_id, count(sales.product_id) as total_items,
sum(menu.price) as amount_spent
from sales
join menu on menu.product_id = sales.product_id
join members on members.customer_id = sales.customer_id
where sales.order_date < members.join_date
group by sales.customer_id
order by sales.customer_id

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

with points_per_order as (
	select sales.customer_id, sales.product_id,
    case
  		when sales.product_id = 1 then (menu.price * 10 * 2)
  		when sales.product_id = 2 then (menu.price * 10)
  		when sales.product_id = 3 then (menu.price * 10)
    end as points
    from sales
    join menu on menu.product_id = sales.product_id
)
select customer_id, sum(points)
from points_per_order
group by customer_id
order by customer_id

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

with points_per_order_after_membership as(
	select sales.customer_id, sales.product_id,
    case
        when sales.order_date Between members.join_date and members.join_date + interval '6 days' then menu.price * 10 * 2
  	 	when sales.product_id = 1 then menu.price * 10 * 2
  		else menu.price * 10
    end as points
    from sales
    join menu on menu.product_id = sales.product_id
    join members on members.customer_id = sales.customer_id
    where sales.order_date <= '2021-01-31'
    order by sales.customer_id, sales.order_date
)
select customer_id, sum(points) as total_points_as_per_jan
from points_per_order_after_membership
group by customer_id
order by customer_id


-- JOIN ALL THE THINGS
select sales.customer_id, 
	   sales.order_date, 
       menu.product_name,
       menu.price,
	   case
       		when members.customer_id is not null and members.join_date <= sales.order_date then 'Y'
            else 'N'
       end as is_member
from sales
join menu on sales.product_id = menu.product_id
left join members on sales.customer_id = members.customer_id
order by sales.customer_id, sales.order_date, menu.product_name;


-- RANK ALL THE THINGS
WITH member_orders_only AS (
  SELECT 
    sales.customer_id,
    sales.order_date,
    menu.product_name,
    RANK() OVER (
      PARTITION BY sales.customer_id
      ORDER BY sales.order_date, menu.product_name
    ) AS rank_after_membership
  FROM sales
  JOIN menu ON sales.product_id = menu.product_id
  JOIN members ON sales.customer_id = members.customer_id
  WHERE sales.order_date >= members.join_date
)

SELECT 
  s.customer_id,
  s.order_date,
  m.product_name,
  m.price,
  CASE 
    WHEN mem.customer_id IS NOT NULL AND s.order_date >= mem.join_date THEN 'Y'
    ELSE 'N'
  END AS is_member,
  mo.rank_after_membership AS ranking
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mem ON s.customer_id = mem.customer_id
LEFT JOIN member_orders_only mo 
  ON s.customer_id = mo.customer_id 
 AND s.order_date = mo.order_date 
 AND m.product_name = mo.product_name
ORDER BY s.customer_id, s.order_date, m.product_name;