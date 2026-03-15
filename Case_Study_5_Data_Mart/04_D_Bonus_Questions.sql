/* ---------------------------------------------------------------------------
-- Case Study #5: Data Mart
-- Section D: Bonus Question
-- Author: Turki Alajmi
-- Date: March 2026
-- Tool used: Microsoft SQL Server (T-SQL)
--------------------------------------------------------------------------- */

------------------------------------------------------------------------
-- Q1: Which areas of the business have the highest negative impact in
-- sales metrics performance in 2020 for the 12 week before and after period?
--
-- Find the areas across:
-- 1. region
-- 2. platform
-- 3. age_band
-- 4. demographic
-- 5. customer_type
------------------------------------------------------------------------

-- Groups sales by 5 business dimensions using GROUPING SETS for a single-scan analysis.
-- GROUPING() replaces aggregation NULLs with '-' to distinguish them from data NULLs.

WITH before_after_sales AS (
    SELECT
        CASE WHEN GROUPING(region) = 1 THEN '-' ELSE region END AS region,
        CASE WHEN GROUPING(platform) = 1 THEN '-' ELSE platform END AS platform,
        CASE WHEN GROUPING(age_band) = 1 THEN '-' ELSE age_band END AS age_band,
        CASE WHEN GROUPING(demographic) = 1 THEN '-' ELSE demographic END AS demographic,
        CASE WHEN GROUPING(customer_type) = 1 THEN '-' ELSE customer_type END AS customer_type,
        SUM(CASE
                WHEN week_number BETWEEN 12 AND 23 THEN
                    CAST(sales AS BIGINT) END) AS before_sales,
        SUM(CASE
                WHEN week_number BETWEEN 24 AND 35 THEN
                    CAST(sales AS BIGINT) END) AS after_sales
    FROM data_mart.clean_weekly_sales
    WHERE week_number BETWEEN 12 AND 35
      AND calendar_year = 2020
    GROUP BY
        GROUPING SETS (
        (region), (platform), (age_band), (demographic), (customer_type))
)

SELECT
    region,
    platform,
    age_band,
    demographic,
    customer_type,
    before_sales,
    after_sales,
    after_sales - before_sales AS difference,
    CAST(((after_sales - before_sales) * 100.0) / before_sales AS DECIMAL(5, 2)) AS growth
FROM before_after_sales;