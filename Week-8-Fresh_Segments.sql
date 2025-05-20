Data Exploration and Cleansing:
-- 1. Update the month_year column in fresh_segments.interest_metrics to be a date data type with the start of the month.
-- Update the `month_year` to be the start of the month
ALTER TABLE fresh_segments.interest_metrics
ADD COLUMN new_month_year DATE;
UPDATE fresh_segments.interest_metrics
SET new_month_year = TO_DATE(month_year, 'MM-YYYY') -- Format might change based on your actual date format
WHERE month_year IS NOT NULL;

-- Drop the old column if the new one is correct
ALTER TABLE fresh_segments.interest_metrics
DROP COLUMN month_year;

-- Rename the new column to the original column name
ALTER TABLE fresh_segments.interest_metrics
RENAME COLUMN new_month_year TO month_year;

-- 2. Count the records in fresh_segments.interest_metrics for each month_year, sorted in chronological order, with null values appearing first:
SELECT month_year, COUNT(*) AS record_count
FROM fresh_segments.interest_metrics
GROUP BY month_year
ORDER BY month_year IS NULL DESC, month_year;

-- 4. How many interest_id values exist in the fresh_segments.interest_metrics table but not in the fresh_segments.interest_map table? What about the other way around?

-- Find interest_id values in `interest_metrics` but not in `interest_map`
SELECT COUNT(DISTINCT im.interest_id)
FROM fresh_segments.interest_metrics im
LEFT JOIN fresh_segments.interest_map imap ON im.interest_id = imap.id
WHERE imap.id IS NULL;

-- Find interest_id values in `interest_map` but not in `interest_metrics`
SELECT COUNT(DISTINCT imap.id)
FROM fresh_segments.interest_map imap
LEFT JOIN fresh_segments.interest_metrics im ON imap.id = im.interest_id
WHERE im.interest_id IS NULL;

-- 5. Summarize the id values in the fresh_segments.interest_map by its total record count:
SELECT id, COUNT(*) AS total_count
FROM fresh_segments.interest_map
GROUP BY id
ORDER BY total_count DESC;

-- 6. What sort of table join should we perform for our analysis and why?
SELECT *
FROM fresh_segments.interest_metrics im
INNER JOIN fresh_segments.interest_map imap ON im.interest_id = imap.id
WHERE im.interest_id = 21246;

-- This query checks the logic for the interest_id = 21246 and includes all columns from both tables except the id column from the interest_map table.

-- 7. Are there any records in the joined table where the month_year value is before the created_at value from the interest_map table? Do you think these values are valid and why?
SELECT *
FROM fresh_segments.interest_metrics im
INNER JOIN fresh_segments.interest_map imap ON im.interest_id = imap.id
WHERE im.month_year < imap.created_at
  AND im.interest_id = 21246;

Interest Analysis:
-- 1. Which interests have been present in all month_year dates in our dataset?
-- Find the total distinct month_year values
WITH total_months AS (
    SELECT COUNT(DISTINCT month_year) AS total_months
    FROM fresh_segments.interest_metrics
),

-- Find the count of distinct month_year for each interest_id
interest_month_count AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS month_count
    FROM fresh_segments.interest_metrics
    GROUP BY interest_id
)

-- Get the interest_ids that have month_count equal to total_months
SELECT im.interest_id
FROM interest_month_count im, total_months tm
WHERE im.month_count = tm.total_months;

-- 2. Using this same total_months measure - calculate the cumulative percentage of all records starting at 14 months - which total_months value passes the 90% cumulative percentage value?
-- Find the total distinct month_year values (total_months)
WITH total_months AS (
    SELECT COUNT(DISTINCT month_year) AS total_months
    FROM fresh_segments.interest_metrics
),

-- Count the total records per interest_id
interest_record_count AS (
    SELECT interest_id, COUNT(*) AS total_records
    FROM fresh_segments.interest_metrics
    GROUP BY interest_id
),

-- Calculate the cumulative sum of records starting from 14 months
interest_month_count AS (
    SELECT interest_id, COUNT(DISTINCT month_year) AS month_count
    FROM fresh_segments.interest_metrics
    GROUP BY interest_id
    HAVING COUNT(DISTINCT month_year) >= 14
),

-- Merge everything together
cumulative_percentage AS (
    SELECT im.interest_id,
           im.month_count,
           ir.total_records,
           tm.total_months,
           SUM(ir.total_records) OVER (ORDER BY im.month_count) AS cumulative_sum,
           SUM(ir.total_records) OVER () AS total_sum,
           100 * SUM(ir.total_records) OVER (ORDER BY im.month_count) / SUM(ir.total_records) OVER () AS cumulative_percentage
    FROM interest_month_count im
    JOIN interest_record_count ir ON im.interest_id = ir.interest_id
    CROSS JOIN total_months tm
)

-- Find the month_count where cumulative percentage exceeds 90%
SELECT interest_id, month_count, cumulative_percentage
FROM cumulative_percentage
WHERE cumulative_percentage >= 90
ORDER BY month_count
LIMIT 1;