IF OBJECT_ID('dbo.month_category_kpi') IS NOT NULL
    DROP TABLE dbo.month_category_kpi;
GO

WITH trans_product AS (
    SELECT
        t.year,
        t.month,
        DATEFROMPARTS(t.year, t.month, 1) AS stat_month,
        t.transaction_id,
        t.customer_id,
        t.gross_revenue,
        CASE WHEN refund_flag = 0 THEN t.gross_revenue ELSE 0 END AS valid_revenue,
        t.quantity,
        p.category  
    FROM dbo.transactions t
    LEFT JOIN dbo.products p 
        ON t.product_id = p.product_id
    WHERE t.year IS NOT NULL AND t.month IS NOT NULL
)
,category_month_agg AS (
    SELECT
        stat_month,
        year,
        month,
        category,
        SUM(gross_revenue) AS category_gmv,
        SUM(valid_revenue) AS category_valid_revenue,
        SUM(quantity) AS sell_qty,
        COUNT(DISTINCT transaction_id) AS order_cnt,
        COUNT(DISTINCT customer_id) AS buyer_cnt
    FROM trans_product
    GROUP BY stat_month, year, month, category
)
SELECT
    *,
    SUM(category_gmv) OVER(PARTITION BY stat_month) AS month_total_gmv,
    ROUND(category_gmv * 1.0 / SUM(category_gmv) OVER(PARTITION BY stat_month),4) AS gmv_ratio,
    SUM(category_valid_revenue) OVER(PARTITION BY stat_month) AS month_total_valid_revenue,
    ROUND(category_valid_revenue * 1.0 / SUM(category_valid_revenue) OVER(PARTITION BY stat_month),4) AS valid_revenue_ratio
INTO dbo.month_category_kpi
FROM category_month_agg
ORDER BY stat_month, category;
