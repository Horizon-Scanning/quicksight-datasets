-- This CTE maps the 8-digit customs item codes to a clean, English commodity name.
WITH hs_code_commodity_mapping AS (
    -- Grains & Feeds
    SELECT '10019910' as hs_code, 'Wheat' as Commodity
    UNION ALL SELECT '10039000', 'Barley'
    UNION ALL SELECT '10041000', 'Oats'
    UNION ALL SELECT '10049000', 'Oats'
    UNION ALL SELECT '10051000', 'Corn'
    UNION ALL SELECT '10059010', 'Corn'
    UNION ALL SELECT '11010020', 'Wheat'
    UNION ALL SELECT '11010090', 'Wheat'
    UNION ALL SELECT '11022000', 'Corn'
    UNION ALL SELECT '11031100', 'Wheat'
    UNION ALL SELECT '11031300', 'Corn'
    UNION ALL SELECT '12011000', 'Soybeans'
    UNION ALL SELECT '12019000', 'Soybeans'
    UNION ALL SELECT '12081000', 'Soybeans'
    UNION ALL SELECT '23023000', 'Wheat'
    UNION ALL SELECT '23031000', 'Corn'
    UNION ALL SELECT '23033000', 'DDG/DDGS'
    UNION ALL SELECT '23040000', 'Soybeans'
    UNION ALL SELECT '23063000', 'Sunflower Oil'
    UNION ALL SELECT '23064900', 'Rapeseed'

    -- Oils, Sugar, Pasta
    UNION ALL SELECT '15079010', 'Soybeans'
    UNION ALL SELECT '15121111', 'Sunflower Oil'
    UNION ALL SELECT '15121990', 'Sunflower Oil'
    UNION ALL SELECT '15121922', 'Sunflower Oil'
    UNION ALL SELECT '15121929', 'Sunflower Oil'
    UNION ALL SELECT '15141910', 'Canola'
    UNION ALL SELECT '15149911', 'Canola'
    UNION ALL SELECT '15149990', 'Canola'
    UNION ALL SELECT '15141900', 'Canola'
    UNION ALL SELECT '12051090', 'Rapeseed'
    UNION ALL SELECT '17019910', 'Sugar'
    UNION ALL SELECT '17011400', 'Sugar'
    UNION ALL SELECT '19021900', 'Pasta'
    UNION ALL SELECT '19023000', 'Pasta'
    UNION ALL SELECT '19043000', 'Bulgur'

    -- Energy Products
    UNION ALL SELECT '27090090', 'Crude Oil (WTI)'
    UNION ALL SELECT '27090000', 'Brent'
    UNION ALL SELECT '27101210', 'Gasoline'
    UNION ALL SELECT '27101211', 'Gasoline'
    UNION ALL SELECT '27101219', 'Gasoline'
    UNION ALL SELECT '27101960', 'Diesel'
    UNION ALL SELECT '27101963', 'Diesel'
    UNION ALL SELECT '27101964', 'Diesel'
    UNION ALL SELECT '27101965', 'Diesel'
    UNION ALL SELECT '27101979', 'Diesel'
    UNION ALL SELECT '27101930', 'Jet Fuel'
    UNION ALL SELECT '27101939', 'Jet Fuel'
    UNION ALL SELECT '27101931', 'Jet Fuel'
    UNION ALL SELECT '27111200', 'LPG'
    UNION ALL SELECT '27111300', 'LPG'
    UNION ALL SELECT '27111900', 'LPG'
    -- Legumes
    UNION ALL SELECT '07131000', 'Peas'
    UNION ALL SELECT '07132000', 'Chickpeas'
    UNION ALL SELECT '07134000', 'Lentils'
    UNION ALL SELECT '07135000', 'Broad beans'
),

-- Step 1: Create a definitive list of ALL commodities.
AllCommodities AS (
    SELECT 'Sunflower Oil' as Commodity
    UNION SELECT 'Other Vegetable Oils'
    UNION SELECT 'Barley'
    UNION SELECT 'Buckwheat'
    UNION SELECT 'Cereals'
    UNION SELECT 'Corn'
    UNION SELECT 'Oats'
    UNION SELECT 'Pasta'
    UNION SELECT 'Potato'
    UNION SELECT 'Rapeseed'
    UNION SELECT 'Rice'
    UNION SELECT 'Sugar'
    UNION SELECT 'Tuna'
    UNION SELECT 'Wheat'
    UNION SELECT 'Brent'
    UNION SELECT 'Crude Oil (WTI)'
    UNION SELECT 'Gasoline'
    UNION SELECT Commodity FROM hs_code_commodity_mapping
),

-- Step 2: Get all unique year/month periods from the data.
AllMonths AS (
    SELECT DISTINCT year, month
    FROM shippingbi.israel_customs_data
),

-- Step 3: Create a scaffold: a row for every commodity for every month.
CommodityMonthScaffold AS (
    SELECT c.Commodity, m.year, m.month
    FROM AllCommodities c
    CROSS JOIN AllMonths m
),

