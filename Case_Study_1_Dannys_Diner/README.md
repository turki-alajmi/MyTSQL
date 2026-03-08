# 🍜 Case Study #1: Danny's Diner 

> 🔗 **Check out the original challenge prompt and dataset here:** [Case Study #1: Danny's Diner](https://8weeksqlchallenge.com/case-study-1/)

## 📋 Table of Contents
- [The Business Problem](#-the-business-problem)
- [Tech Stack Used](#%EF%B8%8F-tech-stack-used)
- [Entity Relationship Diagram](#%EF%B8%8F-entity-relationship-diagram)
- [Highlight Queries & Business Insights](#-highlight-queries--business-insights)

---

## 🏢 The Business Problem
**Danny's Diner** has accumulated transactional data across sales, menu items, and loyalty memberships — but no analytical layer exists to extract value from it. Customer behavior, spending patterns, and menu performance are currently invisible to the business.

**The Goal:**
Query the raw operational data to surface customer purchasing patterns, identify high-value customers, and evaluate menu item performance. The findings will directly support a decision on whether to expand the existing loyalty program.

---

## 🛠️ Tech Stack Used
- **Database Engine:** SQL Server (T-SQL)
- **Core Concepts:** Common Table Expressions (CTEs), Window Functions (`DENSE_RANK`,`RANK`), Aggregations (`SUM`, `COUNT`), And `CASE WHEN` statements.

---

## 🗄️ Entity Relationship Diagram

![Case1_ERD.png](Case1_ERD.png)

---

## 💡 Highlight Queries & Business Insights
*Note: The complete SQL script containing all 10 questions can be found in the [01_Dannys_Diner_Solutions.sql](01_Dannys_Diner_Solutions.sql) file in this repository.*

### Q5. Which item was the most popular for each customer?


**Logic:** RANK() was chosen over ROW_NUMBER() to correctly handle ties — as seen with Customer B who ordered all three items equally

```sql
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
```

#### 📊 Result Set

| customer_id | product_name | product_count |
| :--- | :--- | :--- |
| A | ramen | 3 |
| B | sushi | 2 |
| B | curry | 2 |
| B | ramen | 2 |
| C | ramen | 3 |
---
### Q7. Which item was purchased just before the customer became a member?


**Logic:** A strict inequality join (`order_date < join_date`) was used to ensure we only analyze purchases made *before* the exact day they signed up. `RANK()` was then applied to capture every item, just in case the customer placed a multi-item order on their final visit.

```sql
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
```
#### 📊 Result Set
| customer | product |
| :--- | :--- |
| A | sushi |
| A | curry |
| B | sushi |
---
### Q10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushI how many points do customer A and B have at the end of January


**Logic:** Assuming points accumulate normally before membership, a SUM(CASE WHEN) handles three scenarios in priority order: the first week 2x multiplier on all items, the permanent sushi 2x multiplier, and the base rate. Order is deliberate — sushi ordered in the first week hits the first week rule first, not the sushi rule.

```sql
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
```
#### 📊 Result Set
| customer_id | members_points |
| :--- | :--- |
| A | 1370 |
| B | 820 |
---


[👉 Click here to view the complete SQL script with all 10 solutions](01_Dannys_Diner_Solutions.sql)

