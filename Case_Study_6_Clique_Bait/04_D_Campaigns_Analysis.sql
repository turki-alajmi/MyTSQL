/* ---------------------------------------------------------------------------
-- Case Study #6: Clique Bait
-- Section D: Campaigns Analysis
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
-- PART 1: BUILD THE CAMPAIGN MASTER TABLE
-- Generate a table that has 1 single row for every unique visit_id record
-- and has the following columns:
--
-- 1. user_id
-- 2. visit_id
-- 3. visit_start_time: the earliest event_time for each visit
-- 4. page_views: count of page views for each visit
-- 5. cart_adds: count of product cart add events for each visit
-- 6. purchase: 1/0 flag if a purchase event exists for each visit
-- 7. campaign_name: map the visit to a campaign if the visit_start_time falls
--    between the start_date and end_date
-- 8. impression: count of ad impressions for each visit
-- 9. click: count of ad clicks for each visit
-- 10. (Optional) cart_products: a comma separated text value with products added
--     to the cart sorted by the order they were added (hint: use sequence_number)
--------------------------------------------------------------------------- */


WITH main_data AS (
    -- Base join: events enriched with user and event type metadata.
    SELECT
        e.visit_id,
        e.page_id,
        e.event_type,
        ei.event_name,
        e.sequence_number,
        e.event_time,
        u.user_id
    FROM clique_bait.events AS e
    INNER JOIN clique_bait.users AS u
        ON u.cookie_id = e.cookie_id
    INNER JOIN clique_bait.event_identifier AS ei
        ON ei.event_type = e.event_type
),
    grouped_data AS (
        -- One row per visit with all event-level metrics aggregated up.
        -- user_id is consistent per visit so it's safe to GROUP BY.
        SELECT
            visit_id,
            user_id,
            MIN(event_time) AS visit_start_time,
            SUM(CASE WHEN event_type = 1 THEN 1 ELSE 0 END) AS page_views,
            SUM(CASE WHEN event_type = 2 THEN 1 ELSE 0 END) AS cart_adds,
            MAX(CASE WHEN event_type = 3 THEN 1 ELSE 0 END) AS purchase,
            SUM(CASE WHEN event_type = 4 THEN 1 ELSE 0 END) AS impression,
            SUM(CASE WHEN event_type = 5 THEN 1 ELSE 0 END) AS click
        FROM main_data
        GROUP BY
            visit_id,
            user_id

    ),
    agged_strings AS (
        -- Collapses all cart-added products per visit into a single
        -- comma-separated string, ordered by sequence_number.
        SELECT
            e.visit_id,
            STRING_AGG(page_name, ', ')
                       WITHIN GROUP ( ORDER BY sequence_number ASC ) AS cart_products
        FROM clique_bait.events AS e
        INNER JOIN clique_bait.page_hierarchy ph
            ON e.page_id = ph.page_id
        WHERE event_type = 2
        GROUP BY e.visit_id

    )

SELECT
    gd.user_id,
    gd.visit_id,
    gd.visit_start_time,
    gd.page_views,
    gd.cart_adds,
    gd.purchase,
    ci.campaign_name,
    gd.impression,
    gd.click,
    cart_products
INTO clique_bait.campaign_summary
FROM grouped_data AS gd
LEFT JOIN agged_strings AS ag
    ON ag.visit_id = gd.visit_id
    -- Campaign matched on visit start time, not individual event time.
-- LEFT JOIN preserves visits that fall outside any campaign window.
LEFT JOIN clique_bait.campaign_identifier AS ci
    ON gd.visit_start_time BETWEEN ci.start_date AND ci.end_date;


/* ---------------------------------------------------------------------------
-- PART 2: CAMPAIGN INSIGHTS
-- Use the subsequent dataset to generate at least 5 insights for the Clique Bait team.
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
-- Insight 1: Impression Impact
-- Identify users who have received impressions during each campaign period
-- and compare each metric with other users who did not have an impression event.
------------------------------------------------------------------------

SELECT
    CASE WHEN impression >= 1 THEN 'Yes' ELSE 'No' END AS impressions,
    campaign_name,
    CAST(AVG(page_views * 1.0) AS DECIMAL(5, 2)) AS page_view_avg,
    CAST(AVG(cart_adds * 1.0) AS DECIMAL(5, 2)) AS cart_adds_avg,
    CAST(AVG(purchase * 100.0) AS DECIMAL(5, 2)) AS avg_purchase_percent
FROM clique_bait.campaign_summary
WHERE campaign_name IS NOT NULL
GROUP BY
    campaign_name,
    CASE WHEN impression >= 1 THEN 'Yes' ELSE 'No' END
ORDER BY
    campaign_name;

------------------------------------------------------------------------
-- Insight 2: Click Conversion Rate
-- Does clicking on an impression lead to higher purchase rates?
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Insight 3: Purchase Uplift
-- What is the uplift in purchase rate when comparing users who click on a
-- campaign impression versus users who do not receive an impression?
-- What if we compare them with users who just get an impression but do not click?
------------------------------------------------------------------------

-- Insight 2 & 3 are answered by the same query.
-- Insight 2: Does clicking lead to higher purchase rates?
-- Insight 3: What is the purchase uplift across all three interaction types?


SELECT
    CASE
        WHEN click >= 1 THEN 'Clicked'
        WHEN impression >= 1 THEN 'Impression Only'
        ELSE 'No Impression'
        END AS interaction_type,
    CAST(AVG(purchase * 100.0) AS DECIMAL(5, 2)) AS purchase_percent
FROM clique_bait.campaign_summary
GROUP BY
    CASE
        WHEN click >= 1 THEN 'Clicked'
        WHEN impression >= 1 THEN 'Impression Only'
        ELSE 'No Impression'
        END;

-- Insight 4: Campaign Scorecard
-- Compares campaigns across three metrics: purchase lift from impressions,
-- total impression volume, and impression-to-click rate.

SELECT
    campaign_name,
    -- Lift is the jump of purchase rate after an impression
    CAST((AVG(CASE WHEN impression >= 1 THEN purchase * 1.0 END) -
          AVG(CASE WHEN impression < 1 THEN purchase * 1.0 END))
             / AVG(CASE WHEN impression < 1 THEN purchase * 1.0 END) * 100.0 AS DECIMAL(5, 2)) AS lift,
    SUM(impression) AS total_impression,
    CAST((SUM(click * 100.0)) / SUM(impression) AS DECIMAL(5, 2)) AS impression_to_click_rate
FROM clique_bait.campaign_summary
WHERE campaign_name IS NOT NULL
GROUP BY
    campaign_name;