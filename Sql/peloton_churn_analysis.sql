
-- create database
CREATE DATABASE peloton_churn;

USE peloton_churn;

-- import table


SELECT COUNT(*) 
FROM subscriptions;

SELECT COUNT(*) 
FROM usages;

-- we con't get right data from usage table
SELECT
    COUNT(*) AS total_rows,
    COUNT(minutes_active) AS non_null_minutes,
    SUM(minutes_active IS NULL) AS null_minutes
FROM usages;

SHOW VARIABLES LIKE 'local_infile';

SET GLOBAL local_infile = 1;

TRUNCATE TABLE usages;

USE peloton_churn;

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/usage_fixed.csv'
INTO TABLE usages
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    customer_id,
    month,
    workouts_completed,
    @minutes_active,
    classes_booked,
    support_tickets
)
SET minutes_active = NULLIF(@minutes_active, '');


SELECT
    COUNT(*) AS total_rows,
    COUNT(minutes_active) AS non_null_minutes,
    SUM(minutes_active IS NULL) AS null_minutes
FROM usages;

-- got it data 


-- check details from both table

DESCRIBE subscriptions;

DESCRIBE usages;

-- check date formate
SELECT signup_date, churn_date
FROM subscriptions
LIMIT 10;

SELECT DISTINCT month
FROM usages
ORDER BY month;


SELECT
    signup_date,
    DATE_ADD('1899-12-30', INTERVAL signup_date DAY) AS converted_signup_date
FROM subscriptions
LIMIT 10;

SELECT
    churn_date,
    CASE
        WHEN churn_date IS NULL OR churn_date = '' THEN NULL
        ELSE DATE_ADD('1899-12-30', INTERVAL CAST(churn_date AS UNSIGNED) DAY)
    END AS converted_churn_date
FROM subscriptions
LIMIT 10;




-- convert date coulmns int to date

ALTER TABLE subscriptions
ADD COLUMN signup_date_new DATE;

SET SQL_SAFE_UPDATES = 0;

UPDATE subscriptions
SET signup_date_new = DATE_ADD('1899-12-30', INTERVAL signup_date DAY);


ALTER TABLE subscriptions
ADD COLUMN churn_date_new DATE;

UPDATE subscriptions
SET churn_date_new =
CASE
    WHEN churn_date IS NULL OR churn_date = '' THEN NULL
    ELSE DATE_ADD(
        '1899-12-30',
        INTERVAL CAST(churn_date AS UNSIGNED) DAY
    )
END;

SELECT
    signup_date,
    signup_date_new,
    churn_date,
    churn_date_new
FROM subscriptions
LIMIT 10;


-- delete Old columns 
ALTER TABLE subscriptions
DROP COLUMN signup_date,
DROP COLUMN churn_date;

-- change new columns name
ALTER TABLE subscriptions
RENAME COLUMN signup_date_new TO signup_date,
RENAME COLUMN churn_date_new TO churn_date;


-- check datatype of date columns 
DESCRIBE subscriptions;



-- primary key and foreign key establish

-- check unique customer id 
SELECT
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS non_null_ids,
    COUNT(DISTINCT customer_id) AS unique_ids
FROM subscriptions;


SELECT customer_id, COUNT(*)
FROM subscriptions
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- set primary key column customer id
ALTER TABLE subscriptions
ADD PRIMARY KEY (customer_id);


-- Whether all customer IDs of usages are available in subscriptions or not.
SELECT COUNT(*) AS unmatched_customers
FROM usages u
LEFT JOIN subscriptions s
    ON u.customer_id = s.customer_id
WHERE s.customer_id IS NULL;




-- set foreign key from usages table
ALTER TABLE usages
ADD CONSTRAINT fk_usages_subscriptions
FOREIGN KEY (customer_id)
REFERENCES subscriptions(customer_id);


SHOW CREATE TABLE usages;



-- check date column data from usages table
SELECT
    month,
    DATE_ADD('1899-12-30', INTERVAL month DAY) AS converted_month
FROM usages
LIMIT 10;

-- create new column 
ALTER TABLE usages
ADD COLUMN month_new DATE;

-- add data in new column 
UPDATE usages
SET month_new =
DATE_ADD('1899-12-30', INTERVAL month DAY);

SELECT month, month_new
FROM usages
LIMIT 10;

-- drop column month 
ALTER TABLE usages
DROP COLUMN month;

-- change new column name
ALTER TABLE usages
RENAME COLUMN month_new TO month;


SELECT
    COUNT(*) AS total_rows,
    COUNT(minutes_active) AS non_null_minutes,
    COUNT(*) - COUNT(minutes_active) AS null_minutes
FROM usages;




