-- Custom SQL for QuickSight with Quarter-over-Quarter Export Score and Data Availability Adjustment
WITH hs_codes_mapping AS (
SELECT 'Barley' as mapped_commodity_name, '100390' as hs_code
    UNION ALL SELECT 'LPG', '271113'
    UNION ALL SELECT 'Canola', '151419'
    UNION ALL SELECT 'Corn', '100590'
    UNION ALL SELECT 'Corn', '110220'
    UNION ALL SELECT 'Corn', '110313'
    UNION ALL SELECT 'Corn', '110423'
    UNION ALL SELECT 'Corn', '230210'
    UNION ALL SELECT 'Corn', '230310'
    UNION ALL SELECT 'Corn', '230330'
    UNION ALL SELECT 'Crude Oil', '270900'
    UNION ALL SELECT 'Ethylene and Other Gases', '271114'
    UNION ALL SELECT 'Gasoline', '271019'
    UNION ALL SELECT 'Diesel', '271012'
    UNION ALL SELECT 'Diesel', '271020'
    UNION ALL SELECT 'LPG', '271112'
    UNION ALL SELECT 'Petroleum Gases', '271119'
    UNION ALL SELECT 'Rapeseed', '151411'
    UNION ALL SELECT 'Rapeseed', '230649'
    UNION ALL SELECT 'Rice', '100630'
    UNION ALL SELECT 'Soybeans', '120110'
    UNION ALL SELECT 'Soybeans', '120190'
    UNION ALL SELECT 'Soybeans', '120810'
    UNION ALL SELECT 'Soybeans', '150710'
    UNION ALL SELECT 'Soybeans', '150790'
    UNION ALL SELECT 'Soybeans', '230400'
    UNION ALL SELECT 'Soybeans', '230800'
    UNION ALL SELECT 'Sugar', '170199'
    UNION ALL SELECT 'Sunflower Oil', '151790'
    UNION ALL SELECT 'Sunflower Oil', '230630'
    UNION ALL SELECT 'Wheat', '100199'
    UNION ALL SELECT 'Wheat', '110100'
    UNION ALL SELECT 'Oats', '110290'
    UNION ALL SELECT 'Wheat', '110311'
    UNION ALL SELECT 'Oats', '110319'
    UNION ALL SELECT 'Wheat', '110320'
    UNION ALL SELECT 'Wheat', '230230'
    UNION ALL SELECT 'Wheat', '230240'
    UNION ALL SELECT 'Bitumen', '271320'
    UNION ALL SELECT 'Bitumen', '271490'
    UNION ALL SELECT 'Bitumen', '271500'
    UNION ALL SELECT 'Bitumen', '271410'
    UNION ALL SELECT 'Cement', '252310'
    UNION ALL SELECT 'Cement', '252321'
    UNION ALL SELECT 'Cement', '252329'
    UNION ALL SELECT 'Cement', '252330'
    UNION ALL SELECT 'Cement', '252390'
    UNION ALL SELECT 'Iron Ore', '720110'
    UNION ALL SELECT 'Iron Ore', '720120'
    UNION ALL SELECT 'Iron Ore', '720150'
    UNION ALL SELECT 'Iron Ore', '720211'
    UNION ALL SELECT 'Iron Ore', '720219'
    UNION ALL SELECT 'Iron Ore', '720221'
    UNION ALL SELECT 'Iron Ore', '720229'
    UNION ALL SELECT 'Iron Ore', '720241'
    UNION ALL SELECT 'Iron Ore', '720299'
    UNION ALL SELECT 'Iron Ore', '720310'
    UNION ALL SELECT 'Iron Ore', '720390'
    UNION ALL SELECT 'Urea', '310210'
    UNION ALL SELECT 'Steel', '721590'
    UNION ALL SELECT 'Steel', '721610'
    UNION ALL SELECT 'Steel', '721631'
    UNION ALL SELECT 'Steel', '721632'
    UNION ALL SELECT 'Steel', '721633'
    UNION ALL SELECT 'Steel', '721691'
    UNION ALL SELECT 'Steel', '721699'
    UNION ALL SELECT 'Steel', '722530'
    UNION ALL SELECT 'Steel', '720851'
    UNION ALL SELECT 'Steel', '720890'
    UNION ALL SELECT 'Steel', '721420'
    UNION ALL SELECT 'Steel', '730300'
    UNION ALL SELECT 'Steel', '732510'
    UNION ALL SELECT 'Steel', '732591'
    UNION ALL SELECT 'Steel', '732599'
    UNION ALL SELECT 'Concrete', '681011'
    UNION ALL SELECT 'Concrete', '681019'
    UNION ALL SELECT 'Legumes', '071310'
    UNION ALL SELECT 'Legumes', '071320'
    UNION ALL SELECT 'Legumes', '071331'
    UNION ALL SELECT 'Legumes', '071332'
    UNION ALL SELECT 'Legumes', '071333'
    UNION ALL SELECT 'Legumes', '071334'
    UNION ALL SELECT 'Legumes', '071335'
    UNION ALL SELECT 'Legumes', '071339'
    UNION ALL SELECT 'Legumes', '071340'
    UNION ALL SELECT 'Legumes', '071350'
    UNION ALL SELECT 'Legumes', '071360'
    UNION ALL SELECT 'Legumes', '071390'
    UNION ALL SELECT 'Tuna', '160414'
    UNION ALL SELECT 'Pasta', '190211'
    UNION ALL SELECT 'Pasta', '190219'
    UNION ALL SELECT 'Pasta', '190220'
    UNION ALL SELECT 'Pasta', '190230'
    UNION ALL SELECT 'Couscous', '190240'
    UNION ALL SELECT 'Infant Formula', '190110'
    UNION ALL SELECT 'Yeast', '210210'
    UNION ALL SELECT 'Yeast', '210220'
),

