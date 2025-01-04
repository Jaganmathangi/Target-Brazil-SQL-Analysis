-- Target Brazil SQL Analysis
-- Author: Jagan Mohan Mathangi
-- Date: 04 January 2025
-- Description: This SQL file contains queries for the analysis of Target's operations in Brazil.

-- ========================================================
-- 1. Initial Exploration: Structure & Characteristics
-- ========================================================

-- 1.1 Retrieve column names and data types from the 'customers' table
SELECT
  column_name,
  data_type
FROM
  `target.INFORMATION_SCHEMA.COLUMNS`
WHERE
  table_name = 'customers';

-- 1.2 Retrieve the first and last order dates from the 'orders' table
SELECT
  MIN(order_purchase_timestamp) AS first_order_date,
  MAX(order_purchase_timestamp) AS last_order_date
FROM
  `target.orders`;

-- 1.3 Count the unique states and cities of customers who placed orders
SELECT
  COUNT(DISTINCT customer_state) AS unique_state_count,
  COUNT(DISTINCT customer_city) AS unique_city_count
FROM
  `target.customers`;

-- ========================================================
-- 2. In-Depth Exploration
-- ========================================================

-- 2.1 Analyze the yearly trend in the number of orders placed
SELECT
  EXTRACT(YEAR FROM order_purchase_timestamp) AS year,
  COUNT(order_id) AS no_of_orders
FROM
  `target.orders`
GROUP BY
  year
ORDER BY
  year;

-- 2.2 Analyze monthly seasonality in terms of the number of orders placed
WITH monthly_seasonality AS (
  SELECT
    EXTRACT(MONTH FROM order_purchase_timestamp) AS num_month,
    FORMAT_TIMESTAMP('%B', order_purchase_timestamp) AS month,
    COUNT(order_id) AS no_of_orders
  FROM
    `target.orders`
  GROUP BY
    num_month, month
  ORDER BY
    num_month
)
SELECT
  month,
  no_of_orders
FROM
  monthly_seasonality;

-- 2.3 Determine the time of day when Brazilian customers mostly place their orders
SELECT
    CASE
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) >= 0 AND EXTRACT(HOUR FROM order_purchase_timestamp) <= 6 THEN 'Dawn'
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) >= 7 AND EXTRACT(HOUR FROM order_purchase_timestamp) <= 12 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) >= 13 AND EXTRACT(HOUR FROM order_purchase_timestamp) <= 18 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM order_purchase_timestamp) >= 19 AND EXTRACT(HOUR FROM order_purchase_timestamp) <= 23 THEN 'Night'
    END AS time_of_the_day,
    COUNT(*) AS no_of_orders
FROM
    `target.orders`
GROUP BY
    time_of_the_day
ORDER BY
    FIELD(time_of_the_day, 'Dawn', 'Morning', 'Afternoon', 'Night');

-- ========================================================
-- 3. Evolution of E-commerce Orders
-- ========================================================

-- 3.1 Retrieve month-on-month number of orders placed in each state
SELECT
  C.customer_state AS state,
  EXTRACT(MONTH FROM O.order_purchase_timestamp) AS month,
  COUNT(DISTINCT O.order_id) AS total_orders
FROM
  `target.customers` AS C
INNER JOIN
  `target.orders` AS O
ON
  C.customer_id = O.customer_id
GROUP BY
  C.customer_state, month
ORDER BY
  C.customer_state, month;

-- 3.2 Analyze the distribution of customers across all states
SELECT
  customer_state AS state,
  COUNT(customer_id) AS total_customers
FROM
  `target.customers`
GROUP BY
  customer_state
ORDER BY
  total_customers DESC;

-- ========================================================
-- 4. Economic Impact Analysis
-- ========================================================

-- 4.1 Percentage increase in cost of orders (2017 vs. 2018, Jan-Aug)
WITH yearly_costs AS (
  SELECT
    EXTRACT(YEAR FROM O.order_purchase_timestamp) AS year,
    ROUND(SUM(payment_value), 2) AS total_cost
  FROM
    `target.payments` AS P
  INNER JOIN
    `target.orders` AS O
  ON
    P.order_id = O.order_id
  WHERE
    EXTRACT(MONTH FROM order_purchase_timestamp) BETWEEN 1 AND 8
  GROUP BY
    year
  HAVING
    year IN (2017, 2018)
)
SELECT
  MAX(CASE WHEN year = 2017 THEN total_cost END) AS total_cost_2017,
  MAX(CASE WHEN year = 2018 THEN total_cost END) AS total_cost_2018,
  ROUND((MAX(CASE WHEN year = 2018 THEN total_cost END) / 
         MAX(CASE WHEN year = 2017 THEN total_cost END) - 1) * 100, 2) AS percentage_change
FROM
  yearly_costs;

-- 4.2 Calculate the Total & Average value of order price for each state
SELECT
  customer_state AS state,
  ROUND(SUM(price), 2) AS total,
  ROUND(SUM(price) / COUNT(DISTINCT OI.order_id), 2) AS average_order_price
FROM
  `target.customers` AS C
INNER JOIN
  `target.orders` AS O ON C.customer_id = O.customer_id
