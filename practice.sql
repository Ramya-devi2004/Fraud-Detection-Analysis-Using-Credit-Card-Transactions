CREATE DATABASE fraud_detection;
USE fraud_detection;
CREATE TABLE transactions (
    trans_date_trans_time DATETIME,
    cc_num          BIGINT,
    merchant         VARCHAR(60),
    category         VARCHAR(20),
    amt              DECIMAL(10,2),
    first            VARCHAR(30),
    last             VARCHAR(30),
    gender           CHAR(1),
    city             VARCHAR(30),
    state            CHAR(2),
    zip              INT,
    lat              DECIMAL(9,6),
    `long`           DECIMAL(9,6),
    city_pop         INT,
    job              VARCHAR(70),
    dob              DATE,
    trans_num        VARCHAR(40) PRIMARY KEY,
    merch_lat        DECIMAL(9,6),
    merch_long       DECIMAL(9,6),
    is_fraud         TINYINT,
    trans_month      TINYINT,
    trans_day        TINYINT,
    trans_hour       TINYINT,
    trans_weekday    VARCHAR(10),
    customer_age     TINYINT,
    amount_range     VARCHAR(10)
);
DROP TABLE transactions;
LOAD DATA LOCAL INFILE"D:\Insight\fraud_cleaned.csv"
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
SET GLOBAL local_infile = 1;
SHOW TABLES;

select count(*) from transactions;
-- count of fraud and genuine
SELECT is_fraud, COUNT(*) FROM transactions GROUP BY is_fraud;
-- Q1 — See what fraud actually looks like
SELECT trans_date_trans_time, merchant, category, amt, city, state
FROM transactions
WHERE is_fraud = 1
LIMIT 20;
#High-value fraud only
SELECT trans_num, merchant, amt, trans_date_trans_time
FROM transactions
WHERE is_fraud = 1 AND amt > 500
ORDER BY amt DESC;
-- Fraud in a specific state
SELECT * FROM transactions
WHERE is_fraud = 1 AND state = 'NY'
ORDER BY trans_date_trans_time DESC;
-- Q4 — Night-time fraud (multiple conditions)
SELECT trans_num, merchant, amt, trans_hour
FROM transactions
WHERE is_fraud = 1 AND (trans_hour >= 22 OR trans_hour <= 3)
ORDER BY amt DESC;
--  Genuine transactions that still look "risky" (large amount, not flagged)
SELECT trans_num, merchant, amt
FROM transactions
WHERE is_fraud = 0 AND amt > 1000
ORDER BY amt DESC
LIMIT 20;
-- Q6 — Fraud rate by category
SELECT category,
       COUNT(*) AS total_txns,
       SUM(is_fraud) AS fraud_count,
       ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
FROM transactions
GROUP BY category
ORDER BY fraud_rate_pct DESC;
-- Q7 — States with meaningful fraud volume
SELECT state, COUNT(*) AS fraud_cases
FROM transactions
WHERE is_fraud = 1
GROUP BY state
HAVING COUNT(*) > 100
ORDER BY fraud_cases DESC;
-- Monthly fraud trend
SELECT trans_month,
       COUNT(*) AS total_txns,
       SUM(is_fraud) AS fraud_count,
       ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
FROM transactions
GROUP BY trans_month
ORDER BY trans_month;
-- Fraud by day of week
SELECT trans_weekday, COUNT(*) AS fraud_count
FROM transactions
WHERE is_fraud = 1
GROUP BY trans_weekday
ORDER BY fraud_count DESC;
-- Merchants with unusually high fraud rate
SELECT merchant,
       COUNT(*) AS total_txns,
       SUM(is_fraud) AS fraud_count,
       ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
FROM transactions
GROUP BY merchant
HAVING COUNT(*) > 50
ORDER BY fraud_rate_pct DESC
LIMIT 15;
-- Risk category based on amount
SELECT trans_num, amt,
CASE
    WHEN amt <= 100 THEN 'Low Risk'
    WHEN amt > 100 AND amt <= 500 THEN 'Medium Risk'
    ELSE 'High Risk'
END AS risk_level
FROM transactions;
-- Fraud rate by the risk category we just created
SELECT
CASE
    WHEN amt <= 100 THEN 'Low Risk'
    WHEN amt > 100 AND amt <= 500 THEN 'Medium Risk'
    ELSE 'High Risk'
END AS risk_level,
COUNT(*) AS total_txns,
SUM(is_fraud) AS fraud_count,
ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
FROM transactions
GROUP BY risk_level
ORDER BY fraud_rate_pct DESC;
-- Time-of-day segment
SELECT trans_num, trans_hour,
CASE
    WHEN trans_hour BETWEEN 6 AND 11 THEN 'Morning'
    WHEN trans_hour BETWEEN 12 AND 17 THEN 'Afternoon'
    WHEN trans_hour BETWEEN 18 AND 21 THEN 'Evening'
    ELSE 'Night'
END AS time_segment
FROM transactions;
-- Age group segment via CASE
SELECT
CASE
    WHEN customer_age < 30 THEN 'Under 30'
    WHEN customer_age BETWEEN 30 AND 50 THEN '30-50'
    WHEN customer_age BETWEEN 51 AND 65 THEN '51-65'
    ELSE '65+'
