
DROP TABLE IF EXISTS fact_churn;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_geography;
DROP TABLE IF EXISTS dim_partner;
DROP TABLE IF EXISTS dim_time;


-- Customer Dimension
CREATE TABLE dim_customer AS
SELECT DISTINCT
    customer_id,
    gender,
    age,
    num_dependents,
    estimated_salary
FROM stg_telecom_churn;

ALTER TABLE dim_customer ADD COLUMN customer_key SERIAL PRIMARY KEY;

-- Geography Dimension
CREATE TABLE dim_geography AS
SELECT DISTINCT
    state,
    city,
    pincode
FROM stg_telecom_churn;

ALTER TABLE dim_geography ADD COLUMN geo_key SERIAL PRIMARY KEY;

-- Telecom Partner Dimension
CREATE TABLE dim_partner AS
SELECT DISTINCT
    telecom_partner
FROM stg_telecom_churn;

ALTER TABLE dim_partner ADD COLUMN partner_key SERIAL PRIMARY KEY;

--  Time Dimension
CREATE TABLE dim_time AS
SELECT DISTINCT
    date_of_registration,
    EXTRACT(YEAR FROM date_of_registration)::INT AS year,
    EXTRACT(MONTH FROM date_of_registration)::INT AS month,
    EXTRACT(DAY FROM date_of_registration)::INT AS day
FROM stg_telecom_churn;

ALTER TABLE dim_time ADD COLUMN time_key SERIAL PRIMARY KEY;

-- FACT TABLE
CREATE TABLE fact_churn AS
SELECT
    c.customer_key,
    g.geo_key,
    p.partner_key,
    t.time_key,
    s.calls_made,
    s.sms_sent,
    CASE WHEN s.data_used < 0 THEN 0 ELSE s.data_used END AS data_used,
    s.churn
FROM stg_telecom_churn s
JOIN dim_customer c 
    ON s.customer_id = c.customer_id
JOIN dim_geography g 
    ON s.state = g.state 
   AND s.city = g.city 
   AND s.pincode = g.pincode
JOIN dim_partner p 
    ON s.telecom_partner = p.telecom_partner
JOIN dim_time t 
    ON s.date_of_registration = t.date_of_registration;

ALTER TABLE fact_churn ADD COLUMN fact_key SERIAL PRIMARY KEY;


-- OLAP QUERIES

--  Roll-up: Total churn by state
SELECT g.state, COUNT(*) AS churn_count
FROM fact_churn f
JOIN dim_geography g ON f.geo_key = g.geo_key
WHERE f.churn = 1
GROUP BY g.state
ORDER BY churn_count DESC;

-- Drill-down: Year → Month → Day
SELECT t.year, t.month, t.day, COUNT(*) AS churn_count
FROM fact_churn f
JOIN dim_time t ON f.time_key = t.time_key
WHERE f.churn = 1
GROUP BY t.year, t.month, t.day
ORDER BY t.year, t.month, t.day;

-- Slice: Only churned customers
SELECT *
FROM fact_churn
WHERE churn = 1;

-- Dice: Specific Partner & Low Usage
SELECT *
FROM fact_churn f
JOIN dim_partner p ON f.partner_key = p.partner_key
WHERE f.churn = 1
AND p.telecom_partner = 'Reliance Jio'
AND f.data_used < 5;

-- Top 10 churn cities
SELECT g.city, COUNT(*) AS churn_count
FROM fact_churn f
JOIN dim_geography g ON f.geo_key = g.geo_key
WHERE f.churn = 1
GROUP BY g.city
ORDER BY churn_count DESC
LIMIT 10;

-- Monthly churn view for Power BI
CREATE VIEW vw_monthly_churn AS
SELECT t.year, t.month,
       COUNT(*) AS total_customers,
       SUM(f.churn) AS churned_customers,
       ROUND( (SUM(f.churn)::NUMERIC / COUNT(*) * 100), 2) AS churn_rate_percent
FROM fact_churn f
JOIN dim_time t ON f.time_key = t.time_key
GROUP BY t.year, t.month
ORDER BY t.year, t.month;