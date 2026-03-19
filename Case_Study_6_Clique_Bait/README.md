# 🦞 Case Study #6: Clique Bait

> 🔗 **Check out the original challenge prompt and dataset here:** [Case Study #6: Clique Bait](https://8weeksqlchallenge.com/case-study-6/)

## 📋 Table of Contents
- [The Business Problem](#-the-business-problem)
- [Tech Stack & Skills Applied](#%EF%B8%8F-tech-stack--skills-applied)
- [Entity Relationship Diagram](#%EF%B8%8F-entity-relationship-diagram)
- [Highlight Queries & Engineering Logic](#-highlight-queries--engineering-logic)
- [What I Would Do Differently in Production](#%EF%B8%8F-what-i-would-do-differently-in-production)

---

## 🏢 The Business Problem

**Clique Bait** is an online seafood store. The business captures every user interaction — page views, cart adds, ad impressions, clicks, and purchases — as raw clickstream events.

**The Goal:**
Build a funnel analytics layer from raw clickstream data. This meant constructing product-level and category-level funnel tables to quantify view-to-cart-to-purchase conversion, materializing a visit-level campaign summary table that maps every session to its marketing context, and deriving campaign performance insights from the materialized data.

---

## 🛠️ Tech Stack & Skills Applied

- **Database Engine:** SQL Server (T-SQL)
- **Data Engineering Skills Applied:**
  - **Funnel Construction:** `EXISTS` correlated subqueries for purchase attribution, `COUNT(DISTINCT CASE WHEN)` for visit-level funnel metrics
  - **Table Materialization:** `SELECT INTO` for product funnel, category funnel, and campaign summary tables
  - **Visit-Level Aggregation:** Collapsing event-level rows to one-row-per-visit grain with conditional `SUM`/`MAX`
  - **String Denormalization:** `STRING_AGG` with `WITHIN GROUP (ORDER BY)` for ordered cart product lists
  - **Campaign Attribution:** `LEFT JOIN` with `BETWEEN` on date ranges to map visits to campaigns
  - **Ambiguous Metric Resolution:** Dual-denominator checkout abandonment analysis with `EXISTS`/`NOT EXISTS` and `CROSS JOIN` scalar aggregation

---

## 🗄️ Entity Relationship Diagram

![Case6_ERD.png](Case6_ERD.png)

> Interactive version: [View on dbdiagram.io](https://dbdiagram.io/d/Clique-Bait-69b87ea878c6c4bc7afa3d82)

---

## 💡 Highlight Queries & Engineering Logic

### Highlight 1 — Funnel Table Construction with EXISTS-Based Purchase Attribution
**Question:** *Section C — Create a product-level funnel table showing views, cart adds, purchases, and abandoned count per product.*
*Full script: [03_C_Product_Funnel_Analysis.sql](03_C_Product_Funnel_Analysis.sql)*

**The Problem:** The events table stores atomic actions — one row per click. There is no "purchased product" event; a purchase event (event_type 3) fires once per visit on the Confirmation page, not per product. A product counts as purchased only if it was added to cart *and* the visit ended with a purchase event. Abandoned products are the inverse — carted but the visit had no purchase.

**The Solution:** A `purchased_cte` isolates cart-add rows whose `visit_id` also has a purchase event via `EXISTS`. The main `product_funnel` CTE then `LEFT JOIN`s this result back — `COUNT(DISTINCT CASE WHEN ... AND pr.page_name IS NOT NULL)` counts purchased products, while `added_to_cart - purchased_product` derives abandonment without a second scan. The `WHERE product_id IS NOT NULL` filter excludes navigation pages (Home, Checkout, Confirmation) from the funnel.

```sql
WITH main_data AS (
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
        SELECT
            a.visit_id,
            a.page_name
        FROM main_data AS a
        WHERE event_type = 2
          AND EXISTS (
            SELECT b.visit_id
            FROM main_data AS b
            WHERE a.visit_id = b.visit_id
              AND b.event_type = 3
        )
    ),
    product_funnel AS (
        SELECT
            md.page_name,
            product_category,
            COUNT(DISTINCT CASE WHEN event_type = 1 THEN md.visit_id END) AS product_views,
            COUNT(DISTINCT CASE WHEN event_type = 2 THEN md.visit_id END) AS added_to_cart,
            COUNT(DISTINCT
                  CASE WHEN event_type = 2 AND pr.page_name IS NOT NULL
                      THEN md.visit_id END) AS purchased_product
        FROM main_data AS md
        LEFT JOIN purchased_cte AS pr
            ON md.visit_id = pr.visit_id
            AND md.page_name = pr.page_name
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
```

#### 📊 Result Set

| product\_category | page\_name | product\_views | added\_to\_cart | purchased\_product | abandoned\_count |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Shellfish | Abalone | 1525 | 932 | 699 | 233 |
| Luxury | Black Truffle | 1469 | 924 | 707 | 217 |
| Shellfish | Crab | 1564 | 949 | 719 | 230 |
| Fish | Kingfish | 1559 | 920 | 707 | 213 |
| Shellfish | Lobster | 1547 | 968 | 754 | 214 |
| Shellfish | Oyster | 1568 | 943 | 726 | 217 |
| Luxury | Russian Caviar | 1563 | 946 | 697 | 249 |
| Fish | Salmon | 1559 | 938 | 711 | 227 |
| Fish | Tuna | 1515 | 931 | 697 | 234 |


---

### Highlight 2 — Visit-Level Campaign Summary Table
**Question:** *Section D — Build a campaign master table with one row per visit containing: user_id, visit metrics, campaign attribution, and a comma-separated list of carted products.*
*Full script: [04_D_Campaigns_Analysis.sql](04_D_Campaigns_Analysis.sql)*

**The Problem:** The raw events table has multiple rows per visit per event type. The campaign summary needs exactly one row per visit with aggregated metrics (page views, cart adds, purchase flag, impressions, clicks), the visit mapped to a campaign window if applicable, and all carted products collapsed into a single ordered string. Aggregation, campaign matching, and string denormalization all need to land in one output table.

**The Solution:** `main_data` is the base join enriching events with user and event type metadata. From there, two CTEs split the work: `grouped_data` collapses events to one row per visit using conditional `SUM`/`MAX` on event_type flags, and `agged_strings` uses `STRING_AGG` with `WITHIN GROUP (ORDER BY sequence_number)` to build the ordered cart product list. The final `SELECT INTO` joins both CTEs with a `LEFT JOIN` to `campaign_identifier` on `BETWEEN` date logic — preserving visits that fall outside any campaign window.

```sql
WITH main_data AS (
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
LEFT JOIN clique_bait.campaign_identifier AS ci
    ON gd.visit_start_time BETWEEN ci.start_date AND ci.end_date;
```

<details>
<summary><b>📊 Click to expand Result Set (first 10 rows)</b></summary>

| user\_id | visit\_id | visit\_start\_time | page\_views | cart\_adds | purchase | campaign\_name | impression | click | cart\_products |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 155 | 001597 | 2020-02-17 00:21:45.2951410 | 10 | 6 | 1 | Half Off - Treat Your Shellf\(ish\) | 1 | 1 | Salmon, Russian Caviar, Black Truffle, Lobster, Crab, Oyster |
| 243 | 002809 | 2020-03-13 17:49:55.4598700 | 4 | 0 | 0 | Half Off - Treat Your Shellf\(ish\) | 0 | 0 | null |
| 78 | 0048b2 | 2020-02-10 02:59:51.3354520 | 6 | 4 | 0 | Half Off - Treat Your Shellf\(ish\) | 0 | 0 | Kingfish, Russian Caviar, Abalone, Lobster |
| 228 | 004aaf | 2020-03-18 13:23:07.9739400 | 6 | 2 | 1 | Half Off - Treat Your Shellf\(ish\) | 0 | 0 | Tuna, Lobster |
| 237 | 005fe7 | 2020-04-02 18:14:08.2577110 | 9 | 4 | 1 | null | 0 | 0 | Kingfish, Black Truffle, Crab, Oyster |
| 420 | 006a61 | 2020-01-25 20:54:14.6302530 | 9 | 5 | 1 | 25% Off - Living The Lux Life | 1 | 1 | Tuna, Russian Caviar, Black Truffle, Abalone, Crab |
| 252 | 006e8c | 2020-02-21 03:14:44.9659380 | 1 | 0 | 0 | Half Off - Treat Your Shellf\(ish\) | 0 | 0 | null |
| 20 | 006f7f | 2020-02-23 01:36:34.7863580 | 5 | 1 | 1 | Half Off - Treat Your Shellf\(ish\) | 1 | 1 | Tuna |
| 436 | 007330 | 2020-01-07 22:30:35.7750680 | 11 | 8 | 1 | BOGOF - Fishing For Compliments | 1 | 1 | Salmon, Kingfish, Tuna, Russian Caviar, Black Truffle, Abalone, Lobster, Oyster |
| 161 | 009e0e | 2020-02-20 06:17:50.9073540 | 8 | 5 | 0 | Half Off - Treat Your Shellf\(ish\) | 0 | 0 | Kingfish, Tuna, Black Truffle, Abalone, Lobster |


</details>

---

### Highlight 3 — Dual-Interpretation Checkout Abandonment
**Question:** *Section B, Q06 — What is the percentage of visits which view the checkout page but do not have a purchase event?*
*Full script: [02_B_Digital_Analysis.sql](02_B_Digital_Analysis.sql)*

**The Problem:** The question is grammatically ambiguous — "percentage of visits" could mean two different things depending on the denominator. Interpretation 1 uses all site visits as the base (consistent with Q5's purchase percentage framework). Interpretation 2 uses only visits that reached checkout as the base (standard e-commerce abandonment rate). Both are valid business metrics that answer different questions, so both are solved.

**The Solution:** `NOT EXISTS` isolates visits that viewed the checkout page (page_id 12) without a corresponding purchase event (event_type 3). A `CROSS JOIN` brings the scalar count onto the events table for inline percentage calculation. The only difference between the two queries is the denominator — `COUNT(DISTINCT visit_id)` for all visits vs. `COUNT(DISTINCT CASE WHEN page_id = 12 THEN visit_id END)` for checkout-only visits.

```sql
-- Interpretation 1: Denominator = all site visits
WITH cte AS (
    SELECT
        COUNT(DISTINCT visit_id) AS view_checkout_non_purchase
    FROM clique_bait.events AS e1
    WHERE event_type = 1
      AND page_id = 12
      AND NOT EXISTS(
        SELECT e2.visit_id
        FROM clique_bait.events AS e2
        WHERE e2.visit_id = e1.visit_id
          AND e2.event_type = 3
    )
)
SELECT
    CAST((MAX(view_checkout_non_purchase) * 100.0)
        / COUNT(DISTINCT visit_id) AS DECIMAL(5, 2)) AS checkout_no_purchase
FROM clique_bait.events
CROSS JOIN cte;

-- Interpretation 2: Denominator = visits that reached checkout
WITH cte AS (
    SELECT
        COUNT(DISTINCT visit_id) AS view_checkout_non_purchase
    FROM clique_bait.events AS e1
    WHERE event_type = 1
      AND page_id = 12
      AND NOT EXISTS(
        SELECT e2.visit_id
        FROM clique_bait.events AS e2
        WHERE e2.visit_id = e1.visit_id
          AND e2.event_type = 3
    )
)
SELECT
    CAST((MAX(view_checkout_non_purchase) * 100.0)
        / COUNT(DISTINCT CASE WHEN page_id = 12 THEN visit_id END)
        AS DECIMAL(5, 2)) AS checkout_no_purchase
FROM clique_bait.events
CROSS JOIN cte;
```

#### 📊 Result Set

| Interpretation | checkout\_no\_purchase |
| :--- | :--- |
| 1 — % of all visits | 9.15 |
| 2 — % of checkout visits | 15.50 |

---

## ⚙️ What I Would Do Differently in Production

- All three materialized tables (`product_funnel`, `category_funnel`, `campaign_summary`) use `SELECT INTO` for development convenience — in production, these would be pre-defined tables with explicit data types, constraints, and indexes, refreshed incrementally as new event data arrives
- The campaign `BETWEEN` join assumes non-overlapping campaign windows and clean boundary dates — a production pipeline would add validation for overlapping campaigns and define whether boundary timestamps are inclusive or exclusive

---

[👉 Click here to view the complete SQL scripts for all 4 sections](.)