-- Add commodities with null values (Brent and Oats)
all_commodities AS (
    SELECT DISTINCT mapped_commodity_name FROM hs_codes_mapping
    UNION ALL SELECT 'Brent'
    UNION ALL SELECT 'Jet Fuel'
),

base_data AS (
    -- Original query for all commodities
    SELECT
        ce.*,
        hs.mapped_commodity_name,
        CASE
            WHEN ce.refmonth IN (1,2,3) THEN 1
            WHEN ce.refmonth IN (4,5,6) THEN 2
            WHEN ce.refmonth IN (7,8,9) THEN 3
            WHEN ce.refmonth IN (10,11,12) THEN 4
        END as quarter,
        ce.refyear * 10 + CASE
            WHEN ce.refmonth IN (1,2,3) THEN 1
            WHEN ce.refmonth IN (4,5,6) THEN 2
            WHEN ce.refmonth IN (7,8,9) THEN 3
            WHEN ce.refmonth IN (10,11,12) THEN 4
        END as quarter_num,
        CASE
            WHEN ce.refmonth IN (1,2,3) THEN (ce.refyear-1) * 10 + 4
            WHEN ce.refmonth IN (4,5,6) THEN ce.refyear * 10 + 1
            WHEN ce.refmonth IN (7,8,9) THEN ce.refyear * 10 + 2
            WHEN ce.refmonth IN (10,11,12) THEN ce.refyear * 10 + 3
        END as prev_quarter_num
    FROM shippingbi.comtrade_world_exports ce
    INNER JOIN hs_codes_mapping hs ON CAST(ce.cmdcode AS VARCHAR) = hs.hs_code
    WHERE ce.netwgt IS NOT NULL

    UNION ALL

    -- Duplicate Crude Oil data and assign it to Brent
    SELECT
        ce.*,
        'Brent' AS mapped_commodity_name, -- Re-label the commodity name as 'Brent'
        CASE
            WHEN ce.refmonth IN (1,2,3) THEN 1
            WHEN ce.refmonth IN (4,5,6) THEN 2
            WHEN ce.refmonth IN (7,8,9) THEN 3
            WHEN ce.refmonth IN (10,11,12) THEN 4
        END as quarter,
        ce.refyear * 10 + CASE
            WHEN ce.refmonth IN (1,2,3) THEN 1
            WHEN ce.refmonth IN (4,5,6) THEN 2
            WHEN ce.refmonth IN (7,8,9) THEN 3
            WHEN ce.refmonth IN (10,11,12) THEN 4
        END as quarter_num,
        CASE
            WHEN ce.refmonth IN (1,2,3) THEN (ce.refyear-1) * 10 + 4
            WHEN ce.refmonth IN (4,5,6) THEN ce.refyear * 10 + 1
            WHEN ce.refmonth IN (7,8,9) THEN ce.refyear * 10 + 2
            WHEN ce.refmonth IN (10,11,12) THEN ce.refyear * 10 + 3
        END as prev_quarter_num
    FROM shippingbi.comtrade_world_exports ce
    INNER JOIN hs_codes_mapping hs ON CAST(ce.cmdcode AS VARCHAR) = hs.hs_code
    WHERE ce.netwgt IS NOT NULL AND hs.mapped_commodity_name = 'Crude Oil' -- Select only Crude Oil records to duplicate
),