# ---------------------------------------------------- Exploratory Data Analysis ----------------------------------------------------------------------


SELECT 
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS churn_rate_pct,
    ROUND(SUM(churned = 'no') * 100.0 / COUNT(*), 2) AS active_pct
FROM subscriptions;



-- Which subscription plan has the highest churn rate?

SELECT 
    plan_type,
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS plan_churn_rate_pct
FROM subscriptions
GROUP BY plan_type;



-- Which acquisition channel brings customers with the highest churn rate?

SELECT 
    acquisition_channel,
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS channel_churn_rate_pct
FROM subscriptions
GROUP BY acquisition_channel
ORDER BY channel_churn_rate_pct DESC;





-- Which age group has the highest customer churn rate?

SELECT 
    age_group,
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS age_churn_rate_pct
FROM subscriptions
GROUP BY age_group
ORDER BY age_churn_rate_pct DESC;



-- Which cancel_reason has the highest customer churn rate

SELECT 
    cancel_reason,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM subscriptions WHERE churned = 'yes' AND cancel_reason IS NOT NULL), 2) AS percentage
FROM subscriptions
WHERE churned = 'yes' 
  AND cancel_reason IS NOT NULL
GROUP BY cancel_reason
ORDER BY customer_count DESC;


# ----------- Does customer engagement have a relationship with churn --------------


SELECT 
    s.churned,
    COUNT(s.customer_id) AS customer_count,
    ROUND(AVG(u.avg_workouts), 2) AS overall_avg_monthly_workouts,
    ROUND(AVG(u.avg_active_minutes), 2) AS overall_avg_monthly_minutes
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(workouts_completed) AS avg_workouts,
        AVG(minutes_active) AS avg_active_minutes
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY s.churned;


-- Does customer engagement differ across subscription plans

SELECT 
    s.plan_type,
    s.churned,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    ROUND(AVG(u.avg_workouts), 2) AS avg_monthly_workouts,
    ROUND(AVG(u.avg_minutes), 2) AS avg_monthly_minutes
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(workouts_completed) AS avg_workouts,
        AVG(minutes_active) AS avg_minutes
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY s.plan_type, s.churned
ORDER BY s.plan_type, s.churned;



-- Does customer device preference have a relationship with churn
SELECT 
    primary_device,
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS device_churn_rate_pct
FROM subscriptions
GROUP BY primary_device
ORDER BY device_churn_rate_pct DESC;





-- Does customer signup month or season have a relationship with churn
SELECT 
    LEFT(signup_date, 7) AS signup_month,
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS monthly_churn_rate_pct
FROM subscriptions
GROUP BY signup_month
ORDER BY signup_month;


-- Does plan tier have a relationship with customer churn
SELECT 
    plan_tier,
    COUNT(*) AS total_customers,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS tier_churn_rate_pct
FROM subscriptions
GROUP BY plan_tier
ORDER BY tier_churn_rate_pct DESC;


-- Does customer support activity have a relationship with churn

SELECT 
    s.churned,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    ROUND(AVG(u.avg_tickets), 3) AS avg_monthly_support_tickets
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(support_tickets) AS avg_tickets
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY s.churned;


-- Does workout frequency have a relationship with customer churn

SELECT 
    CASE 
        WHEN u.avg_workouts < 3 THEN '1. Low (<3)'
        WHEN u.avg_workouts BETWEEN 3 AND 6 THEN '2. Medium (3-6)'
        ELSE '3. High (>6)'
    END AS engagement_group,
    COUNT(s.customer_id) AS total_customers,
    SUM(s.churned = 'yes') AS churned_customers,
    ROUND(SUM(s.churned = 'yes') * 100.0 / COUNT(s.customer_id), 2) AS churn_rate_pct
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(workouts_completed) AS avg_workouts
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY engagement_group
ORDER BY engagement_group;


-- Does monthly active time have a relationship with customer churn
SELECT 
    CASE 
        WHEN u.avg_minutes < 100 THEN '1. Low Active Time (<100m)'
        WHEN u.avg_minutes BETWEEN 100 AND 200 THEN '2. Medium Active Time (100-200m)'
        ELSE '3. High Active Time (>200m)'
    END AS active_time_group,
    COUNT(s.customer_id) AS total_customers,
    SUM(s.churned = 'yes') AS churned_customers,
    ROUND(SUM(s.churned = 'yes') * 100.0 / COUNT(s.customer_id), 2) AS churn_rate_pct
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(minutes_active) AS avg_minutes
    FROM usages
    WHERE minutes_active IS NOT NULL -- Handling missing values without unjustified zero-filling
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY active_time_group
ORDER BY active_time_group;



-- Does support activity differ across acquisition channels

