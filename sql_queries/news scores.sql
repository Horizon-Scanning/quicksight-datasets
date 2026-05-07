SELECT
    *,
    CASE
        WHEN score > 80  THEN 'Red Node'
        WHEN score >= 60 THEN 'Red'
        WHEN score >= 30 THEN 'Yellow'
        ELSE                  'Green'
    END AS status_color
FROM (
    -- ===================== ORIGINAL QUERY BELOW =====================
    WITH
    combined_news AS (
        SELECT
            id,
            title,
            CAST(date_parse(date, '%d/%m/%Y') AS DATE) AS date,
            description,
            country,
            category,
            symbol,
            url,
            importance,
            tag,
            tag_confidence,
            CASE
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'lpg' THEN 'LPG'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'rapeseed oil' THEN 'Rapeseed'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'brent crude oil' THEN 'Brent'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'cement' THEN 'Cement'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'steel' THEN 'Steel'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'iron-ore' THEN 'Iron Ore'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'bitumen' THEN 'Bitumen'
                WHEN LOWER(REPLACE(commodity, '-', ' ')) = 'urea' THEN 'Urea'
                ELSE ARRAY_JOIN(
                    TRANSFORM(
                        SPLIT(REPLACE(commodity, '-', ' '), ' '),
                        word -> UPPER(SUBSTRING(word, 1, 1)) || LOWER(SUBSTRING(word, 2))
                    ),
                    ' '
                )
            END AS commodity
        FROM shippingbi.historic_te_news

        UNION ALL

        SELECT
            CAST(900000000 + ROW_NUMBER() OVER () AS BIGINT) AS id,
            title,
            CAST(
                COALESCE(
                    TRY(date_parse(date, '%d/%m/%Y %H:%i:%s')),
                    TRY(date_parse(date, '%d/%m/%Y'))
                )
            AS DATE) AS date,
            description,
            country,
            'Commodity' AS category,
            NULL AS symbol,
            url,
            CAST(importance AS BIGINT) AS importance,
            tag,
            CAST(confidence AS DOUBLE) AS tag_confidence,
            CASE
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'lpg' THEN 'LPG'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'rapeseed oil' THEN 'Rapeseed'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'brent crude oil' THEN 'Brent'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'cement' THEN 'Cement'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'steel' THEN 'Steel'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'iron-ore' THEN 'Iron Ore'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'bitumen' THEN 'Bitumen'
                WHEN LOWER(REPLACE(id, '-', ' ')) = 'urea' THEN 'Urea'
                ELSE ARRAY_JOIN(
                    TRANSFORM(
                        SPLIT(REPLACE(id, '-', ' '), ' '),
                        word -> UPPER(SUBSTRING(word, 1, 1)) || LOWER(SUBSTRING(word, 2))
                    ),
                    ' '
                )
            END AS commodity
        FROM shippingbi.all_news_items_history_llm
        WHERE
            id NOT IN ('BAID', 'BCTI')
            AND title IS NOT NULL
    ),
    base_data AS (
        SELECT
            *,
            date AS parsed_date,
            CASE WHEN tag = 'NEUTRAL' THEN 0 ELSE 1 END AS is_bad_news
        FROM combined_news
    ),
    cleaned_data AS (
        SELECT
            *,
            commodity AS commodity1
        FROM base_data
        WHERE parsed_date IS NOT NULL
    ),
    last_30_days AS (
        SELECT
            commodity1,
            COUNT(*) AS total_news,
            SUM(is_bad_news) AS bad_news_count,
            CAST(SUM(is_bad_news) AS DOUBLE) / NULLIF(COUNT(*), 0) * 100 AS bad_news_percent
        FROM cleaned_data
        WHERE parsed_date >= CURRENT_DATE - INTERVAL '30' DAY
        GROUP BY commodity1
    ),
    prior_30_days AS (
        SELECT
            commodity1,
            COUNT(*) AS total_news,
            SUM(is_bad_news) AS bad_news_count,
            CAST(SUM(is_bad_news) AS DOUBLE) / NULLIF(COUNT(*), 0) * 100 AS bad_news_percent
        FROM cleaned_data
        WHERE
            parsed_date >= CURRENT_DATE - INTERVAL '60' DAY
            AND parsed_date < CURRENT_DATE - INTERVAL '30' DAY
        GROUP BY commodity1
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
            CASE
                WHEN COALESCE(p.bad_news_percent, 0) = 0 THEN
                    CASE WHEN COALESCE(l.bad_news_percent, 0) > 0 THEN 100 ELSE 0 END
                ELSE
                    (COALESCE(l.bad_news_percent, 0) - COALESCE(p.bad_news_percent, 0)) /
                    COALESCE(p.bad_news_percent, 1) * 100
            END AS bad_news_percent_change
        FROM last_30_days l
        FULL OUTER JOIN prior_30_days p ON l.commodity1 = p.commodity1
        WHERE COALESCE(l.total_news, 0) > 0 OR COALESCE(p.total_news, 0) > 0
    ),
    news_frequency_stats AS (
        SELECT MAX(last_30_days_total) AS max_news_count
        FROM score_data
    )
    SELECT
        s.commodity1 AS Commodity,
        s.last_30_days_total,
        s.last_30_days_bad_news,
        ROUND(s.last_30_days_bad_percent, 1) AS last_30_days_bad_percent,
        s.prior_30_days_total,
        s.prior_30_days_bad_news,
        ROUND(s.prior_30_days_bad_percent, 1) AS prior_30_days_bad_percent,
        ROUND(s.bad_news_percent_change, 1) AS bad_news_percent_change,
        ROUND(0.1 + 0.9 * (LN(s.last_30_days_total + 1) / NULLIF(LN(nfs.max_news_count + 1), 1)), 2) AS news_frequency_factor,
        ROUND(
            (
                (s.last_30_days_bad_percent * 0.6) +
                (CASE
                    WHEN s.bad_news_percent_change > 0 THEN s.bad_news_percent_change
                    ELSE 0
                 END * 0.2) +
                (100 * (0.1 + 0.9 * (LN(s.last_30_days_total + 1) / NULLIF(LN(nfs.max_news_count + 1), 1))) * 0.2)
            ) *
            CASE
                WHEN s.last_30_days_total = 1 THEN 0.3
                WHEN s.last_30_days_total = 2 THEN 0.5
                ELSE 0.6 + (0.4 * POWER((s.last_30_days_total - 3) / NULLIF((nfs.max_news_count - 3), 1), 0.5))
            END,
            1
        ) AS score
    FROM score_data s
    CROSS JOIN news_frequency_stats nfs
) inner_query
ORDER BY score DESC