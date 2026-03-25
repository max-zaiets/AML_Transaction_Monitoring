
-- Fraud Pattern Analysis
-- Goal: find common characteristics of IS_FRAUD=1 transactions
-- and test whether new rules outperform the existing ones


-- Step 1: compare fraud vs non-fraud transactions side by side
-- looking for numeric differences that could become rules
SELECT
    IS_FRAUD,
    COUNT(*) AS transaction_count,
    ROUND(AVG(AMOUNT), 2) AS avg_amount,
    ROUND(AVG(OLD_BALANCE_ORIG), 2) AS avg_orig_balance,
    ROUND(AVG(NEW_BALANCE_ORIG), 2) AS avg_new_balance_orig,
    ROUND(AVG(OLD_BALANCE_DEST), 2) AS avg_dest_balance,
    ROUND(AVG(NEW_BALANCE_DEST), 2) AS avg_new_balance_dest,
    -- how often does amount equal the original balance exactly?
    SUM(CASE WHEN AMOUNT = OLD_BALANCE_ORIG THEN 1 ELSE 0 END) AS exact_drain_count,
    -- how often does destination balance stay at zero despite receiving money?
    SUM(CASE WHEN OLD_BALANCE_DEST = 0 AND NEW_BALANCE_DEST = 0 AND AMOUNT > 0 THEN 1 ELSE 0 END) AS dest_balance_mismatch
FROM RAW_TRANSACTIONS
WHERE TYPE IN ('TRANSFER', 'CASH_OUT')
GROUP BY IS_FRAUD;



-- Step 2: final comparison - all rules in one table

SELECT rule_name, total_alerts, confirmed_fraud_caught, precision_pct, recall_pct FROM (

    SELECT 'Existing Flag'                      AS rule_name,
        SUM(IS_FLAGGED_FRAUD)                   AS total_alerts,
        SUM(CASE WHEN IS_FRAUD=1 AND IS_FLAGGED_FRAUD=1 THEN 1 ELSE 0 END) AS confirmed_fraud_caught,
        ROUND(SUM(CASE WHEN IS_FRAUD=1 AND IS_FLAGGED_FRAUD=1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(IS_FLAGGED_FRAUD),0)*100,2) AS precision_pct,
        ROUND(SUM(CASE WHEN IS_FRAUD=1 AND IS_FLAGGED_FRAUD=1 THEN 1.0 ELSE 0 END)/NULLIF(SUM(IS_FRAUD),0)*100,2) AS recall_pct
    FROM RAW_TRANSACTIONS

    UNION ALL

    SELECT 'Rule A: Exact Balance Transfer'     AS rule_name,
        COUNT(*)                                AS total_alerts,
        SUM(IS_FRAUD)                           AS confirmed_fraud_caught,
        ROUND(SUM(IS_FRAUD)/COUNT(*)*100,2)     AS precision_pct,
        ROUND(SUM(IS_FRAUD)/(SELECT SUM(IS_FRAUD) FROM RAW_TRANSACTIONS)*100,2) AS recall_pct
    FROM RAW_TRANSACTIONS
    WHERE TYPE IN ('TRANSFER','CASH_OUT') AND AMOUNT=OLD_BALANCE_ORIG AND NEW_BALANCE_ORIG=0 AND OLD_BALANCE_ORIG>0

    UNION ALL

    SELECT 'Rule B: Destination Mismatch'       AS rule_name,
        COUNT(*)                                AS total_alerts,
        SUM(IS_FRAUD)                           AS confirmed_fraud_caught,
        ROUND(SUM(IS_FRAUD)/COUNT(*)*100,2)     AS precision_pct,
        ROUND(SUM(IS_FRAUD)/(SELECT SUM(IS_FRAUD) FROM RAW_TRANSACTIONS)*100,2) AS recall_pct
    FROM RAW_TRANSACTIONS
    WHERE TYPE='TRANSFER' AND OLD_BALANCE_DEST=0 AND NEW_BALANCE_DEST=0 AND AMOUNT>0

    UNION ALL

    SELECT 'Rule C: Combined'                   AS rule_name,
        COUNT(*)                                AS total_alerts,
        SUM(IS_FRAUD)                           AS confirmed_fraud_caught,
        ROUND(SUM(IS_FRAUD)/COUNT(*)*100,2)     AS precision_pct,
        ROUND(SUM(IS_FRAUD)/(SELECT SUM(IS_FRAUD) FROM RAW_TRANSACTIONS)*100,2) AS recall_pct
    FROM RAW_TRANSACTIONS
    WHERE TYPE IN ('TRANSFER','CASH_OUT') AND AMOUNT=OLD_BALANCE_ORIG AND NEW_BALANCE_ORIG=0
      AND OLD_BALANCE_DEST=0 AND NEW_BALANCE_DEST=0

) results
ORDER BY recall_pct DESC;
