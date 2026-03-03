------------------------------------------------------------------------
--Q01 How many runners signed up for each 1-week period?
--    (i.e. week starts 2021-01-01)
------------------------------------------------------------------------

WITH histo AS (
    SELECT
        runner_id,
        registration_date,
        (DATEDIFF(DAY, '20210101', registration_date) / 7) + 1 AS week_histo
/*  This week_histo column uses the integer devision concept to throw
    the decimal point and +1 to make the starting week from 0 >> 1 */
    FROM runners
)
SELECT
    week_histo,
    COUNT(*) AS runners_registering
FROM histo
GROUP BY
    week_histo;

------------------------------------------------------------------------
--Q02 What was the average time in minutes it took for each runner to
--    arrive at the Pizza Runner HQ to pickup the order?
------------------------------------------------------------------------

WITH distinct_orders AS (
    SELECT DISTINCT
        r.runner_id AS runner,
        r.order_id,
        DATEDIFF(MINUTE, c.order_time, r.pickup_time) AS picktime
    FROM runner_orders_clean AS r
    INNER JOIN customer_orders_clean AS c
        ON r.order_id = c.order_id
    WHERE r.cancellation IS NULL
)

SELECT
    runner,
    AVG(picktime) AS avg_pickup_time
FROM distinct_orders
GROUP BY
    runner;

------------------------------------------------------------------------
--Q03 Is there any relationship between the number of pizzas and how
--    long the order takes to prepare?
------------------------------------------------------------------------

WITH diff AS (

    SELECT DISTINCT
        c.order_id AS order_dis,
        DATEDIFF(MINUTE, c.order_time, r.pickup_time) AS time_diff
    FROM customer_orders_clean AS c
    INNER JOIN runner_orders_clean AS r
        ON r.order_id = c.order_id
    WHERE r.cancellation IS NULL
),
    histogram AS (
        SELECT
            order_id,
            COUNT(order_id) AS amount_of_pizza
        FROM customer_orders_clean
        GROUP BY
            order_id
    )
SELECT
    amount_of_pizza,
    AVG(time_diff) AS avg_delivery_time
FROM histogram
INNER JOIN diff
    ON diff.order_dis = histogram.order_id
GROUP BY
    amount_of_pizza;
/*
 We can clearly see that the more pizza in 1 order = more prep-time and longer delivery at the end
 */

------------------------------------------------------------------------
--Q04 What was the average distance travelled for each customer?
------------------------------------------------------------------------

WITH true_values AS (
    SELECT DISTINCT
        c.customer_id,
        r.distance,
        c.order_id


    FROM customer_orders_clean AS c
    INNER JOIN runner_orders_clean AS r
        ON c.order_id = r.order_id
    WHERE r.cancellation IS NULL
)

SELECT
    customer_id,
    AVG(distance) AS avg_distance
FROM true_values
GROUP BY
    customer_id;


------------------------------------------------------------------------
--Q05 What was the difference between the longest and shortest delivery
--    times for all orders?
------------------------------------------------------------------------

SELECT
    MAX(duration) - MIN(duration) AS diffrence
FROM runner_orders_clean
WHERE cancellation IS NULL;

------------------------------------------------------------------------
--Q06 What was the average speed for each runner for each delivery and
--    do you notice any trend for these values?
------------------------------------------------------------------------

SELECT
    runner_id,
    order_id,
    CAST(SUM(distance / (duration / 60.0)) AS DECIMAL(5, 1)) AS avg_speed_kmph
FROM runner_orders_clean
WHERE cancellation IS NULL
GROUP BY
    runner_id,
    order_id
ORDER BY
    runner_id,
    order_id,
    avg_speed_kmph;
/*
 runner's first order is always the slowest, maybe they are nervous?
 Also runner 2 speed is doubling on every order, danny need to give runner 2 a raise.
 */

------------------------------------------------------------------------
--Q07 What is the successful delivery percentage for each runner?
------------------------------------------------------------------------

WITH nums AS (
    SELECT
        runner_id,
        SUM(CASE
                WHEN cancellation IS NULL THEN 1
                ELSE 0
            END) AS successful_delivery,
        COUNT(*) AS all_orders
    FROM runner_orders_clean
    GROUP BY
        runner_id

)

SELECT
    runner_id,
    CAST((100.0 * successful_delivery) / all_orders AS DECIMAL(5, 2)) AS successful_delivery_percentage
FROM nums;