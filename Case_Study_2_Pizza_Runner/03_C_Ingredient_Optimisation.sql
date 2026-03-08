------------------------------------------------------------------------
-- Q01: What are the standard ingredients for each pizza?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        n.pizza_name,
        try_CAST(TRIM(value) AS INT) AS ingredient
    FROM pizza_recipes AS r
    CROSS APPLY STRING_SPLIT(toppings, ',')
    INNER JOIN pizza_names AS n
        ON n.pizza_id = r.pizza_id
)
SELECT
    pizza_name,
    topping_name
FROM cte
INNER JOIN pizza_toppings
    ON pizza_toppings.topping_id = ingredient;

------------------------------------------------------------------------
-- Q02: What was the most commonly added extra?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        c.order_id,
        c.extras,
        try_CAST(trim(value) AS INT) as ingredient
    FROM customer_orders_clean AS c
    INNER JOIN runner_orders_clean AS r
        ON r.order_id = c.order_id
    CROSS APPLY STRING_SPLIT(c.extras, ',')

    WHERE r.cancellation IS NULL
      AND c.extras IS NOT NULL

)
SELECT TOP 1 WITH TIES
    topping_name,
    count(topping_name) AS count_of_topping
from cte
INNER JOIN pizza_toppings
on pizza_toppings.topping_id = cte.ingredient
GROUP BY topping_name
ORDER BY count_of_topping DESC;

------------------------------------------------------------------------
-- Q03: What was the most common exclusion?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        c.order_id,
        c.exclusions,
        try_CAST(trim(value) AS INT) as ingredient

    FROM customer_orders_clean AS c
    INNER JOIN runner_orders_clean AS r
        ON r.order_id = c.order_id
    CROSS APPLY STRING_SPLIT(c.exclusions, ',')

    WHERE r.cancellation IS NULL
      AND c.exclusions IS NOT NULL

)
SELECT TOP 1 WITH TIES
    topping_name,
    count(topping_name) AS count_of_topping
from cte
INNER JOIN pizza_toppings
on pizza_toppings.topping_id = cte.ingredient
GROUP BY topping_name
ORDER BY count_of_topping DESC;

------------------------------------------------------------------------
-- Q04: Generate an order item for each record in the customers_orders
--      table in the format of one of the following:
--      Meat Lovers
--      Meat Lovers - Exclude Beef
--      Meat Lovers - Extra Bacon
--      Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
------------------------------------------------------------------------
-- Assigns a unique identifier for each pizza order to handle multi-pizza per order
WITH uni AS (
    SELECT
        c.order_id,
        c.customer_id,
        c.pizza_id,
        c.exclusions,
        c.extras,
        c.order_time,
        p.pizza_name,
        ROW_NUMBER() OVER (ORDER BY c.order_id) AS uni_key
    FROM customer_orders_clean AS c
    INNER JOIN pizza_names AS p
        ON p.pizza_id = c.pizza_id
),
-- Splits extras per order and aggregates into a comma-separated string
    extra_split AS (
        SELECT
            uni_key,
            STRING_AGG(t.topping_name, ', ') AS true_extras
        FROM uni AS c
        OUTER APPLY STRING_SPLIT(extras, ',')
        LEFT JOIN pizza_toppings AS t
            ON t.topping_id = TRY_CAST(trim(value) as INT)
        GROUP BY
            uni_key

    ),
-- Splits exclusions per order and aggregates into a comma-separated string
    exclusion_split AS (
        SELECT
            uni_key,
            STRING_AGG(t.topping_name, ', ') AS true_exclusion
        FROM uni AS c
        OUTER APPLY STRING_SPLIT(c.exclusions, ',')
        LEFT JOIN pizza_toppings AS t
            ON t.topping_id = TRY_CAST(trim(value) as INT)
        GROUP BY
            uni_key

    )
-- Applies CASE WHEN logic to format the final order string based on extras and exclusions
SELECT
    order_id,
    CASE
        WHEN true_extras IS NULL AND true_exclusion IS NULL
            THEN pizza_name
        WHEN true_extras IS NOT NULL AND true_exclusion IS NULL
            THEN CONCAT(pizza_name,' - Extra ',true_extras)
        WHEN true_extras IS  NULL AND true_exclusion IS NOT NULL
            THEN CONCAT(pizza_name,' - Exclude ',true_exclusion)
        Else CONCAT(pizza_name,' - Exclude ',true_exclusion,' - Extra ',true_extras)
    end AS receipt
FROM uni
INNER JOIN extra_split AS plus
    ON uni.uni_key = plus.uni_key
INNER JOIN exclusion_split AS minus
    ON uni.uni_key = minus.uni_key;



------------------------------------------------------------------------
-- Q05: Generate an alphabetically ordered comma separated ingredient
--      list for each pizza order from the customer_orders table and
--      add a 2x in front of any relevant ingredients.
------------------------------------------------------------------------

-- Assigns a unique identifier for each pizza order to handle multi-pizza per order
WITH surg_key AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY order_id) AS rownum,
        c.order_id,
        c.customer_id,
        c.pizza_id,
        n.pizza_name,
        c.exclusions,
        c.extras,
        order_time
    FROM customer_orders_clean AS c
    INNER JOIN pizza_names AS n
        ON c.pizza_id = n.pizza_id
),
-- Splits the 1 row full-ingredients and explode it vertically
    recipe_ing AS
        (
            SELECT
                pizza_id,
                t.topping_name
            FROM pizza_recipes
            CROSS APPLY STRING_SPLIT(toppings, ',')
            INNER JOIN pizza_toppings AS t
                ON t.topping_id = TRY_CAST(TRIM(value) AS INT)
        ),