-- Get availability data by quarter
availability_data AS (
    SELECT
        cah.reportercode,
        cah.period,
        cah.totalrecords,
        -- **FIX**: Cast the numeric 'period' column to VARCHAR before using SUBSTR
        CASE
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (1,2,3) THEN 1
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (4,5,6) THEN 2
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (7,8,9) THEN 3
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (10,11,12) THEN 4
        END as quarter,

        -- **FIX**: Cast the numeric 'period' column to VARCHAR before using SUBSTR
        CAST(SUBSTR(CAST(cah.period AS VARCHAR), 1, 4) AS INTEGER) as refyear,

        -- **FIX**: Cast the numeric 'period' column to VARCHAR before using SUBSTR
        CAST(SUBSTR(CAST(cah.period AS VARCHAR), 1, 4) AS INTEGER) * 10 +
        CASE
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (1,2,3) THEN 1
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (4,5,6) THEN 2
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (7,8,9) THEN 3
            WHEN CAST(SUBSTR(CAST(cah.period AS VARCHAR), 5, 2) AS INTEGER) IN (10,11,12) THEN 4
        END as quarter_num
    FROM shippingbi.cmt_availability_history cah
),

-- Aggregate availability by reporter and quarter
availability_quarterly AS (
    SELECT
        reportercode,
        refyear,
        quarter,
        quarter_num,
        SUM(CAST(totalrecords AS DOUBLE)) as total_records_quarter
    FROM availability_data
    GROUP BY reportercode, refyear, quarter, quarter_num
),

-- Get the current quarter to exclude from scoring
current_quarter AS (
    SELECT MAX(quarter_num) as max_quarter_num
    FROM base_data
),

-- Aggregate by mapped commodity and quarter with availability data
quarterly_aggregated AS (
    SELECT
        bd.mapped_commodity_name,
        bd.refyear,
        bd.quarter,
        bd.quarter_num,
        bd.prev_quarter_num,
        SUM(CAST(bd.netwgt AS DOUBLE)) as total_netwgt,
        COUNT(*) as record_count,
        SUM(COALESCE(aq.total_records_quarter, 0)) as total_availability_records
    FROM base_data bd
    CROSS JOIN current_quarter cq
    LEFT JOIN availability_quarterly aq ON
        bd.reportercode = aq.reportercode AND
        bd.quarter_num = aq.quarter_num
    WHERE bd.quarter_num < cq.max_quarter_num
    GROUP BY bd.mapped_commodity_name, bd.refyear, bd.quarter, bd.quarter_num, bd.prev_quarter_num
),

