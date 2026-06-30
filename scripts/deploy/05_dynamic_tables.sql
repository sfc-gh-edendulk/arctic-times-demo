-- ============================================================================
-- Arctic Times — 05 Dynamic Tables: CURATED aggregations
-- ============================================================================
-- Column shapes match what AI.CONTENT_SV expects.
--   snow sql -f scripts/deploy/05_dynamic_tables.sql --connection lemondetrial
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARCTIC_TIMES;
USE SCHEMA CURATED;
USE WAREHOUSE COMPUTE_WH;

-- ---------------------------------------------------------------------------
-- READER_ENGAGEMENT — daily engagement by section + publication
-- ---------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ARCTIC_TIMES.CURATED.READER_ENGAGEMENT
  TARGET_LAG = '5 minutes'
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  WAREHOUSE = COMPUTE_WH
AS
SELECT
    event_date                                          AS day,
    section,
    publication,
    COUNT(DISTINCT user_pseudo_id)                      AS unique_readers,
    COUNT(*)                                            AS page_views,
    ROUND(AVG(engagement_time_sec), 1)                  AS avg_engagement_sec,
    COUNT_IF(event_name = 'paywall_hit')                AS paywall_hits,
    COUNT_IF(event_name = 'subscribe_click')            AS subscribe_clicks,
    ROUND(
        COUNT_IF(event_name = 'subscribe_click')
        / NULLIF(COUNT_IF(event_name = 'paywall_hit'), 0) * 100, 1
    )                                                   AS conversion_rate_pct
FROM ARCTIC_TIMES.RAW.GA4_EVENTS
GROUP BY 1, 2, 3;

-- ---------------------------------------------------------------------------
-- ARTICLE_PERFORMANCE — per-article reader metrics + performance tier
-- ---------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE ARCTIC_TIMES.CURATED.ARTICLE_PERFORMANCE
  TARGET_LAG = '10 minutes'
  REFRESH_MODE = AUTO
  INITIALIZE = ON_CREATE
  WAREHOUSE = COMPUTE_WH
AS
SELECT
    a.article_id,
    a.title,
    a.author,
    a.section,
    a.publication,
    a.published_at,
    a.paywall_type,
    COUNT(DISTINCT e.user_pseudo_id)                    AS unique_readers,
    ROUND(AVG(e.engagement_time_sec), 1)                AS avg_read_time_sec,
    COUNT_IF(e.scroll_pct >= 75)                        AS deep_reads,
    COUNT_IF(e.event_name = 'share')                    AS shares,
    COUNT_IF(e.event_name = 'paywall_hit')              AS paywall_hits,
    COUNT_IF(e.event_name = 'subscribe_click')          AS conversions,
    CASE
        WHEN COUNT(DISTINCT e.user_pseudo_id) >= 30 THEN 'VIRAL'
        WHEN COUNT(DISTINCT e.user_pseudo_id) >= 25 THEN 'HIGH'
        WHEN COUNT(DISTINCT e.user_pseudo_id) >= 18 THEN 'NORMAL'
        ELSE 'LOW'
    END                                                 AS performance_tier
FROM ARCTIC_TIMES.RAW.ARTICLES a
LEFT JOIN ARCTIC_TIMES.RAW.GA4_EVENTS e
  ON e.article_id = a.article_id
GROUP BY 1, 2, 3, 4, 5, 6, 7;

SELECT 'Dynamic tables created' AS status;