-- Splits the extras from each unique pizza and explode it vertically
    extras_cte AS (
        SELECT
            rownum,
            t2.topping_name AS extra_ing

        FROM surg_key
        OUTER APPLY STRING_SPLIT(extras, ',') AS extra
        LEFT JOIN pizza_toppings AS t2
            ON t2.topping_id = TRY_CAST(TRIM(extra.value) AS INT)

    ),
-- Splits the exclusions from each unique pizza and explode it vertically
    exclude_cte AS (
        SELECT
            rownum,
            t.topping_name AS excluded_ing

        FROM surg_key
        OUTER APPLY STRING_SPLIT(exclusions, ',') AS exclusion_split
        LEFT JOIN pizza_toppings AS t
            ON t.topping_id = TRY_CAST(TRIM(exclusion_split.value) AS INT)

    ),
-- Combine the base ingredients with the extras and filter out the exclusion
    final_atomic_data AS (
        SELECT
            surg_key.rownum,
            ri.topping_name AS atomic_topping_name
        FROM surg_key
        INNER JOIN recipe_ing AS ri
            ON ri.pizza_id = surg_key.pizza_id
        WHERE ri.topping_name NOT IN (
            SELECT
                excluded_ing
            FROM exclude_cte
            WHERE surg_key.rownum = exclude_cte.rownum
              AND excluded_ing IS NOT NULL
        )

        UNION ALL
        SELECT
            rownum,
            extra_ing
        FROM extras_cte

    ),
-- Counts each ingredient and adds 2x when there is an extra
    counted_extras AS (

        SELECT
            rownum,
            CASE
                WHEN COUNT(atomic_topping_name) = 2
                    THEN CONCAT('2x', atomic_topping_name)
                ELSE atomic_topping_name
                END AS receipt_final
        FROM final_atomic_data
        WHERE atomic_topping_name IS NOT NULL
        GROUP BY
            rownum,
            atomic_topping_name
    ),
-- Aggregates ingredients into a single alphabetically ordered comma-separated string per pizza
    s_aggregated AS (
        SELECT
            rownum,
            STRING_AGG(receipt_final, ', ')
                       WITHIN GROUP ( ORDER BY receipt_final ASC ) AS atomic_receipt
        FROM counted_extras
        GROUP BY rownum
    )
SELECT
    s.rownum,
    order_id,
    customer_id,
    CONCAT(pizza_name, ': ', atomic_receipt) AS instruction_list,
    order_time
FROM surg_key AS s
INNER JOIN s_aggregated AS a
    ON a.rownum = s.rownum;

------------------------------------------------------------------------
-- Q06: What is the total quantity of each ingredient used in all
--      delivered pizzas sorted by most frequent first?
------------------------------------------------------------------------

-- Built on the same CTE foundation as Q5, adapted to count ingredient usage across delivered orders

-- Assigns a unique identifier for each pizza order to handle multi-pizza per order
WITH surg_key AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY order_id) AS rownum,
        c.order_id,
        c.customer_id,
        c.pizza_id,
        n.pizza_name,
        c.exclusions,
        c.extras,
        order_time
    FROM customer_orders_clean AS c
    INNER JOIN pizza_names AS n
        ON c.pizza_id = n.pizza_id
),
-- Splits the 1 row full-ingredients and explode it vertically
    recipe_ing AS
        (
            SELECT
                pizza_id,
                t.topping_name
            FROM pizza_recipes
            CROSS APPLY STRING_SPLIT(toppings, ',')
            INNER JOIN pizza_toppings AS t
                ON t.topping_id = TRY_CAST(TRIM(value) AS INT)
        ),
-- Splits the extras from each unique pizza and explode it vertically
    extras_cte AS (
        SELECT
            rownum,
            t2.topping_name AS extra_ing

        FROM surg_key
        OUTER APPLY STRING_SPLIT(extras, ',') AS extra
        LEFT JOIN pizza_toppings AS t2
            ON t2.topping_id = TRY_CAST(TRIM(extra.value) AS INT)

    ),
-- Splits the exclusions from each unique pizza and explode it vertically
    exclude_cte AS (
        SELECT
            rownum,
            t.topping_name AS excluded_ing

        FROM surg_key
        OUTER APPLY STRING_SPLIT(exclusions, ',') AS exclusion_split
        LEFT JOIN pizza_toppings AS t
            ON t.topping_id = TRY_CAST(TRIM(exclusion_split.value) AS INT)

    ),
-- Combine the base ingredients with the extras and filter out the exclusion
    final_atomic_data AS (
        SELECT
            surg_key.rownum,
            ri.topping_name AS atomic_topping_name
        FROM surg_key
        INNER JOIN recipe_ing AS ri
            ON ri.pizza_id = surg_key.pizza_id
        WHERE ri.topping_name NOT IN (
            SELECT
                excluded_ing
            FROM exclude_cte
            WHERE surg_key.rownum = exclude_cte.rownum
              AND excluded_ing IS NOT NULL
        )

        UNION ALL
        SELECT
            rownum,
            extra_ing
        FROM extras_cte

    )

SELECT
    atomic_topping_name,
    COUNT(atomic_topping_name) AS total_used_ingrediant
FROM final_atomic_data f
INNER JOIN surg_key AS s
    ON s.rownum = f.rownum
INNER JOIN runner_orders_clean AS r
    ON r.order_id = s.order_id
WHERE atomic_topping_name IS NOT NULL
  AND r.cancellation IS NULL
GROUP BY
    atomic_topping_name
ORDER BY
    total_used_ingrediant DESC;