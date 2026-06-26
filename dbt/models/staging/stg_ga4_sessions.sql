-- stg_ga4_sessions.sql
-- Sessionize raw GA4 events into user sessions with engagement metrics

{{ config(materialized='view', schema='MARTS') }}

WITH events AS (
    SELECT
        user_pseudo_id,
        event_timestamp,
        event_name,
        article_id,
        section,
        engagement_time_sec,
        device_category,
        traffic_source,
        -- Session boundary: 30 min inactivity gap
        CASE 
            WHEN DATEDIFF('minute', 
                LAG(event_timestamp) OVER (PARTITION BY user_pseudo_id ORDER BY event_timestamp),
                event_timestamp) > 30
            THEN 1
            ELSE 0
        END AS new_session_flag
    FROM {{ source('raw', 'GA4_EVENTS') }}
)

, sessions AS (
    SELECT
        *,
        SUM(new_session_flag) OVER (
            PARTITION BY user_pseudo_id 
            ORDER BY event_timestamp 
            ROWS UNBOUNDED PRECEDING
        ) AS session_id
    FROM events
)

SELECT
    user_pseudo_id,
    session_id,
    MIN(event_timestamp) AS session_start,
    MAX(event_timestamp) AS session_end,
    DATEDIFF('second', MIN(event_timestamp), MAX(event_timestamp)) AS session_duration_sec,
    COUNT(*) AS total_events,
    COUNT(DISTINCT article_id) AS articles_viewed,
    SUM(engagement_time_sec) AS total_engagement_sec,
    MAX(device_category) AS device,
    MAX(traffic_source) AS traffic_source,
    COUNT_IF(event_name = 'paywall_hit') AS paywall_hits,
    COUNT_IF(event_name = 'subscribe_click') AS subscribe_clicks,
    ARRAY_AGG(DISTINCT section) WITHIN GROUP (ORDER BY section) AS sections_visited
FROM sessions
GROUP BY user_pseudo_id, session_id
