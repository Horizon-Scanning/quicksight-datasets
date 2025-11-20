WITH combined_index_raw_data AS (
    -- This CTE is unchanged
    SELECT CAST('BAID' AS VARCHAR) as symbol, DATE_PARSE(date, '%d/%m/%Y') as parsed_date, CAST(price AS DOUBLE) as index_value, CAST('Baltic Dirty Tanker' AS VARCHAR) as full_commodity_name FROM shippingbi.baid_history
    UNION ALL
    SELECT CAST('BCTI' AS VARCHAR) as symbol, DATE_PARSE(date, '%d/%m/%Y') as parsed_date, CAST(price AS DOUBLE) as index_value, CAST('Baltic Clean Tanker' AS VARCHAR) as full_commodity_name FROM shippingbi.bcti_history
    UNION ALL
    SELECT CAST(symbol AS VARCHAR) as symbol, DATE_PARSE(date, '%d/%m/%Y') as parsed_date, COALESCE(CAST(REPLACE(CAST(open AS VARCHAR), ',', '') AS DOUBLE), CAST(REPLACE(CAST(close AS VARCHAR), ',', '') AS DOUBLE)) as index_value, CAST(commodity AS VARCHAR) as full_commodity_name FROM shippingbi.te_index_history
),

index_data AS (
    -- This CTE is unchanged
    SELECT cird.parsed_date, cird.symbol, cird.index_value AS open,
        CASE
            WHEN cird.full_commodity_name = 'Baltic Dirty Tanker' THEN 'baltic_dirty_tanker'
            WHEN cird.full_commodity_name = 'Baltic Clean Tanker' THEN 'baltic_clean_tanker'
            WHEN cird.full_commodity_name = 'baltic' THEN 'baltic_dry_index'
            WHEN cird.full_commodity_name = 'contain' THEN 'containerized_freight'
            ELSE NULL
        END AS commodity
    FROM combined_index_raw_data cird
    WHERE
        CASE
            WHEN cird.full_commodity_name = 'Baltic Dirty Tanker' THEN 'baltic_dirty_tanker'
            WHEN cird.full_commodity_name = 'Baltic Clean Tanker' THEN 'baltic_clean_tanker'
            WHEN cird.full_commodity_name = 'baltic' THEN 'baltic_dry_index'
            WHEN cird.full_commodity_name = 'contain' THEN 'containerized_freight'
            ELSE NULL
        END IN ('baltic_dirty_tanker', 'baltic_clean_tanker', 'baltic_dry_index', 'containerized_freight')
        AND cird.index_value IS NOT NULL
),

date_limits AS (
    -- Using 7-day periods for Week-over-Week
    SELECT current_date AS today, date_add('day', -7, current_date) AS seven_days_ago, date_add('day', -14, current_date) AS fourteen_days_ago
),

normalized_indices AS (
    -- This CTE is unchanged
    SELECT id.parsed_date, id.commodity, id.open,
        (id.open - MIN(id.open) OVER (PARTITION BY id.commodity)) / NULLIF((MAX(id.open) OVER (PARTITION BY id.commodity) - MIN(id.open) OVER (PARTITION BY id.commodity)), 0) AS normalized_value,
        CASE
            WHEN id.parsed_date >= dl.seven_days_ago THEN 'last_7'
            WHEN id.parsed_date >= dl.fourteen_days_ago THEN 'prior_7'
            ELSE 'older'
        END AS time_period
    FROM index_data id
    CROSS JOIN date_limits dl
),