-- Calculate quarter-over-quarter comparison by mapped commodity
period_comparison AS (
    SELECT
        q1.*,
        q2.total_netwgt as prev_total_netwgt,
        q2.total_availability_records as prev_total_availability_records,
        CASE
            WHEN q2.total_netwgt IS NOT NULL AND q2.total_netwgt > 0
            THEN ((q1.total_netwgt - q2.total_netwgt) / q2.total_netwgt) * 100
            ELSE 0.0
        END as netwgt_qoq_change,
        CASE
            WHEN q2.total_availability_records IS NOT NULL AND q2.total_availability_records > 0
            THEN ((q1.total_availability_records - q2.total_availability_records) / q2.total_availability_records) * 100
            ELSE 0.0
        END as totalrecords_qoq_change
    FROM quarterly_aggregated q1
    LEFT JOIN quarterly_aggregated q2 ON
        q1.mapped_commodity_name = q2.mapped_commodity_name AND
        q1.prev_quarter_num = q2.quarter_num
),

-- Calculate average records change (baseline)
totalrecords_avg_pop AS (
    SELECT
        mapped_commodity_name,
        AVG(totalrecords_qoq_change) as avg_totalrecords_change
    FROM period_comparison
    WHERE totalrecords_qoq_change IS NOT NULL
    GROUP BY mapped_commodity_name
),

-- Get all quarters and commodities for complete matrix
quarters_commodities AS (
    SELECT
        ac.mapped_commodity_name,
        qd.refyear,
        qd.quarter,
        qd.quarter_num
    FROM all_commodities ac
    CROSS JOIN (
        SELECT DISTINCT refyear, quarter, quarter_num
        FROM period_comparison
    ) qd
),

-- Final data with null values for missing commodities
final_data AS (
    SELECT
        qc.mapped_commodity_name,
        qc.refyear,
        qc.quarter,
        qc.quarter_num,
        COALESCE(pc.total_netwgt, NULL) as total_netwgt,
        COALESCE(pc.prev_total_netwgt, NULL) as prev_total_netwgt,
        COALESCE(pc.record_count, 0) as record_count,
        COALESCE(pc.total_availability_records, NULL) as total_availability_records,
        COALESCE(pc.prev_total_availability_records, NULL) as prev_total_availability_records,
        COALESCE(pc.netwgt_qoq_change, NULL) as netwgt_qoq_change,
        COALESCE(pc.totalrecords_qoq_change, NULL) as totalrecords_qoq_change,
        COALESCE(tap.avg_totalrecords_change, 0) as avg_totalrecords_change
    FROM quarters_commodities qc
    LEFT JOIN period_comparison pc ON
        qc.mapped_commodity_name = pc.mapped_commodity_name AND
        qc.quarter_num = pc.quarter_num
    LEFT JOIN totalrecords_avg_pop tap ON
        qc.mapped_commodity_name = tap.mapped_commodity_name
)

-- Final SELECT with calculated QoQ scores by mapped commodity
SELECT
    mapped_commodity_name,
    refyear,
    quarter,
    quarter_num,
    total_netwgt,
    prev_total_netwgt,
    record_count,
    total_availability_records,
    netwgt_qoq_change,
    totalrecords_qoq_change,
    avg_totalrecords_change,
    netwgt_qoq_change as worldwide_exports_score_continuous,
    CASE
        WHEN netwgt_qoq_change IS NOT NULL AND totalrecords_qoq_change IS NOT NULL
        THEN netwgt_qoq_change - (totalrecords_qoq_change - avg_totalrecords_change)
        ELSE NULL
    END as availability_adjusted_score,
    CASE
        WHEN netwgt_qoq_change IS NOT NULL AND totalrecords_qoq_change IS NOT NULL
        THEN
            CASE
                WHEN (netwgt_qoq_change - (totalrecords_qoq_change - avg_totalrecords_change)) > 100 THEN 100
                WHEN (netwgt_qoq_change - (totalrecords_qoq_change - avg_totalrecords_change)) < -100 THEN -100
                ELSE (netwgt_qoq_change - (totalrecords_qoq_change - avg_totalrecords_change))
            END
        ELSE NULL
    END as availability_adjusted_score_normalized
FROM final_data
ORDER BY mapped_commodity_name, refyear DESC, quarter DESC