SELECT 
    s.acquisition_channel,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    ROUND(AVG(u.avg_tickets), 3) AS avg_monthly_support_tickets
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(support_tickets) AS avg_tickets
    FROM usages
    WHERE support_tickets IS NOT NULL
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY s.acquisition_channel
ORDER BY avg_monthly_support_tickets DESC;




-- Does average monthly workout frequency differ across acquisition channels 
SELECT 
    s.acquisition_channel,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    ROUND(AVG(u.avg_workouts), 2) AS avg_monthly_workouts,
    ROUND(AVG(u.avg_minutes), 2) AS avg_monthly_active_minutes
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(workouts_completed) AS avg_workouts,
        AVG(minutes_active) AS avg_minutes
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY s.acquisition_channel
ORDER BY avg_monthly_workouts DESC;



-- Does monthly subscription price have a relationship with customer churn
SELECT 
    monthly_price,
    COUNT(*) AS customer_count,
    SUM(churned = 'yes') AS churned_customers,
    ROUND(SUM(churned = 'yes') * 100.0 / COUNT(*), 2) AS churn_rate_pct
FROM subscriptions
GROUP BY monthly_price
ORDER BY monthly_price;






-- Does the number of classes booked relate to customer churn
SELECT 
    CASE 
        WHEN u.avg_classes < 2 THEN '1. Low Classes (<2)'
        WHEN u.avg_classes BETWEEN 2 AND 5 THEN '2. Medium Classes (2-5)'
        ELSE '3. High Classes (>5)'
    END AS class_booking_group,
    COUNT(s.customer_id) AS total_customers,
    SUM(s.churned = 'yes') AS churned_customers,
    ROUND(SUM(s.churned = 'yes') * 100.0 / COUNT(s.customer_id), 2) AS churn_rate_pct
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(classes_booked) AS avg_classes -- (agar column ka naam classes_booked hai toh wo use kar sakte hain)
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY class_booking_group
ORDER BY class_booking_group;


-- Support Tickets vs Class Booking
SELECT 
    CASE 
        WHEN u.avg_classes < 2 THEN '1. Low Classes (<2)'
        WHEN u.avg_classes BETWEEN 2 AND 5 THEN '2. Medium Classes (2-5)'
        ELSE '3. High Classes (>5)'
    END AS class_booking_group,
    COUNT(DISTINCT s.customer_id) AS customer_count,
    ROUND(AVG(u.avg_tickets), 3) AS avg_monthly_support_tickets
FROM subscriptions s
JOIN (
    SELECT 
        customer_id, 
        AVG(classes_booked) AS avg_classes,
        AVG(support_tickets) AS avg_tickets
    FROM usages
    GROUP BY customer_id
) u ON s.customer_id = u.customer_id
GROUP BY class_booking_group
ORDER BY class_booking_group;






-- Average engagement of every customer
SELECT
    customer_id,
    ROUND(AVG(workouts_completed), 2) AS avg_workouts,
    ROUND(AVG(minutes_active), 2) AS avg_active_minutes,
    ROUND(AVG(classes_booked), 2) AS avg_classes_booked
FROM usages
GROUP BY customer_id
LIMIT 10;



-- Combine customer engagement data with churn data
SELECT
    s.customer_id,
    s.churned,
    ROUND(AVG(u.workouts_completed), 2) AS avg_workouts,
    ROUND(AVG(u.minutes_active), 2) AS avg_active_minutes,
    ROUND(AVG(u.classes_booked), 2) AS avg_classes_booked
FROM subscriptions s
JOIN usages u
    ON s.customer_id = u.customer_id
GROUP BY
    s.customer_id,
    s.churned
LIMIT 10;




-- Make overall engagement groups
WITH customer_engagement AS (
    SELECT
        s.customer_id,
        s.churned,
        AVG(u.workouts_completed) AS avg_workouts
    FROM subscriptions s
    JOIN usages u
        ON s.customer_id = u.customer_id
    GROUP BY s.customer_id, s.churned
),

engagement_groups AS (
    SELECT
        customer_id,
        churned,
        CASE
            WHEN avg_workouts < 3 THEN 'Low'
            WHEN avg_workouts <= 6 THEN 'Medium'
            ELSE 'High'
        END AS engagement_group
    FROM customer_engagement
)

