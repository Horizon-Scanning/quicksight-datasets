SELECT
    *,
    CASE
        WHEN score IS NULL              THEN NULL
        WHEN score < -80               THEN 'Red Node'
        WHEN score <= -5               THEN 'Red'
        WHEN score <= 0                THEN 'Yellow'
        ELSE                                'Green'
    END AS status_color
FROM (
    WITH all_commodities AS (
        SELECT commodity_name FROM (VALUES
            ('Barley'),
            ('Canola'),
            ('Corn'),
            ('Oat'),
            ('Rapeseed'),
            ('Rice'),
            ('Soybeans'),
            ('Sugar'),
            ('Sunflower Oil'),
            ('Wheat'),
            ('Brent'),
            ('Crude Oil (WTI)'),
            ('Diesel'),
            ('Gasoline'),
            ('Jet Fuel'),
            ('LPG'),
            ('Bitumen'),
            ('Cement'),
            ('Concrete'),
            ('Iron Ore'),
            ('Steel'),
            ('Urea')
        ) AS t(commodity_name)
    ),
    jodi_prepared AS (
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
            AND flow_breakdown IN ('INDPROD', 'REFGROUT', 'TOTIMPSB', 'STOCKCH', 'OSOURCES', 'TOTDEMO')
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
    te_production_prepared AS (
        SELECT
            CASE
                WHEN category = 'Cement Production' THEN 'Cement'
                WHEN category = 'Steel Production' THEN 'Steel'
                ELSE category
            END AS commodity_description,
            country AS country_name,
            DATE_TRUNC('month', COALESCE(
                TRY(CAST(date_parse(datetime, '%d/%m/%Y') AS DATE)),
                TRY(CAST(date_parse(datetime, '%Y-%m-%d') AS DATE)),
                TRY(CAST(datetime AS DATE))
            )) AS report_date,
            CAST(value AS DOUBLE) AS value
        FROM shippingbi.te_supply_demand_commodity_production
        WHERE
            category IN ('Cement Production', 'Steel Production')
            AND value IS NOT NULL
            AND COALESCE(
                TRY(CAST(date_parse(datetime, '%d/%m/%Y') AS DATE)),
                TRY(CAST(date_parse(datetime, '%Y-%m-%d') AS DATE)),
                TRY(CAST(datetime AS DATE))
            ) >= DATE '2024-01-01'
    ),
    te_unpivoted AS (
        SELECT commodity_description, country_name, report_date, 'Production' AS attribute_description, SUM(value) AS value
        FROM te_production_prepared
        GROUP BY commodity_description, country_name, report_date
        UNION ALL
        SELECT commodity_description, country_name, report_date, 'Total Supply' AS attribute_description, SUM(value) AS value
        FROM te_production_prepared
        GROUP BY commodity_description, country_name, report_date
    ),
    CombinedDataRaw AS (
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
        SELECT commodity_description, country_name, report_date, attribute_description, value FROM jodi_unpivoted
        UNION ALL
        SELECT commodity_description, country_name, report_date, attribute_description, value FROM te_unpivoted
    ),
    CombinedDataExpanded AS (
        SELECT commodity_description, country_name, report_date, attribute_description, value, CAST(NULL AS VARCHAR) AS oil_variant
        FROM CombinedDataRaw
        WHERE commodity_description <> 'Crude Oil'
        UNION ALL
        SELECT commodity_description, country_name, report_date, attribute_description, value, 'Brent' AS oil_variant
        FROM CombinedDataRaw
        WHERE commodity_description = 'Crude Oil'
        UNION ALL
        SELECT commodity_description, country_name, report_date, attribute_description, value, 'WTI' AS oil_variant
        FROM CombinedDataRaw
        WHERE commodity_description = 'Crude Oil'
    ),
    CombinedData AS (
        SELECT
            commodity_description,
            country_name,
            report_date,
            attribute_description,
            SUM(value) AS value,
            CASE
                WHEN commodity_description IN ('Meal, Rapeseed', 'Oil, Rapeseed', 'Oilseed, Rapeseed') THEN 'Rapeseed'
                WHEN commodity_description IN ('Meal, Soybean', 'Oil, Soybean', 'Oilseed, Soybean', 'Oilseed, Soybean (Local)', 'Oil, Soybean (Local)', 'soybeans', 'Meal, Soybean (Local)') THEN 'Soybeans'
                WHEN commodity_description IN ('Meal, Sunflowerseed', 'Oil, Sunflowerseed', 'Oilseed, Sunflowerseed', 'sunflower') THEN 'Sunflower Oil'
                WHEN commodity_description IN ('Rice', 'Rice, Milled') THEN 'Rice'
                WHEN commodity_description IN ('wheat', 'Wheat') THEN 'Wheat'
                WHEN commodity_description = 'Oats' THEN 'Oat'
                WHEN commodity_description = 'Barley' THEN 'Barley'
                WHEN commodity_description = 'Corn' THEN 'Corn'
                WHEN commodity_description = 'Sugar' THEN 'Sugar'
                WHEN commodity_description LIKE '%Canola%' THEN 'Canola'
                WHEN commodity_description = 'Crude Oil' AND oil_variant = 'Brent' THEN 'Brent'
                WHEN commodity_description = 'Crude Oil' AND oil_variant = 'WTI' THEN 'Crude Oil (WTI)'
                WHEN commodity_description = 'Jet Fuel' THEN 'Jet Fuel'
                WHEN commodity_description = 'Diesel' THEN 'Diesel'
                WHEN commodity_description = 'LPG' THEN 'LPG'
                WHEN commodity_description = 'Gasoline' THEN 'Gasoline'
                WHEN commodity_description = 'Cement' THEN 'Cement'
                WHEN commodity_description = 'Steel' THEN 'Steel'
                WHEN commodity_description LIKE '%Bitumen%' OR commodity_description LIKE '%bitumen%' THEN 'Bitumen'
                WHEN commodity_description LIKE '%Urea%' OR commodity_description LIKE '%urea%' THEN 'Urea'
                WHEN commodity_description LIKE '%Iron Ore%' OR commodity_description LIKE '%iron ore%' OR commodity_description LIKE '%Iron-Ore%' THEN 'Iron Ore'
                WHEN commodity_description LIKE '%Concrete%' OR commodity_description LIKE '%concrete%' THEN 'Concrete'
                ELSE commodity_description
            END AS mapped_commodity_name
        FROM CombinedDataExpanded
        GROUP BY commodity_description, country_name, report_date, attribute_description, oil_variant
    ),
    DataWithRanking AS (
        SELECT
            *,
            DENSE_RANK() OVER (PARTITION BY mapped_commodity_name ORDER BY report_date DESC) AS month_num
        FROM CombinedData
    ),
    AggregatedData AS (
        SELECT
            commodity_description,
            mapped_commodity_name,
            report_date,
            month_num,
            SUM(CASE WHEN attribute_description = 'Domestic Consumption' THEN value ELSE 0 END) AS sum_domestic_consumption,
            SUM(CASE WHEN attribute_description = 'Production' THEN value ELSE 0 END) AS sum_production,
            SUM(CASE WHEN attribute_description = 'Total Supply' THEN value ELSE 0 END) AS sum_total_supply
        FROM DataWithRanking
        GROUP BY commodity_description, mapped_commodity_name, report_date, month_num
    ),
    DataWithAvg AS (
        SELECT
            *,
            AVG(sum_total_supply) OVER (
                PARTITION BY mapped_commodity_name
                ORDER BY report_date
                ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
            ) AS avg_previous_3_months
        FROM AggregatedData
    ),
    commodities_with_data AS (
        SELECT DISTINCT mapped_commodity_name FROM DataWithAvg
    ),
    missing_commodities AS (
        SELECT c.commodity_name AS mapped_commodity_name
        FROM all_commodities c
        LEFT JOIN commodities_with_data d ON c.commodity_name = d.mapped_commodity_name
        WHERE d.mapped_commodity_name IS NULL
    )
    SELECT
        mapped_commodity_name,
        month_num,
        CAST(report_date AS TIMESTAMP) AS report_date,
        commodity_description,
        sum_domestic_consumption AS domestic_consumption,
        sum_production AS production,
        sum_total_supply AS total_supply,
        (sum_total_supply - sum_domestic_consumption) AS supply_consumption,
        CASE
            WHEN month_num = 1 AND avg_previous_3_months IS NOT NULL AND avg_previous_3_months <> 0 THEN
                ((sum_total_supply / NULLIF(avg_previous_3_months, 0.0)) - 1) * 100
            ELSE NULL
        END AS score
    FROM DataWithAvg

    UNION ALL

    SELECT
        mapped_commodity_name,
        CAST(NULL AS BIGINT) AS month_num,
        CAST(NULL AS TIMESTAMP) AS report_date,
        CAST(NULL AS VARCHAR) AS commodity_description,
        CAST(NULL AS DOUBLE) AS domestic_consumption,
        CAST(NULL AS DOUBLE) AS production,
        CAST(NULL AS DOUBLE) AS total_supply,
        CAST(NULL AS DOUBLE) AS supply_consumption,
        CAST(NULL AS DOUBLE) AS score
    FROM missing_commodities

    ORDER BY mapped_commodity_name, report_date DESC NULLS LAST
) inner_query