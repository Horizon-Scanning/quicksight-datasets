WITH 
combined_news AS (
    -- This section has been replaced with your new UNION ALL logic
    -- Select all data from the historic news table, parsing its date format
    SELECT
        ROW_NUMBER() OVER (ORDER BY pub_date DESC) AS id,
        title,
        -- Parse the 'dd-mm-yyyy' string and cast to a DATE
        CAST(date_parse(pub_date, '%d/%m/%Y') AS DATE) AS date,
        description,
        NULL AS country, -- Country not available in mining_news_history
        'Commodity' AS category, -- Default category for mining news
        NULL AS symbol, -- Symbol not available
        link AS url, -- Use 'link' as 'url'
        NULL AS importance, -- Importance not available
        tag,
        confidence as tag_confidence,
        ARRAY_JOIN(
                TRANSFORM(
                    SPLIT(REPLACE(commodity, '-', ' '), ' '),
                    word -> UPPER(SUBSTRING(word, 1, 1)) || LOWER(SUBSTRING(word, 2))
                ),
                ' '
            )
        AS commodity
    FROM
        shippingbi.mining_news_history
    WHERE
        title IS NOT NULL -- Ensure title is not null for valid news items
),
base_data AS (
    SELECT
        *,
        -- The date is already parsed in the 'combined_news' CTE.
        -- We no longer need to parse it again. We just pass it through.
        date AS parsed_date,
        CASE WHEN tag = 'NEUTRAL' THEN 0 ELSE 1 END AS is_bad_news
    FROM 
        combined_news
),
cleaned_data AS (
    SELECT
        *,
        -- Use the 'commodity' field directly as commodity1. No URL parsing needed.
        commodity AS commodity1
    FROM
        base_data
    -- Only include records where date parsing succeeded
    WHERE parsed_date IS NOT NULL
),
last_30_days AS (
    SELECT 
        commodity1,
        COUNT(*) AS total_news,
        SUM(is_bad_news) AS bad_news_count,
        CAST(SUM(is_bad_news) AS DOUBLE) / NULLIF(COUNT(*), 0) * 100 AS bad_news_percent
    FROM 
        cleaned_data
    WHERE 
        parsed_date >= CURRENT_DATE - INTERVAL '30' DAY
    GROUP BY
        commodity1
),
prior_30_days AS (
    SELECT 
        commodity1,
        COUNT(*) AS total_news,
        SUM(is_bad_news) AS bad_news_count,
        CAST(SUM(is_bad_news) AS DOUBLE) / NULLIF(COUNT(*), 0) * 100 AS bad_news_percent
    FROM 
        cleaned_data
    WHERE 
        parsed_date >= CURRENT_DATE - INTERVAL '60' DAY
        AND parsed_date < CURRENT_DATE - INTERVAL '30' DAY
    GROUP BY
        commodity1
),
score_data AS (
    SELECT 
        COALESCE(l.commodity1, p.commodity1) AS commodity1,
        COALESCE(l.total_news, 0) AS last_30_days_total,
        COALESCE(l.bad_news_count, 0) AS last_30_days_bad_news,
        COALESCE(l.bad_news_percent, 0) AS last_30_days_bad_percent,
        COALESCE(p.total_news, 0) AS prior_30_days_total,
        COALESCE(p.bad_news_count, 0) AS prior_30_days_bad_news,
        COALESCE(p.bad_news_percent, 0) AS prior_30_days_bad_percent,
        -- Calculate percent change in bad news percentage
        CASE 
            WHEN COALESCE(p.bad_news_percent, 0) = 0 THEN 
                CASE WHEN COALESCE(l.bad_news_percent, 0) > 0 THEN 100 ELSE 0 END
            ELSE
                (COALESCE(l.bad_news_percent, 0) - COALESCE(p.bad_news_percent, 0)) / 
                COALESCE(p.bad_news_percent, 1) * 100
        END AS bad_news_percent_change
    FROM 
        last_30_days l
    FULL OUTER JOIN
        prior_30_days p
    ON
        l.commodity1 = p.commodity1
    WHERE
        COALESCE(l.total_news, 0) > 0 OR COALESCE(p.total_news, 0) > 0
),
news_frequency_stats AS (
    SELECT 
        MAX(last_30_days_total) AS max_news_count
    FROM 
        score_data
)
SELECT 
    s.commodity1 as Commodity,
    s.last_30_days_total,
    s.last_30_days_bad_news,
    ROUND(s.last_30_days_bad_percent, 1) AS last_30_days_bad_percent,
    s.prior_30_days_total,
    s.prior_30_days_bad_news,
    ROUND(s.prior_30_days_bad_percent, 1) AS prior_30_days_bad_percent,
    ROUND(s.bad_news_percent_change, 1) AS bad_news_percent_change,
    -- News frequency factor - better distribution across the range
    -- Using a logarithmic scale to better distribute values between min and max
    ROUND(0.1 + 0.9 * (LN(s.last_30_days_total + 1) / NULLIF(LN(nfs.max_news_count + 1), 1)), 2) AS news_frequency_factor,
    -- New score incorporating news frequency with updated weights: 0.3, 0.3, 0.4
    -- Apply final calibration to penalize low news counts in the total score
    ROUND(
        -- Calculate raw score with standard 0.3/0.3/0.4 weights
        (
            (s.last_30_days_bad_percent * 0.6) + 
            (CASE 
                WHEN s.bad_news_percent_change > 0 THEN s.bad_news_percent_change
                ELSE 0
             END * 0.2) +
            (100 * (0.1 + 0.9 * (LN(s.last_30_days_total + 1) / NULLIF(LN(nfs.max_news_count + 1), 1))) * 0.2)
        ) *
        -- Apply multiplier to final score based on news count
        CASE
            WHEN s.last_30_days_total = 1 THEN 0.3  -- 30% of score for 1 story
            WHEN s.last_30_days_total = 2 THEN 0.5  -- 50% of score for 2 stories
            -- For 3+ stories: gradual progression from 60% to 100%
            ELSE 0.6 + (0.4 * POWER((s.last_30_days_total - 3) / NULLIF((nfs.max_news_count - 3), 1), 0.5))
        END,
        1
    ) AS score
FROM 
    score_data s
CROSS JOIN
    news_frequency_stats nfs
ORDER BY
    score DESC