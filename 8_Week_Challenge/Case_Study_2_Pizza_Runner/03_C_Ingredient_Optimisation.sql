------------------------------------------------------------------------
-- Q01: What are the standard ingredients for each pizza?
------------------------------------------------------------------------

WITH cte AS (
    SELECT
        n.pizza_name,
        CAST(TRIM(value) AS INT) AS ingredient
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



------------------------------------------------------------------------
-- Q03: What was the most common exclusion?
------------------------------------------------------------------------



------------------------------------------------------------------------
-- Q04: Generate an order item for each record in the customers_orders
--      table in the format of one of the following:
--      Meat Lovers
--      Meat Lovers - Exclude Beef
--      Meat Lovers - Extra Bacon
--      Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
------------------------------------------------------------------------



------------------------------------------------------------------------
-- Q05: Generate an alphabetically ordered comma separated ingredient
--      list for each pizza order from the customer_orders table and
--      add a 2x in front of any relevant ingredients.
------------------------------------------------------------------------



------------------------------------------------------------------------
-- Q06: What is the total quantity of each ingredient used in all
--      delivered pizzas sorted by most frequent first?
------------------------------------------------------------------------