commodity_weights AS (
    -- This CTE is unchanged
    SELECT 'Canola' AS commodity_name, 0.0 AS baltic_dirty_tanker_weight, 0.0 AS baltic_clean_tanker_weight, 0.2 AS baltic_dry_index_weight, 0.8 AS containerized_freight_weight
    UNION ALL SELECT 'Corn', 0.0, 0.0, 0.8, 0.2
    UNION ALL SELECT 'Rapeseed', 0.0, 0.0, 0.6, 0.4
    UNION ALL SELECT 'Rice', 0.0, 0.0, 0.5, 0.5
    UNION ALL SELECT 'Soybeans', 0.0, 0.0, 0.7, 0.3
    UNION ALL SELECT 'Sugar', 0.0, 0.0, 0.4, 0.6
    UNION ALL SELECT 'Sunflower Oil', 0.0, 0.3, 0.0, 0.7
    UNION ALL SELECT 'Wheat', 0.0, 0.0, 0.8, 0.2
    UNION ALL SELECT 'Barley', 0.0, 0.0, 0.75, 0.25
    UNION ALL SELECT 'Oat', 0.0, 0.0, 0.7, 0.3
    UNION ALL SELECT 'Brent', 0.7, 0.3, 0.0, 0.0
    UNION ALL SELECT 'Crude Oil', 0.8, 0.2, 0.0, 0.0
    UNION ALL SELECT 'Gasoline', 0.2, 0.8, 0.0, 0.0
    UNION ALL SELECT 'LPG', 0.1, 0.6, 0.0, 0.3
    UNION ALL SELECT 'Diesel', 0.2, 0.8, 0.0, 0.0
    UNION ALL SELECT 'Jet Fuel', 0.1, 0.9, 0.0, 0.0
    UNION ALL SELECT 'Cobalt', 0.0, 0.0, 0.2, 0.8
    UNION ALL SELECT 'Gallium', 0.0, 0.0, 0.0, 1.0
    UNION ALL SELECT 'Lithium', 0.0, 0.0, 0.2, 0.8
    UNION ALL SELECT 'Nickel', 0.0, 0.0, 0.5, 0.5
    UNION ALL SELECT 'Urea', 0.0, 0.0, 0.7, 0.3
    UNION ALL SELECT 'Bitumen', 0.9, 0.1, 0.0, 0.0
    UNION ALL SELECT 'Cement', 0.0, 0.0, 0.7, 0.3
    UNION ALL SELECT 'Concrete', 0.0, 0.0, 1.0, 0.0
    UNION ALL SELECT 'Steel', 0.0, 0.0, 0.5, 0.5
    UNION ALL SELECT 'Iron Ore', 0.0, 0.0, 0.9, 0.1 
),

raw_index_averages AS (
    -- This CTE is unchanged
    SELECT commodity, AVG(CASE WHEN time_period = 'last_7' THEN normalized_value END) as last_7_norm_avg, AVG(CASE WHEN time_period = 'prior_7' THEN normalized_value END) as prior_7_norm_avg
    FROM normalized_indices
    WHERE time_period IN ('last_7', 'prior_7')
    GROUP BY commodity
),

raw_index_momentum AS (
    -- This CTE is unchanged
    SELECT commodity, ((last_7_norm_avg - prior_7_norm_avg) / NULLIF(prior_7_norm_avg, 0)) * 100 as pct_change
    FROM raw_index_averages
),

pivoted_momentum AS (
    -- CORRECTED LOGIC
    SELECT
        1 as join_key,
        MAX(CASE WHEN commodity = 'baltic_dirty_tanker' THEN pct_change ELSE NULL END) AS dirty_tanker_momentum,
        MAX(CASE WHEN commodity = 'baltic_clean_tanker' THEN pct_change ELSE NULL END) AS clean_tanker_momentum,
        MAX(CASE WHEN commodity = 'baltic_dry_index' THEN pct_change ELSE NULL END) AS dry_index_momentum,
        MAX(CASE WHEN commodity = 'containerized_freight' THEN pct_change ELSE NULL END) AS containerized_freight_momentum
    FROM raw_index_momentum
),

final_scores AS (
    -- This CTE is unchanged
    SELECT
        cw.commodity_name,
        (COALESCE(pm.dirty_tanker_momentum, 0) * cw.baltic_dirty_tanker_weight) +
        (COALESCE(pm.clean_tanker_momentum, 0) * cw.baltic_clean_tanker_weight) +
        (COALESCE(pm.dry_index_momentum, 0) * cw.baltic_dry_index_weight) +
        (COALESCE(pm.containerized_freight_momentum, 0) * cw.containerized_freight_weight) AS weighted_percent_change
    FROM
        commodity_weights cw
    JOIN
        pivoted_momentum pm ON 1=1
)

SELECT
    commodity_name,
    1 + ((weighted_percent_change * -1) / 100.0) AS last_7_avg_score,
    1.0 AS prior_7_avg_score,
    weighted_percent_change * -1 AS score_change,
    weighted_percent_change * -1 AS percent_change
FROM
    final_scores
ORDER BY
    percent_change DESC