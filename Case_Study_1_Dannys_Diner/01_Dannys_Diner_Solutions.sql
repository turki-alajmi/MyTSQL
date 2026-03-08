/* ---------------------------------------------------------------------------
-- Case Study #1: Danny's Diner
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
--Q01 What is the total amount each customer spent at the restaurant?
------------------------------------------------------------------------

SELECT
    customer_id,
    SUM(price) AS totalspent
FROM sales
INNER JOIN menu
    ON menu.product_id = sales.product_id
GROUP BY
    customer_id;

------------------------------------------------------------------------
--Q02 How many days has each customer visited the restaurant?
------------------------------------------------------------------------

SELECT
    customer_id,
    COUNT(DISTINCT order_date) AS visit_amount
FROM sales
GROUP BY
    customer_id;

------------------------------------------------------------------------
--Q03 What was the first item from the menu purchased by each customer?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        customer_id,
        product_name,
        DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS first_product
    FROM sales
    INNER JOIN menu
        ON sales.product_id = menu.product_id
)
SELECT DISTINCT
    customer_id,
    product_name
FROM cte
WHERE first_product = 1;


------------------------------------------------------------------------
--Q04 What is the most purchased item on the menu and how many times
--    was it purchased by all customers?
------------------------------------------------------------------------

SELECT -- TOP 1 (alternative approach, works on SQL Server 2012+)
    product_name,
    COUNT(sales.product_id) AS purchase_count
FROM sales
INNER JOIN menu
    ON sales.product_id = menu.product_id
GROUP BY
    product_name
ORDER BY
    purchase_count DESC
OFFSET 0 ROWS FETCH NEXT 1 ROW ONLY;

------------------------------------------------------------------------
--Q05 Which item was the most popular for each customer?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        customer_id,
        product_name,
        COUNT(product_name) AS product_count,
        RANK() OVER (
            PARTITION BY customer_id
            ORDER BY COUNT(product_name) DESC
            ) AS rnk
    FROM sales
    INNER JOIN menu
        ON sales.product_id = menu.product_id
    GROUP BY
        customer_id,
        product_name
)

SELECT
    customer_id,
    product_name,
    product_count
FROM cte
WHERE rnk = 1
ORDER BY
    customer_id ASC;

------------------------------------------------------------------------
--Q06 Which item was purchased first by the customer after they became
--    a member?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        s.customer_id AS customer,
        join_date,
        order_date,
        product_name,
        RANK() OVER (
            PARTITION BY s.customer_id
            ORDER BY s.order_date ASC
            ) AS order_rank
    FROM sales AS s
    INNER JOIN members
        ON s.customer_id = members.customer_id
        AND s.order_date >= members.join_date
    INNER JOIN menu
        ON menu.product_id = s.product_id
)

SELECT
    customer,
    product_name
FROM cte
WHERE order_rank = 1;

------------------------------------------------------------------------
--Q07 Which item was purchased just before the customer became a member?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        s.customer_id AS customer,
        join_date,
        order_date,
        product_name AS product,
        RANK() OVER (
            PARTITION BY s.customer_id
            ORDER BY order_date DESC
            ) AS last_purchase
    FROM sales AS s
    INNER JOIN members
        ON s.customer_id = members.customer_id
        AND s.order_date < members.join_date
    INNER JOIN menu
        ON menu.product_id = s.product_id
)

SELECT
    customer,
    product
FROM cte
WHERE last_purchase = 1;

------------------------------------------------------------------------
--Q08 What is the total items and amount spent for each member before
--    they became a member?
------------------------------------------------------------------------

SELECT
    s.customer_id,
    COUNT(s.product_id) AS total_count,
    SUM(price) AS total_spent


FROM sales AS s
INNER JOIN members AS mem
    ON s.customer_id = mem.customer_id
    AND s.order_date < mem.join_date
INNER JOIN menu AS m
    ON m.product_id = s.product_id
GROUP BY
    s.customer_id;

------------------------------------------------------------------------
--Q09 If each $1 spent equates to 10 points and sushi has a 2x points
--    multiplier - how many points would each customer have?
------------------------------------------------------------------------

SELECT
    customer_id,
    SUM(CASE
            WHEN product_name = 'sushi'
                THEN (2 * (price * 10))
            ELSE (price * 10)
        END) AS points
FROM sales
INNER JOIN menu
    ON menu.product_id = sales.product_id
GROUP BY
    customer_id;

------------------------------------------------------------------------
--Q10 In the first week after a customer joins the program (including
--    their join date) they earn 2x points on all items, not just sushi
--    - how many points do customer A and B have at the end of January?
------------------------------------------------------------------------

SELECT
    sales.customer_id,
    SUM(CASE
            WHEN order_date BETWEEN join_date AND DATEADD(DAY, 6, join_date)
                THEN (2 * (price * 10))
            WHEN product_name = 'sushi'
                THEN (2 * (price * 10))
            ELSE (price * 10)
        END) AS members_points
FROM sales
INNER JOIN menu
    ON menu.product_id = sales.product_id
INNER JOIN members
    ON members.customer_id = sales.customer_id
WHERE order_date < '20210201'
GROUP BY
    sales.customer_id;


