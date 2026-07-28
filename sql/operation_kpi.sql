SELECT
year,
month,
SUM(gross_revenue) AS total_gmv,
SUM(CASE WHEN refund_flag = 0 THEN gross_revenue ELSE 0 END) AS vaild_revenue,
COUNT(DISTINCT transaction_id) AS total_order_count,
COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END) AS vaild_order_count,
COUNT(DISTINCT customer_id) AS pay_user_count,
--有效客单价
CASE
    WHEN COUNT(DISTINCT customer_id) > 0
    THEN SUM(CASE WHEN refund_flag = 0 THEN gross_revenue ELSE 0 END) / COUNT(DISTINCT customer_id)
    ELSE 0 
END AS avg_customer_price,
--连带率
CASE
    WHEN COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END) > 0
    THEN SUM(CASE WHEN refund_flag = 0 THEN quantity ELSE 0 END) * 1.0 / COUNT(DISTINCT CASE WHEN refund_flag = 0 THEN transaction_id END)
    ELSE 0 
END AS items_per_order,
--折扣订单占比
CASE 
        WHEN COUNT(transaction_id) > 0
        THEN SUM(CASE WHEN discount_applied > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(transaction_id)
        ELSE 0 
    END AS discount_order_ratio,
--退款率
CASE 
        WHEN COUNT(transaction_id) > 0
        THEN SUM(CASE WHEN refund_flag = 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(transaction_id)
        ELSE 0 
    END AS refund_ratio
INTO dbo.operation_kpi
FROM dbo.transactions
WHERE year IS NOT NULL AND month IS NOT NULL
GROUP BY year,month
ORDER BY year,month;