SELECT
    engagement_group,
    COUNT(*) AS total_customers,
    SUM(CASE WHEN churned = 'yes' THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(
        SUM(CASE WHEN churned = 'yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS churn_rate_pct
FROM engagement_groups
GROUP BY engagement_group;



-- Do customers with longer subscription tenure have different churn patterns
SELECT
    customer_id,
    signup_date,
    churn_date,
    DATEDIFF(churn_date, signup_date) AS tenure_days
FROM subscriptions
WHERE churned = 'yes'
LIMIT 10;

-- Average and Median Churn Tenure

SELECT
    COUNT(*) AS total_churned_customers,
    ROUND(AVG(DATEDIFF(churn_date, signup_date)), 2) AS avg_tenure_days,
    ROUND(
        (SELECT AVG(tenure_days)
         FROM (
             SELECT DATEDIFF(churn_date, signup_date) AS tenure_days
             FROM subscriptions
             WHERE churned = 'yes'
             ORDER BY tenure_days
             LIMIT 1768 OFFSET 883
         ) AS middle_values), 2
    ) AS median_tenure_days,
    MIN(DATEDIFF(churn_date, signup_date)) AS min_tenure_days,
    MAX(DATEDIFF(churn_date, signup_date)) AS max_tenure_days
FROM subscriptions
WHERE churned = 'yes';




WITH tenure_data AS (
    SELECT
        DATEDIFF(churn_date, signup_date) AS tenure_days
    FROM subscriptions
    WHERE churned = 'yes'
),
ranked_data AS (
    SELECT
        tenure_days,
        ROW_NUMBER() OVER (ORDER BY tenure_days) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM tenure_data
)
SELECT
    ROUND(AVG(tenure_days), 2) AS median_tenure_days
FROM ranked_data
WHERE row_num IN (
    FLOOR((total_rows + 1) / 2),
    FLOOR((total_rows + 2) / 2)
);



-- Tenure Distribution of Churned Customers

SELECT
    CASE
        WHEN DATEDIFF(churn_date, signup_date) <= 30
            THEN '1. 0-30 Days'
        WHEN DATEDIFF(churn_date, signup_date) <= 90
            THEN '2. 31-90 Days'
        WHEN DATEDIFF(churn_date, signup_date) <= 180
            THEN '3. 91-180 Days'
        WHEN DATEDIFF(churn_date, signup_date) <= 365
            THEN '4. 181-365 Days'
        ELSE '5. 365+ Days'
    END AS tenure_group,

    COUNT(*) AS customer_count,

    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*)
         FROM subscriptions
         WHERE churned = 'yes'),
        2
    ) AS customer_percentage

FROM subscriptions
WHERE churned = 'yes'
GROUP BY tenure_group
ORDER BY tenure_group;




# ------------------------ Which customer segments should Peloton prioritize for retention ------------------------



-- Plan Type + Engagement Group vs Churn

WITH customer_engagement AS (
    SELECT
        s.customer_id,
        s.plan_type,
        s.churned,
        AVG(u.workouts_completed) AS avg_workouts
    FROM subscriptions s
    JOIN usages u
        ON s.customer_id = u.customer_id
    GROUP BY
        s.customer_id,
        s.plan_type,
        s.churned
),

customer_segments AS (
    SELECT
        customer_id,
        plan_type,
        churned,
        CASE
            WHEN avg_workouts < 3 THEN 'Low'
            WHEN avg_workouts <= 6 THEN 'Medium'
            ELSE 'High'
        END AS engagement_group
    FROM customer_engagement
)

SELECT
    plan_type,
    engagement_group,
    COUNT(*) AS total_customers,

    SUM(
        CASE WHEN churned = 'yes' THEN 1 ELSE 0 END
    ) AS churned_customers,

    ROUND(
        SUM(CASE WHEN churned = 'yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS churn_rate_pct

FROM customer_segments
GROUP BY plan_type, engagement_group
ORDER BY plan_type, engagement_group;


-- Acquisition Channel + Engagement vs Churn
WITH customer_engagement AS (
    SELECT
        s.customer_id,
        s.acquisition_channel,
        s.churned,
        AVG(u.workouts_completed) AS avg_workouts
    FROM subscriptions s
    JOIN usages u
        ON s.customer_id = u.customer_id
    GROUP BY
        s.customer_id,
        s.acquisition_channel,
        s.churned
),

customer_segments AS (
    SELECT
        customer_id,
        acquisition_channel,
        churned,
        CASE
            WHEN avg_workouts < 3 THEN 'Low'
            WHEN avg_workouts <= 6 THEN 'Medium'
            ELSE 'High'
        END AS engagement_group
    FROM customer_engagement
)

SELECT
    acquisition_channel,
    engagement_group,
    COUNT(*) AS total_customers,

    SUM(
        CASE WHEN churned = 'yes' THEN 1 ELSE 0 END
    ) AS churned_customers,

    ROUND(
        SUM(CASE WHEN churned = 'yes' THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS churn_rate_pct

FROM customer_segments
GROUP BY
    acquisition_channel,
    engagement_group
ORDER BY
    acquisition_channel,
    engagement_group;



































