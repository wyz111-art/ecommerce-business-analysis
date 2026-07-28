WITH trans_with_first_info AS (
    SELECT
        year,
        month,
        DATEFROMPARTS(year, month, 1) AS stat_month,
        transaction_id,
        customer_id,
        gross_revenue,
        CASE WHEN refund_flag = 0 THEN gross_revenue ELSE 0 END AS valid_revenue,
        MIN(year) OVER (PARTITION BY customer_id) AS first_order_year,
        MIN(month) OVER (PARTITION BY customer_id) AS first_order_month
    FROM dbo.transactions
    WHERE year IS NOT NULL AND month IS NOT NULL
)
,trans_with_usertype AS (
    SELECT
        *,
        CASE
            WHEN year = first_order_year AND month = first_order_month
            THEN N'新用户'
            ELSE N'老用户'
        END AS user_type
    FROM trans_with_first_info
)
,month_user_agg AS (
    SELECT
        stat_month,
        year,
        month,
        user_type,
        SUM(gross_revenue) AS total_gmv,
        SUM(valid_revenue) AS valid_revenue,
        COUNT(DISTINCT transaction_id) AS total_order_count,
        COUNT(DISTINCT customer_id) AS pay_user_count
    FROM trans_with_usertype
    GROUP BY stat_month, year, month, user_type
)
SELECT
    *,
    -- 窗口函数：按月份汇总全部营收，用来计算占比
    SUM(total_gmv) OVER (PARTITION BY stat_month) AS month_total_gmv,
    ROUND(total_gmv * 1.0 / SUM(total_gmv) OVER (PARTITION BY stat_month), 4) AS gmv_ratio,
    SUM(valid_revenue) OVER (PARTITION BY stat_month) AS month_total_valid_revenue,
    ROUND(valid_revenue * 1.0 / SUM(valid_revenue) OVER (PARTITION BY stat_month), 4) AS valid_revenue_ratio
INTO dbo.user_type_revenue
FROM month_user_agg
ORDER BY stat_month, user_type;

