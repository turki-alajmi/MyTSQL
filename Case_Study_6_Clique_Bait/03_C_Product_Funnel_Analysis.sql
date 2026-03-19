/* ---------------------------------------------------------------------------
-- Case Study #6: Clique Bait
-- Section C: Product Funnel Analysis
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
-- 1. PRODUCT LEVEL FUNNEL TABLE
-- Using a single SQL query - create a new output table which has the
-- following details:
--   a. How many times was each product viewed?
--   b. How many times was each product added to cart?
--   c. How many times was each product added to a cart but not purchased (abandoned)?
--   d. How many times was each product purchased?
--------------------------------------------------------------------------- */

WITH main_data AS (
    -- Pull everything together
    -- Kept unfiltered so purchase events on the Confirmation page
    -- are visible to the EXISTS check in purchased_cte.
    SELECT
        visit_id,
        sequence_number,
        page_name,
        event_name,
        event_time,
        e.event_type,
        h.product_id,
        product_category
    FROM clique_bait.events AS e
    INNER JOIN clique_bait.page_hierarchy AS h
        ON h.page_id = e.page_id
    INNER JOIN clique_bait.event_identifier AS i
        ON i.event_type = e.event_type
),
    purchased_cte AS (
        -- counts products as purchased if it was added to cart
        -- AND the visit it belongs to ended with a purchase event.
        SELECT
            a.visit_id,
            a.page_name
        FROM main_data AS a
        WHERE event_type = 2
          AND EXISTS (
            SELECT
                b.visit_id
            FROM main_data AS b
            WHERE a.visit_id = b.visit_id
              AND b.event_type = 3
        )
    ),
    product_funnel AS (
        -- Funnel metrics per product.
        -- Abandoned is derived: cart adds minus purchases.
        SELECT
            md.page_name,
            product_category,
            COUNT(DISTINCT CASE WHEN event_type = 1 THEN md.visit_id END) AS product_views,
            COUNT(DISTINCT CASE WHEN event_type = 2 THEN md.visit_id END) AS added_to_cart,
            COUNT(DISTINCT
                  CASE WHEN event_type = 2 AND pr.page_name IS NOT NULL THEN md.visit_id END) AS purchased_product
        FROM main_data AS md
        LEFT JOIN purchased_cte AS pr
            ON md.visit_id = pr.visit_id
            AND md.page_name = pr.page_name
        -- Only keep actual product pages, not navigation pages like Home or Checkout
        WHERE product_id IS NOT NULL
        GROUP BY
            product_category,
            md.page_name
    )

SELECT
    product_category,
    page_name,
    product_views,
    added_to_cart,
    purchased_product,
    added_to_cart - purchased_product AS abandoned_count
INTO clique_bait.product_funnel
FROM product_funnel;

/* ---------------------------------------------------------------------------
-- 2. CATEGORY LEVEL FUNNEL TABLE
-- Additionally, create another table which further aggregates the data
-- for the above points but this time for each product category instead of
-- individual products.
--------------------------------------------------------------------------- */

SELECT
    product_category,
    SUM(product_views) AS category_views,
    SUM(added_to_cart) AS carted_category_products,
    SUM(purchased_product) AS purchased_category_products,
    SUM(abandoned_count) AS abandoned_category_products
INTO clique_bait.category_funnel
-- product_funnel is the table i just created in the earlier question
FROM clique_bait.product_funnel
GROUP BY
    product_category;

/* ---------------------------------------------------------------------------
-- 3. FUNNEL METRICS & CONVERSION RATES
-- Use your 2 new output tables to answer the following questions:
--------------------------------------------------------------------------- */

-- Q1: Which product had the most views, cart adds and purchases?

WITH ranks AS (
    SELECT *,
        RANK() OVER (ORDER BY product_views DESC) AS view_rnk,
        RANK() OVER (ORDER BY added_to_cart DESC) AS carting_rnk,
        RANK() OVER (ORDER BY purchased_product DESC) AS purchase_rnk
    FROM clique_bait.product_funnel
)

SELECT
    'Most Viewed' AS metric,
    page_name,
    product_views
FROM ranks
WHERE view_rnk = 1

UNION ALL

SELECT
    'Most Carted',
    page_name,
    added_to_cart
FROM ranks
WHERE carting_rnk = 1

UNION ALL

SELECT
    'Most Purchased',
    page_name,
    purchased_product
FROM ranks
WHERE purchase_rnk = 1;

-- Q2: Which product was most likely to be abandoned?

SELECT TOP 1
    page_name,
    CAST((abandoned_count * 100.0) / added_to_cart AS DECIMAL(5, 2)) AS abandonment_rate
FROM clique_bait.product_funnel
ORDER BY
    abandonment_rate DESC;

-- Q3: Which product had the highest view to purchase percentage?

SELECT TOP 1
    page_name,
    CAST((purchased_product * 100.0) / product_views AS DECIMAL(5, 2)) view_to_purchase_percentage
FROM clique_bait.product_funnel
ORDER BY
    view_to_purchase_percentage DESC;


-- Q4: What is the average conversion rate from view to cart add?

SELECT
    CAST(AVG((added_to_cart * 100.0) / product_views) AS DECIMAL(5, 2)) view_to_cart_rate
FROM clique_bait.product_funnel;

-- Q5: What is the average conversion rate from cart add to purchase?

SELECT
    CAST(AVG((purchased_product * 100.0) / added_to_cart) AS DECIMAL(5, 2)) cart_to_purchase_rate
FROM clique_bait.product_funnel;