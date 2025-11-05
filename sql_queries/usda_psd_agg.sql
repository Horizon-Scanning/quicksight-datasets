-- Step 1.A: Prepare JODI data by selecting all necessary components for calculation.
WITH jodi_prepared AS (
    SELECT
        CASE
            WHEN energy_product = 'CRUDEOIL' THEN 'Crude Oil'
            WHEN energy_product = 'JETKERO' THEN 'Jet Fuel'
            WHEN energy_product = 'GASDIES' THEN 'Diesel'
            WHEN energy_product = 'LPG' THEN 'LPG'
            WHEN energy_product = 'GASOLINE' THEN 'Gasoline'
        END AS commodity_description,
        ref_area AS country_name,
        TRY(CAST(date_parse(date, '%d/%m/%Y') AS DATE)) AS report_date,
        flow_breakdown,
        energy_product,
        CAST(obs_value AS DOUBLE) AS value
    FROM shippingbi.jodi_oil_data
    WHERE
        obs_value IS NOT NULL
        AND unit_description LIKE 'Thousand Barrels per day%'
        AND TRY(CAST(date_parse(date, '%d/%m/%Y') AS DATE)) >= DATE '2024-01-01'
        AND energy_product IN ('CRUDEOIL', 'JETKERO', 'GASDIES', 'LPG', 'GASOLINE')
        AND flow_breakdown IN (
            'INDPROD',
            'REFGROUT',
            'TOTIMPSB',
            'STOCKCH',
            'OSOURCES',
            'TOTDEMO'
        )
),
jodi_aggregated AS (
    SELECT
        commodity_description,
        country_name,
        report_date,
        SUM(
            CASE
                WHEN energy_product = 'CRUDEOIL' AND flow_breakdown = 'INDPROD' THEN value
                WHEN energy_product <> 'CRUDEOIL' AND flow_breakdown = 'REFGROUT' THEN value
                ELSE 0
            END
        ) AS production_val,
        SUM(CASE WHEN flow_breakdown = 'TOTDEMO' THEN value ELSE 0 END) AS domestic_consumption_val,
        (
            SUM(
                CASE
                    WHEN energy_product = 'CRUDEOIL' AND flow_breakdown = 'INDPROD' THEN value
                    WHEN energy_product <> 'CRUDEOIL' AND flow_breakdown = 'REFGROUT' THEN value
                    ELSE 0
                END
            ) +
            SUM(CASE WHEN flow_breakdown = 'TOTIMPSB' THEN value ELSE 0 END) +
            SUM(CASE WHEN flow_breakdown = 'STOCKCH' THEN value ELSE 0 END)
        ) AS total_supply_val
    FROM jodi_prepared
    GROUP BY 1, 2, 3
),
jodi_unpivoted AS (
    SELECT commodity_description, country_name, report_date, 'Production' AS attribute_description, production_val AS value FROM jodi_aggregated
    UNION ALL
    SELECT commodity_description, country_name, report_date, 'Domestic Consumption' AS attribute_description, domestic_consumption_val AS value FROM jodi_aggregated
    UNION ALL
    SELECT commodity_description, country_name, report_date, 'Total Supply' AS attribute_description, total_supply_val AS value FROM jodi_aggregated
),
CombinedData AS (
    SELECT 
        commodity_description, 
        country_name, 
        COALESCE(
            TRY(CAST(date_parse(curr_date, '%Y-%m-%d') AS DATE)),
            TRY(CAST(date_parse(curr_date, '%m/%d/%Y') AS DATE)),
            TRY(CAST(date_parse(curr_date, '%d/%m/%Y') AS DATE))
        ) as report_date, 
        attribute_description, 
        value
    FROM shippingbi.usda_psd_table
    WHERE attribute_description IN ('Domestic Consumption', 'Production', 'Total Supply')
        AND COALESCE(
            TRY(CAST(date_parse(curr_date, '%Y-%m-%d') AS DATE)),
            TRY(CAST(date_parse(curr_date, '%m/%d/%Y') AS DATE)),
            TRY(CAST(date_parse(curr_date, '%d/%m/%Y') AS DATE))
        ) >= DATE '2024-01-01'
    UNION ALL
    SELECT 
        commodity_description, 
        country_name, 
        report_date, 
        attribute_description, 
        value
    FROM jodi_unpivoted
),
DataWithRanking AS (
    SELECT
        *,
        DENSE_RANK() OVER (PARTITION BY commodity_description ORDER BY report_date DESC) AS month_num
    FROM CombinedData
),
AggregatedData AS (
    SELECT
        commodity_description,
        report_date,
        month_num,
        SUM(CASE WHEN attribute_description = 'Domestic Consumption' THEN value ELSE 0 END) AS sum_domestic_consumption,
        SUM(CASE WHEN attribute_description = 'Production' THEN value ELSE 0 END) AS sum_production,
        SUM(CASE WHEN attribute_description = 'Total Supply' THEN value ELSE 0 END) AS sum_total_supply
    FROM DataWithRanking
    GROUP BY commodity_description, report_date, month_num
),
DataWithAvg AS (
    SELECT
        *,
        AVG(sum_total_supply) OVER (
            PARTITION BY commodity_description 
            ORDER BY report_date
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS avg_previous_3_months
    FROM AggregatedData
)
SELECT
    commodity_description,
    month_num,
    CAST(report_date AS TIMESTAMP) AS report_date,
    sum_domestic_consumption AS domestic_consumption,
    sum_production AS production,
    sum_total_supply AS total_supply,
    (sum_total_supply - sum_domestic_consumption) AS supply_consumption,
    CASE
        WHEN month_num = 1 AND avg_previous_3_months IS NOT NULL AND avg_previous_3_months <> 0 THEN
            ((sum_total_supply / NULLIF(avg_previous_3_months, 0.0)) - 1) * 100
        ELSE NULL
    END AS score
FROM 
    DataWithAvg
ORDER BY 
    commodity_description,
    report_date DESC