--RFM用户价值分层
--R：最近一次下单次数；F：有效订单购买次数；M：累积有效收入

IF OBJECT_ID('dbo.user_rfm_segment') IS NOT NULL
    DROP TABLE dbo.user_rfm_segment;
GO

WITH user_agg AS (
    SELECT
        customer_id,
        MIN(TRY_CAST(timestamp AS DATETIME)) AS first_order_dt,
        MAX(TRY_CAST(timestamp AS DATETIME)) AS last_order_dt,
        COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END) AS f_value,
        SUM(CASE WHEN refund_flag = 0 THEN gross_revenue ELSE 0 END) AS m_value,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END) > 0 
            THEN SUM(CASE WHEN refund_flag = 0 THEN gross_revenue ELSE 0 END)*1.0 
                 / COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END)
            ELSE 0 
        END AS avg_order_price,
        CASE 
            WHEN COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END) >= 2 
            THEN 1 ELSE 0 
        END AS is_repurchase
    FROM dbo.transactions
    WHERE year IS NOT NULL AND month IS NOT NULL
    GROUP BY customer_id
)
,user_rfm_raw AS (
    SELECT
        *,
        MAX(last_order_dt) OVER() AS dataset_latest_dt,
        DATEDIFF(DAY, last_order_dt, MAX(last_order_dt) OVER()) AS r_days
    FROM user_agg
)
,user_rfm_score AS (
    SELECT
        *,
        -- 窗口函数：全局切分两组
        NTILE(2) OVER(ORDER BY r_days) AS r_tile,
        NTILE(2) OVER(ORDER BY f_value) AS f_tile,
        NTILE(2) OVER(ORDER BY m_value) AS m_tile,
        -- R打分：天数偏小(前一半) → 活跃=1
        CASE WHEN NTILE(2) OVER(ORDER BY r_days) = 1 THEN 1 ELSE 0 END AS r_score,
        -- F打分：频次偏高(后一半)=1
        CASE WHEN NTILE(2) OVER(ORDER BY f_value) = 2 THEN 1 ELSE 0 END AS f_score,
        -- M打分：金额偏高(后一半)=1
        CASE WHEN NTILE(2) OVER(ORDER BY m_value) = 2 THEN 1 ELSE 0 END AS m_score
    FROM user_rfm_raw
)
SELECT
    *,
    CASE
        WHEN r_score=1 AND f_score=1 AND m_score=1 THEN N'高价值用户'
        WHEN r_score=1 AND f_score=0 AND m_score=1 THEN N'潜力用户'
        WHEN r_score=1 AND f_score=0 AND m_score=0 THEN N'新用户'
        WHEN r_score=1 AND f_score=1 AND m_score=0 THEN N'一般用户'
        WHEN r_score=0 AND f_score=1 AND m_score=1 THEN N'流失风险用户'
        ELSE N'沉睡用户'
    END AS user_segment
INTO dbo.user_rfm_segment
FROM user_rfm_score
ORDER BY m_value DESC;
