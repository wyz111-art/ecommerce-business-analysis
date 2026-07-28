IF OBJECT_ID('dbo.channel_user_quality') IS NOT NULL
    DROP TABLE dbo.channel_user_quality;
GO

WITH user_basic AS (
    -- 用户基础信息：注册渠道
    SELECT
        customer_id,
        acquisition_channel
    FROM dbo.customers
),
user_order_info AS (
    -- 每个用户订单汇总
    SELECT
        customer_id,
        MIN(TRY_CAST(timestamp AS DATETIME)) AS first_order_dt, -- 用户首单时间
        COUNT(DISTINCT transaction_id) AS total_order_cnt,
        SUM(CASE WHEN refund_flag = 0 THEN gross_revenue ELSE 0 END) AS user_valid_revenue,
        -- 是否产生订单
        CASE WHEN COUNT(transaction_id) > 0 THEN 1 ELSE 0 END AS is_buyer,
        -- 是否复购：订单数≥2
        CASE WHEN COUNT(DISTINCT transaction_id) >= 2 THEN 1 ELSE 0 END AS is_repurchase,
        -- 该用户订单里退款订单数量
        SUM(CASE WHEN refund_flag = 1 THEN 1 ELSE 0 END) AS user_refund_order_cnt,
        COUNT(transaction_id) AS user_all_order_cnt
    FROM dbo.transactions
    GROUP BY customer_id
),
user_merge AS (
    SELECT
        u.customer_id,
        u.acquisition_channel,
        o.first_order_dt,
        o.is_buyer,
        o.is_repurchase,
        o.user_valid_revenue,
        o.total_order_cnt,
        o.user_refund_order_cnt,
        o.user_all_order_cnt
    FROM user_basic u
    LEFT JOIN user_order_info o
        ON u.customer_id = o.customer_id
),
-- 计算全体付费用户人均有效收入，用来定义高价值用户
global_buyer_avg AS (
    SELECT AVG(user_valid_revenue) AS avg_buyer_revenue
    FROM user_merge
    WHERE is_buyer = 1
),
user_tag AS (
    SELECT
        m.*,
        g.avg_buyer_revenue,
        -- 高价值用户标签：付费且收入大于付费用户均值
        CASE
            WHEN m.is_buyer = 1 AND m.user_valid_revenue > g.avg_buyer_revenue
            THEN 1 ELSE 0
        END AS is_high_value_user
    FROM user_merge m
    CROSS JOIN global_buyer_avg g
    LEFT JOIN dbo.customers c ON m.customer_id = c.customer_id
)
-- 按渠道聚合所有指标
SELECT
    acquisition_channel,
    COUNT(DISTINCT customer_id) AS register_user_cnt, -- 渠道新增注册用户
    SUM(is_buyer) AS buyer_cnt, -- 渠道付费用户
    -- 首购转化率
    ROUND(SUM(is_buyer)*1.0 / COUNT(DISTINCT customer_id),4) AS first_buy_conv_rate,
    -- 付费用户人均有效收入
    CASE WHEN SUM(is_buyer) > 0
         THEN ROUND(SUM(CASE WHEN is_buyer=1 THEN user_valid_revenue ELSE 0 END)*1.0 / SUM(is_buyer),2)
         ELSE 0 END AS avg_revenue_per_buyer,
    -- 复购率：付费用户中订单≥2的占比
    CASE WHEN SUM(is_buyer) > 0
         THEN ROUND(SUM(is_repurchase)*1.0 / SUM(is_buyer),4)
         ELSE 0 END AS repurchase_rate,
    -- 渠道整体退款率
    CASE WHEN SUM(user_all_order_cnt) > 0
         THEN ROUND(SUM(user_refund_order_cnt)*1.0 / SUM(user_all_order_cnt),4)
         ELSE 0 END AS channel_refund_rate,
    -- 高价值用户数量 & 占渠道付费用户比例
    SUM(is_high_value_user) AS high_value_user_cnt,
    CASE WHEN SUM(is_buyer) > 0
         THEN ROUND(SUM(is_high_value_user)*1.0 / SUM(is_buyer),4)
         ELSE 0 END AS high_value_user_ratio
INTO dbo.channel_user_quality
FROM user_tag
GROUP BY acquisition_channel
ORDER BY register_user_cnt DESC;