-- Step 4 (Original): Calculate the actual import quantities by month.
AggregatedImports AS (
    SELECT
        d.year,
        d.month,
        COALESCE(
            CASE
                WHEN d.category = 'sunflower' THEN 'Sunflower Oil'
                WHEN d.category = 'other vegetable oils' THEN 'Other Vegetable Oils'
                WHEN d.category = 'barley' THEN 'Barley'
                WHEN d.category = 'buckwheat' THEN 'Buckwheat'
                WHEN d.category = 'cereals' THEN 'Cereals'
                WHEN d.category = 'corn' THEN 'Corn'
                WHEN d.category = 'oats' THEN 'Oats'
                WHEN d.category = 'pasta' THEN 'Pasta'
                WHEN d.category = 'potato' THEN 'Potato'
                WHEN d.category = 'rapeseed' THEN 'Rapeseed'
                WHEN d.category = 'rice' THEN 'Rice'
                WHEN d.category = 'sugar' THEN 'Sugar'
                WHEN d.category = 'tuna' THEN 'Tuna'
                WHEN d.category = 'wheat' THEN 'Wheat'
                WHEN d.category = 'crude_oil_wti' THEN 'Crude Oil (WTI)'
                WHEN d.category = 'baby formula' THEN 'Baby Formula'
                ELSE NULL
            END,
            hsm.Commodity
        ) AS Commodity,
        SUM(CAST(d.quantity AS DOUBLE)) as total_quantity
    FROM
        shippingbi.israel_customs_data AS d
    LEFT JOIN
        hs_code_commodity_mapping AS hsm ON CAST(d.customsitem_8_digits AS VARCHAR) = hsm.hs_code
    WHERE COALESCE(
            CASE
                WHEN d.category = 'sunflower' THEN 'Sunflower Oil'
                WHEN d.category = 'other vegetable oils' THEN 'Other Vegetable Oils'
                WHEN d.category = 'barley' THEN 'Barley'
                WHEN d.category = 'buckwheat' THEN 'Buckwheat'
                WHEN d.category = 'cereals' THEN 'Cereals'
                WHEN d.category = 'corn' THEN 'Corn'
                WHEN d.category = 'oats' THEN 'Oats'
                WHEN d.category = 'pasta' THEN 'Pasta'
                WHEN d.category = 'potato' THEN 'Potato'
                WHEN d.category = 'rapeseed' THEN 'Rapeseed'
                WHEN d.category = 'rice' THEN 'Rice'
                WHEN d.category = 'sugar' THEN 'Sugar'
                WHEN d.category = 'tuna' THEN 'Tuna'
                WHEN d.category = 'wheat' THEN 'Wheat'
                WHEN d.category = 'crude_oil_wti' THEN 'Crude Oil (WTI)'
                ELSE NULL
            END,
            hsm.Commodity
        ) IS NOT NULL
    GROUP BY 1, 2, 3
),

-- Step 4 (New): Use the aggregated data and duplicate WTI data for Brent
MonthlyImports AS (
    SELECT
        year,
        month,
        Commodity,
        total_quantity
    FROM
        AggregatedImports
    UNION ALL
    SELECT
        year,
        month,
        'Brent' as Commodity,
        total_quantity
    FROM
        AggregatedImports
    WHERE
        Commodity = 'Crude Oil (WTI)'
),

-- Step 5: Join the scaffold with the actual data and calculate the 12-month moving average.
ComparisonData AS (
    SELECT
        s.year,
        s.month,
        s.Commodity,
        COALESCE(i.total_quantity, 0) AS current_month_quantity,
        -- Calculate the average of the previous 12 months
        AVG(COALESCE(i.total_quantity, 0)) OVER (
            PARTITION BY s.Commodity
            ORDER BY s.year, s.month
            ROWS BETWEEN 12 PRECEDING AND 1 PRECEDING
        ) AS avg_previous_12_months_quantity
    FROM
        CommodityMonthScaffold s
    LEFT JOIN
        MonthlyImports i ON s.Commodity = i.Commodity AND s.year = i.year AND s.month = i.month
)

-- Final step: Calculate the Score against the 12-month average and add the month number.
SELECT
    year,
    month,
    DENSE_RANK() OVER (ORDER BY year DESC, month DESC) as month_number,
    Commodity,
    CAST(current_month_quantity AS BIGINT) AS current_month_quantity,
    CAST(avg_previous_12_months_quantity AS BIGINT) AS avg_previous_12_months_quantity,
    CASE
        -- Check if the average is not null and is large enough
        WHEN avg_previous_12_months_quantity IS NOT NULL AND avg_previous_12_months_quantity >= 10000
        THEN ((current_month_quantity - avg_previous_12_months_quantity) * 100.0 / avg_previous_12_months_quantity)
        ELSE 0
    END AS "Israel Imports Score (vs 12m Avg %)"
FROM
    ComparisonData
WHERE
    avg_previous_12_months_quantity IS NOT NULL -- Only include rows where an average could be calculated
ORDER BY
    Commodity,
    year DESC,
    month DESC