-- content_analytics.sql
-- Complex content performance model: articles with reader engagement, lifecycle, and conversion

{{ config(materialized='table', schema='MARTS') }}

WITH article_events AS (
    SELECT
        article_id,
        COUNT(DISTINCT user_pseudo_id) AS unique_readers,
        COUNT(*) AS total_events,
        AVG(engagement_time_sec) AS avg_engagement_sec,
        COUNT_IF(event_name = 'scroll' AND scroll_pct >= 75) AS deep_reads,
        COUNT_IF(event_name = 'share') AS shares,
        COUNT_IF(event_name = 'paywall_hit') AS paywall_hits,
        COUNT_IF(event_name = 'subscribe_click') AS conversions,
        MIN(event_timestamp) AS first_read,
        MAX(event_timestamp) AS last_read
    FROM {{ source('raw', 'GA4_EVENTS') }}
    WHERE article_id IS NOT NULL
    GROUP BY article_id
)

, articles AS (
    SELECT
        article_id,
        title,
        author,
        section,
        publication,
        published_at,
        word_count,
        paywall_type
    FROM {{ source('raw', 'ARTICLES') }}
)

SELECT
    a.article_id,
    a.title,
    a.author,
    a.section,
    a.publication,
    a.published_at,
    a.word_count,
    a.paywall_type,
    
    -- Reader metrics
    COALESCE(e.unique_readers, 0) AS unique_readers,
    COALESCE(e.total_events, 0) AS total_events,
    COALESCE(e.avg_engagement_sec, 0) AS avg_engagement_sec,
    COALESCE(e.deep_reads, 0) AS deep_reads,
    COALESCE(e.shares, 0) AS shares,
    
    -- Conversion funnel
    COALESCE(e.paywall_hits, 0) AS paywall_hits,
    COALESCE(e.conversions, 0) AS conversions,
    CASE 
        WHEN e.paywall_hits > 0 
        THEN ROUND(e.conversions / e.paywall_hits * 100, 1)
        ELSE 0 
    END AS conversion_rate_pct,
    
    -- Lifecycle
    DATEDIFF('hour', a.published_at, e.last_read) AS lifespan_hours,
    DATEDIFF('hour', a.published_at, e.first_read) AS time_to_first_read_hours,
    
    -- Performance tier
    CASE
        WHEN COALESCE(e.unique_readers, 0) > 5000 THEN 'VIRAL'
        WHEN COALESCE(e.unique_readers, 0) > 1000 THEN 'HIGH'
        WHEN COALESCE(e.unique_readers, 0) > 200 THEN 'NORMAL'
        ELSE 'LOW'
    END AS performance_tier

FROM articles a
LEFT JOIN article_events e ON a.article_id = e.article_id