END AS age_group,
COUNT(*) AS total_txns,
SUM(is_fraud) AS fraud_count,
ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
FROM transactions
GROUP BY age_group
ORDER BY fraud_rate_pct DESC;
-- transactions above the overall average amount
SELECT trans_num, amt, is_fraud
FROM transactions
WHERE amt > (SELECT AVG(amt) FROM transactions)
ORDER BY amt DESC
LIMIT 20;
-- fraud summary per category, reused twice
WITH category_summary AS (
    SELECT category,
           COUNT(*) AS total_txns,
           SUM(is_fraud) AS fraud_count
    FROM transactions
    GROUP BY category
)
SELECT category, total_txns, fraud_count,
       ROUND(fraud_count/total_txns*100, 2) AS fraud_rate_pct
FROM category_summary
ORDER BY fraud_rate_pct DESC;
-- only categories with above-average fraud rate
WITH category_rates AS (
    SELECT category,
           ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
    FROM transactions
    GROUP BY category
)
SELECT * FROM category_rates
WHERE fraud_rate_pct > (SELECT AVG(fraud_rate_pct) FROM category_rates)
ORDER BY fraud_rate_pct DESC;
-- (same cc_num with 2+ fraud cases)
WITH card_fraud_counts AS (
    SELECT cc_num, COUNT(*) AS fraud_count
    FROM transactions
    WHERE is_fraud = 1
    GROUP BY cc_num
)
SELECT * FROM card_fraud_counts
WHERE fraud_count >= 2
ORDER BY fraud_count DESC;
-- Rank merchants by fraud count within each category
SELECT category, merchant, fraud_count,
       RANK() OVER (PARTITION BY category ORDER BY fraud_count DESC) AS rank_in_category
FROM (
    SELECT category, merchant, SUM(is_fraud) AS fraud_count
    FROM transactions
    GROUP BY category, merchant
) AS merchant_fraud
WHERE fraud_count > 0;
-- Running total of fraud amount by month
SELECT trans_month,
       SUM(amt) AS monthly_fraud_amt,
       SUM(SUM(amt)) OVER (ORDER BY trans_month) AS running_total
FROM transactions
WHERE is_fraud = 1
GROUP BY trans_month
ORDER BY trans_month;
-- Each fraud transaction's % share of total fraud amount
SELECT trans_num, amt,
       ROUND(amt / SUM(amt) OVER () * 100, 3) AS pct_of_total_fraud
FROM transactions
WHERE is_fraud = 1
ORDER BY pct_of_total_fraud DESC
LIMIT 20;
-- Compare each state's fraud count to the national average (window function without grouping rows away)
SELECT state, fraud_count,
       ROUND(AVG(fraud_count) OVER (), 1) AS avg_fraud_all_states,
       fraud_count - ROUND(AVG(fraud_count) OVER (), 1) AS diff_from_avg
FROM (
    SELECT state, COUNT(*) AS fraud_count
    FROM transactions
    WHERE is_fraud = 1
    GROUP BY state
) AS state_fraud
ORDER BY diff_from_avg DESC;
-- find same card used twice within the same day (possible fraud pattern)
SELECT a.cc_num, a.trans_num AS txn_1, b.trans_num AS txn_2,
       a.trans_date_trans_time AS time_1, b.trans_date_trans_time AS time_2
FROM transactions a
JOIN transactions b
  ON a.cc_num = b.cc_num
  AND a.trans_num <> b.trans_num
  AND DATE(a.trans_date_trans_time) = DATE(b.trans_date_trans_time)
WHERE a.is_fraud = 1 AND b.is_fraud = 1
LIMIT 20;
-- 
-- Step 1: create a tiny region lookup table
CREATE TABLE state_region (
    state CHAR(2),
    region VARCHAR(20)
);

INSERT INTO state_region VALUES
('NY','Northeast'), ('PA','Northeast'), ('TX','South'),
('CA','West'), ('FL','South'), ('IL','Midwest');
-- (add more states as needed)

-- Step 2: join transactions to this lookup table
CREATE TABLE state_region (
    state CHAR(2),
    region VARCHAR(20)
);
INSERT INTO state_region VALUES
('NY','Northeast'), ('PA','Northeast'), ('TX','South'),
('CA','West'), ('FL','South'), ('IL','Midwest');
SELECT t.state, s.region, COUNT(*) AS fraud_count
FROM transactions t
JOIN state_region s ON t.state = s.state
WHERE t.is_fraud = 1
GROUP BY t.state, s.region
ORDER BY fraud_count DESC;
CREATE VIEW fraud_summary_view AS
SELECT category, state, trans_month, trans_hour,
       amount_range, gender,
       COUNT(*) AS total_txns,
       SUM(is_fraud) AS fraud_count,
       ROUND(SUM(is_fraud)/COUNT(*)*100, 2) AS fraud_rate_pct
FROM transactions
GROUP BY category, state, trans_month, trans_hour, amount_range, gender;