INNER JOIN
  `target.order_items` AS OI ON OI.order_id = O.order_id
GROUP BY
  customer_state
ORDER BY
  customer_state;

-- 4.3 Calculate the Total & Average value of order freight for each state
SELECT
  customer_state AS state,
  ROUND(SUM(freight_value), 2) AS total_freight_value,
  ROUND(SUM(freight_value) / COUNT(DISTINCT OI.order_id), 2) AS average_freight_value
FROM
  `target.customers` AS C
INNER JOIN
  `target.orders` AS O ON C.customer_id = O.customer_id
INNER JOIN
  `target.order_items` AS OI ON OI.order_id = O.order_id
GROUP BY
  customer_state
ORDER BY
  customer_state;

-- ========================================================
-- 5. Delivery Time Analysis
-- ========================================================

-- Calculate delivery time and the difference between estimated and actual delivery dates
SELECT
  order_id,
  DATE_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY) AS time_to_deliver,
  DATE_DIFF(order_delivered_customer_date, order_estimated_delivery_date, DAY) AS diff_estimated_delivery
FROM
  `target.orders`
WHERE
  order_delivered_customer_date IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;

-- 5.2.1 Find the top 5 states with the highest average freight value
SELECT
  customer_state AS state,
  ROUND(AVG(freight_value), 2) AS avg_freight_value,
  DENSE_RANK() OVER (ORDER BY AVG(freight_value) DESC) AS top_rank
FROM
  `target.order_items` AS OI
INNER JOIN
  `target.orders` AS O ON OI.order_id = O.order_id
INNER JOIN
  `target.customers` AS C ON C.customer_id = O.customer_id
GROUP BY
  customer_state
QUALIFY
  top_rank <= 5
ORDER BY
  top_rank;

-- 5.2.2 Retrieve the top 5 states with the lowest average freight value
SELECT
  customer_state AS state,
  ROUND(AVG(freight_value), 2) AS avg_freight_value,
  DENSE_RANK() OVER (ORDER BY AVG(freight_value)) AS bottom_rank
FROM
  `target.order_items` AS OI
INNER JOIN
  `target.orders` AS O ON OI.order_id = O.order_id
INNER JOIN
  `target.customers` AS C ON C.customer_id = O.customer_id
GROUP BY
  customer_state
QUALIFY
  bottom_rank <= 5
ORDER BY
  bottom_rank;

-- 5.3.1 Find the top 5 states with the lowest average delivery time
SELECT
  customer_state AS state,
  ROUND(AVG(TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY)), 2) AS avg_days,
  RANK() OVER (ORDER BY AVG(TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY))) AS delivery_rank
FROM
  `target.orders` AS O
INNER JOIN
  `target.customers` AS C ON C.customer_id = O.customer_id
WHERE
  order_delivered_customer_date IS NOT NULL
GROUP BY
  customer_state
QUALIFY
  delivery_rank <= 5
ORDER BY
  avg_days;

-- 5.3.2 Find the top 5 states with the highest average delivery time
SELECT
  customer_state AS state,
  ROUND(AVG(TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY)), 2) AS avg_days,
  RANK() OVER (ORDER BY AVG(TIMESTAMP_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY)) DESC) AS delivery_rank
FROM
  `target.orders` AS O
INNER JOIN
  `target.customers` AS C ON C.customer_id = O.customer_id
WHERE
  order_delivered_customer_date IS NOT NULL
GROUP BY
  customer_state
QUALIFY
  delivery_rank <= 5
ORDER BY
  avg_days DESC;

-- 5.4 Find the top 5 states where the order delivery is faster than the estimated delivery date
SELECT
  customer_state AS state,
  ROUND(AVG(TIMESTAMP_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY)), 2) AS avg_days_early,
  RANK() OVER (ORDER BY AVG(TIMESTAMP_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY))) AS fast_delivery_rank
FROM
  `target.orders` AS O
INNER JOIN
  `target.customers` AS C ON C.customer_id = O.customer_id
WHERE
  order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY
  customer_state
QUALIFY
  fast_delivery_rank <= 5
ORDER BY
  avg_days_early DESC;

-- ========================================================
-- 6. Payments Analysis
-- ========================================================

-- 6.1 Analyze the month-on-month number of orders placed using different payment types
WITH CTE AS (
  SELECT
    payment_type,
    EXTRACT(MONTH FROM order_purchase_timestamp) AS month,
    COUNT(P.order_id) AS no_of_orders
  FROM
    `target.payments` AS P
  INNER JOIN
    `target.orders` AS O ON P.order_id = O.order_id
  GROUP BY
    payment_type, month
  ORDER BY
    payment_type, month
)
SELECT
  payment_type,
  month,
  no_of_orders,
  LAG(no_of_orders, 1) OVER (PARTITION BY payment_type ORDER BY month) AS previous_month_orders
FROM
  CTE;

-- 6.2 Analyze the number of orders based on payment installments
SELECT
	payment_installments AS installments_used,
    COUNT(DISTINCT order_id) AS num_orders
FROM
    `target.payments`
GROUP BY
    payment_installments
ORDER BY
    installments_used;

-- ========================================================
-- End of File
-- ========================================================