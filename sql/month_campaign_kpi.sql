IF OBJECT_ID('dbo.month_campaign_kpi') IS NOT NULL
    DROP TABLE dbo.month_campaign_kpi;
GO

WITH trans_campaign AS (
    SELECT
        t.year,
        t.month,
        DATEFROMPARTS(t.year, t.month, 1) AS stat_month,
        t.campaign_id,
        c.channel,
        c.objective,
        c.target_segment,
        t.transaction_id,
        t.customer_id,
        t.gross_revenue,
        CASE WHEN refund_flag = 0 THEN t.gross_revenue ELSE 0 END AS valid_revenue
    FROM dbo.transactions t
    LEFT JOIN dbo.campaigns c 
        ON t.campaign_id = c.campaign_id
    WHERE t.year IS NOT NULL AND t.month IS NOT NULL
)
,campaign_month_agg AS (
    SELECT
        stat_month,
        year,
        month,
        campaign_id,
        channel,
        objective,
        target_segment,
        SUM(gross_revenue) AS campaign_gmv,
        SUM(valid_revenue) AS campaign_valid_revenue,
        COUNT(DISTINCT transaction_id) AS order_cnt,
        COUNT(DISTINCT customer_id) AS buyer_cnt
    FROM trans_campaign
    GROUP BY stat_month, year, month, campaign_id, channel, objective, target_segment
)
SELECT
    *,
    SUM(campaign_gmv) OVER (PARTITION BY stat_month) AS month_all_campaign_gmv,
    ROUND(campaign_gmv * 1.0 / SUM(campaign_gmv) OVER (PARTITION BY stat_month), 4) AS gmv_contribution_rate,
    SUM(campaign_valid_revenue) OVER (PARTITION BY stat_month) AS month_all_campaign_valid_revenue,
    ROUND(campaign_valid_revenue * 1.0 / SUM(campaign_valid_revenue) OVER (PARTITION BY stat_month), 4) AS valid_revenue_contribution_rate
INTO dbo.month_campaign_kpi
FROM campaign_month_agg
ORDER BY stat_month, campaign_id;
