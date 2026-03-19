# 8-Week SQL Challenge in T-SQL

T-SQL solutions to Danny Ma's [8-Week SQL Challenge](https://8weeksqlchallenge.com/), built entirely in SQL Server. Five case studies covering data cleaning, complex joins, time-series logic, and funnel analysis — each with documented query logic, ERDs, and production commentary.

By **[Turki Alajmi](https://www.linkedin.com/in/turki-alajmi-data)**

---

## 📂 Case Studies

| # | Case Study | Business Domain | Key Technical Focus |
|:-:|:-----------|:----------------|:--------------------|
| 1 | **[Danny's Diner](Case_Study_1_Dannys_Diner/)** | Restaurant & Loyalty | Window Functions (`RANK`, `DENSE_RANK`), CTE Chaining, Inequality Joins |
| 2 | **[Pizza Runner](Case_Study_2_Pizza_Runner/)** | Logistics & Delivery | Data Cleaning (`TRY_CAST`, `PATINDEX`), String Parsing (`CROSS APPLY`), Schema Design |
| 3 | **[Foodie-Fi](Case_Study_3_Foodie-Fi/)** | SaaS Subscriptions | Recursive CTEs, `LAG`/`LEAD`, Payment Table Construction |
| 5 | **[Data Mart](Case_Study_5_Data_Mart/)** | E-Commerce Retail | `VARCHAR` Date Parsing, Before/After Impact Analysis, `GROUPING SETS` |
| 6 | **[Clique Bait](Case_Study_6_Clique_Bait/)** | Digital Marketing | Funnel Construction (`EXISTS`), Visit-Level Aggregation, `STRING_AGG` |

Each case study README breaks down the business problem, walks through highlight queries with result sets, and includes notes on what I would do differently in production.

---

> *All datasets and challenge prompts are the intellectual property of [Danny Ma](https://www.datawithdanny.com/).*