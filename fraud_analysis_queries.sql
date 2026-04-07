-- Initial Data Exploration
SELECT * FROM "Credit Card Fraud Detection" LIMIT 10;

-- Get Total Transaction Volume
SELECT COUNT(*) AS total_num
FROM "Credit Card Fraud Detection";

-- Distribution of Transactions by Class (Legit vs. Fraud)
SELECT "Class", COUNT(*) AS fraud_num
FROM "Credit Card Fraud Detection"
GROUP BY "Class";

-- Class Imbalance Analysis: Calculate Percentage of Each Class
SELECT 
    "Class", 
    COUNT(*) AS num_per_class,
    -- Calculation: (Count of Class / Total Transactions) * 100
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 4) || '%' AS percentage
FROM "Credit Card Fraud Detection"
GROUP BY "Class";

-- Temporal Analysis: Converting seconds to 24-hour format
SELECT 
    CAST("Time"/ 3600 AS INT) % 24 AS hour_of_day,
    "Class",
    COUNT(*) AS transaction_count
FROM "Credit Card Fraud Detection"
GROUP BY hour_of_day, "Class"
ORDER BY hour_of_day, "Class";

-- Summary Statistics: Analyzing Transaction Amounts by Class
SELECT 
    "Class", 
    COUNT(*) AS total_count,
    ROUND(AVG("amount")::numeric, 2) AS avg_amount,
    ROUND(MIN("amount")::numeric, 2) AS min_amount,
    ROUND(MAX("amount")::numeric, 2) AS max_amount,
    ROUND(STDDEV("amount")::numeric, 2) AS std_amount
FROM "Credit Card Fraud Detection"
GROUP BY "Class";

-- Behavioral Segmenting: Identifying "Micro-testing" vs. "High-value" Patterns
SELECT 
    CASE 
        WHEN "amount" <= 1 THEN '01_Micro (<=1)'
        WHEN "amount" <= 10 THEN '02_Small (1-10)'
        WHEN "amount" <= 100 THEN '03_Standard (10-100)'
        WHEN "amount" <= 1000 THEN '04_High (100-1000)'
        ELSE '05_Ultra High (>1000)'
    END AS amount_range,
    "Class",
    COUNT(*) AS transaction_count
FROM "Credit Card Fraud Detection"
GROUP BY amount_range, "Class"
ORDER BY amount_range, "Class";

-- Feature Profiling: Comparing PCA Variances between Classes
SELECT 
    "Class",
    ROUND(AVG("v1")::numeric, 4) AS avg_v1,
    ROUND(AVG("v3")::numeric, 4) AS avg_v3,
    ROUND(AVG("v10")::numeric, 4) AS avg_v10,
    ROUND(AVG("v14")::numeric, 4) AS avg_v14,
    ROUND(AVG("v17")::numeric, 4) AS avg_v17
FROM "Credit Card Fraud Detection"
GROUP BY "Class";

-- Velocity Analysis: Calculating Time Difference (Seconds) between Consecutive Transactions
SELECT 
    "Time","v1","v2","amount","Class",
    "Time" - LAG("Time") OVER(PARTITION BY "v1", "v2" ORDER BY "Time") AS time_diff
FROM "Credit Card Fraud Detection"
ORDER BY time_diff ASC
LIMIT 20;

-- Outlier Detection: Identifying Transactions 3x Greater than User Average
SELECT 
    "Class", "amount",
    AVG("amount") OVER(PARTITION BY "v1", "v2") AS user_avg_amount,
    CASE 
        WHEN "amount" > 3 * (AVG("amount") OVER(PARTITION BY "v1", "v2")) THEN 1 
        ELSE 0 
    END AS is_amount_outlier
FROM "Credit Card Fraud Detection"
ORDER BY is_amount_outlier DESC;

-- Comprehensive Risk Scoring Engine
-- Integrating Findings: Late-night spikes, V14 anomalies, high frequency, and large amounts
WITH FeatureEngineering AS (
    SELECT *,
        CAST("Time" / 3600 AS INT) % 24 AS hour,
        "Time" - LAG("Time") OVER(PARTITION BY "v1", "v2" ORDER BY "Time") AS time_diff
    FROM "Credit Card Fraud Detection"
)
SELECT 
    "Class", "amount", "hour",
    (
        CASE WHEN hour BETWEEN 2 AND 5 THEN 15 ELSE 0 END + -- High-risk late-night window
        CASE WHEN "amount" > 500 THEN 10 ELSE 0 END +       -- High-value transaction risk
        CASE WHEN "v14" < -5 THEN 20 ELSE 0 END +           -- Statistical anomaly in V14
        CASE WHEN time_diff < 60 THEN 25 ELSE 0 END         -- Velocity risk: "Card Testing" (Most Critical)
    ) AS total_risk_score
FROM FeatureEngineering
ORDER BY total_risk_score DESC;
