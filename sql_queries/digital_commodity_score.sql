WITH daily_data AS (
    SELECT 
        symbol,
        COALESCE(
            TRY(DATE_PARSE(date, '%d/%m/%Y')),
            TRY(DATE_PARSE(date, '%Y-%m-%d'))
        ) as parsed_date,
        date as original_date,
        open,
        high,
        low,
        close,
        commodity
    FROM shippingbi.te_digital_history
),
weekly_aggregated AS (
    SELECT 
        symbol,
        commodity,
        DATE_TRUNC('week', parsed_date) as week_start,
        MAX(original_date) as latest_date_in_week,
        MAX(parsed_date) as latest_parsed_date,
        MAX_BY(open, parsed_date) as week_open,
        MAX(high) as week_high,
        MIN(low) as week_low,
        MAX_BY(close, parsed_date) as week_close
    FROM daily_data
    GROUP BY symbol, commodity, DATE_TRUNC('week', parsed_date)
),
weekly_ranked AS (
    SELECT 
        symbol,
        commodity,
        week_start,
        latest_date_in_week as date,
        latest_parsed_date as parsed_date,
        week_open as open,
        week_high as high,
        week_low as low,
        week_close as close,
        DENSE_RANK() OVER (
            PARTITION BY symbol, commodity 
            ORDER BY week_start DESC
        ) as LatestWeekRank
    FROM weekly_aggregated
),
week_over_week_data AS (
    SELECT 
        current_week.symbol,
        current_week.date,
        current_week.parsed_date,
        current_week.open,
        current_week.high,
        current_week.low,
        current_week.close,
        current_week.commodity,
        current_week.LatestWeekRank,
        previous_week.close as previous_week_close,
        CASE 
            WHEN previous_week.close IS NOT NULL AND previous_week.close != 0 
            THEN ((current_week.close - previous_week.close) / previous_week.close) * 100
            ELSE 0 
        END as week_over_week_percent_change,
        CASE 
            WHEN previous_week.close IS NOT NULL 
            THEN current_week.close - previous_week.close
            ELSE 0 
        END as week_over_week_difference
    FROM weekly_ranked current_week
    LEFT JOIN weekly_ranked previous_week 
        ON current_week.symbol = previous_week.symbol 
        AND current_week.commodity = previous_week.commodity
        AND current_week.LatestWeekRank = previous_week.LatestWeekRank - 1
)
SELECT 
    w.symbol,
    w.date,
    w.parsed_date,
    w.open,
    w.high,
    w.low,
    w.close,
    w.commodity,
    w.LatestWeekRank,
    w.week_over_week_percent_change,
    w.week_over_week_difference,
    w.week_over_week_percent_change as score
FROM week_over_week_data w
ORDER BY w.commodity, w.symbol, w.LatestWeekRank, w.parsed_date