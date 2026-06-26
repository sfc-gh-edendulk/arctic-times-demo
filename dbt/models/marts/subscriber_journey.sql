-- subscriber_journey.sql
-- Maps the user journey from first anonymous visit to subscription (or churn)

{{ config(materialized='table', schema='MARTS') }}

WITH subscriber_events AS (
    SELECT
        e.user_pseudo_id,
        s.user_id,
        s.subscription_type,
        s.start_date AS subscription_start,
        s.churn_flag,
        s.ltv_estimated_eur,
        e.event_timestamp,
        e.event_name,
        e.section,
        e.article_id,
        e.engagement_time_sec,
        -- Days relative to subscription start
        DATEDIFF('day', s.start_date, e.event_timestamp::DATE) AS days_from_subscription
    FROM {{ source('raw', 'GA4_EVENTS') }} e
    INNER JOIN {{ source('raw', 'SUBSCRIBERS') }} s 
        ON e.user_pseudo_id = s.user_id
)

, journey_phases AS (
    SELECT
        user_id,
        subscription_type,
        subscription_start,
        churn_flag,
        ltv_estimated_eur,
        
        -- Pre-subscription behavior (discovery phase)
        COUNT_IF(days_from_subscription < 0) AS events_before_sub,
        COUNT_IF(days_from_subscription < 0 AND event_name = 'page_view') AS pages_before_sub,
        COUNT(DISTINCT CASE WHEN days_from_subscription < 0 THEN section END) AS sections_explored_pre,
        AVG(CASE WHEN days_from_subscription < 0 THEN engagement_time_sec END) AS avg_engagement_pre,
        
        -- First 30 days (onboarding)
        COUNT_IF(days_from_subscription BETWEEN 0 AND 30) AS events_first_30d,
        COUNT(DISTINCT CASE WHEN days_from_subscription BETWEEN 0 AND 30 THEN article_id END) AS articles_first_30d,
        
        -- Last 30 days (retention signal)
        COUNT_IF(days_from_subscription >= DATEDIFF('day', subscription_start, CURRENT_DATE()) - 30) AS events_last_30d,
        COUNT(DISTINCT CASE WHEN days_from_subscription >= DATEDIFF('day', subscription_start, CURRENT_DATE()) - 30 THEN article_id END) AS articles_last_30d,
        
        -- Overall
        COUNT(*) AS total_events,
        COUNT(DISTINCT article_id) AS total_articles_read,
        COUNT(DISTINCT section) AS sections_engaged
        
    FROM subscriber_events
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    *,
    -- Engagement trend (last 30d vs first 30d)
    CASE
        WHEN events_first_30d > 0
        THEN ROUND((events_last_30d - events_first_30d) / events_first_30d * 100, 1)
        ELSE 0
    END AS engagement_trend_pct,
    
    -- Journey classification
    CASE
        WHEN churn_flag = TRUE THEN 'CHURNED'
        WHEN events_last_30d = 0 THEN 'AT_RISK'
        WHEN engagement_trend_pct < -50 THEN 'DECLINING'
        WHEN engagement_trend_pct > 50 THEN 'GROWING'
        ELSE 'STABLE'
    END AS journey_stage

FROM journey_phases
