-- ============================================================================
-- Arctic Times — 03 Curate: ARTICLES, AUTHORS, typed GA4_EVENTS
-- ============================================================================
-- The original demo sourced ARTICLES/AUTHORS from a Postgres CMS via Openflow
-- CDC. In the trial we synthesize them deterministically from the article_ids
-- present in the GA4 events (hash-based, so joins always resolve).
--   snow sql -f scripts/deploy/03_curate.sql --connection lemondetrial
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARCTIC_TIMES;
USE SCHEMA RAW;
USE WAREHOUSE COMPUTE_WH;

-- ---------------------------------------------------------------------------
-- ARTICLES — one row per distinct article_id seen in events
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARCTIC_TIMES.RAW.ARTICLES AS
WITH ids AS (
    SELECT DISTINCT article_id
    FROM ARCTIC_TIMES.RAW.GA4_TRACKING
    WHERE article_id IS NOT NULL
),
sections AS (
    SELECT ARRAY_CONSTRUCT(
        'Politique','International','Economie','Culture','Sciences',
        'Sport','Planete','Opinions','Societe'
    ) AS arr
),
pubs AS (
    SELECT ARRAY_CONSTRUCT(
        'Arctic Times','Courrier Polaire','Telerama Nord',
        'La Vie Glaciale','Arctic Times Diplomatique'
    ) AS arr
),
authors AS (
    SELECT ARRAY_CONSTRUCT(
        'Jean Martin','Marie Bernard','Pierre Dubois','Sophie Thomas',
        'Laurent Robert','Claire Richard','Nicolas Petit','Isabelle Durand',
        'Thomas Leroy','Camille Moreau','Antoine Girard','Lucie Lefevre',
        'Julien Mercier','Emma Fontaine','Hugo Rousseau','Lea Blanc'
    ) AS arr
)
SELECT
    i.article_id,
    'Reportage ' || GET(s.arr, ABS(HASH(i.article_id)) % 9)::STRING
        || ' #' || REGEXP_REPLACE(i.article_id, '[^0-9]', '')        AS title,
    GET(au.arr, ABS(HASH(i.article_id, 'auth')) % 16)::STRING        AS author,
    GET(s.arr,  ABS(HASH(i.article_id)) % 9)::STRING                 AS section,
    GET(p.arr,  ABS(HASH(i.article_id, 'pub')) % 5)::STRING          AS publication,
    DATEADD('hour', -(ABS(HASH(i.article_id, 'ts')) % 1440),
            CURRENT_TIMESTAMP())::TIMESTAMP_NTZ                      AS published_at,
    300 + (ABS(HASH(i.article_id, 'wc')) % 2200)                     AS word_count,
    CASE (ABS(HASH(i.article_id, 'pw')) % 10)
        WHEN 8 THEN 'hard' WHEN 9 THEN 'hard'
        WHEN 0 THEN 'none' WHEN 1 THEN 'none' WHEN 2 THEN 'none'
        ELSE 'soft'
    END                                                              AS paywall_type
FROM ids i, sections s, pubs p, authors au;

-- ---------------------------------------------------------------------------
-- AUTHORS — derived from the authors actually assigned to articles
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARCTIC_TIMES.RAW.AUTHORS AS
SELECT
    author                                                          AS name,
    MAX(section)                                                    AS section,
    CASE (ABS(HASH(author)) % 3)
        WHEN 0 THEN 'senior' WHEN 1 THEN 'staff' ELSE 'contributor'
    END                                                             AS seniority,
    COUNT(*)                                                        AS article_count
FROM ARCTIC_TIMES.RAW.ARTICLES
GROUP BY author;

-- ---------------------------------------------------------------------------
-- GA4_EVENTS — typed events with event_date + publication (for the DTs)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARCTIC_TIMES.RAW.GA4_EVENTS AS
SELECT
    t.event_name,
    TO_TIMESTAMP_NTZ(t.event_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS event_timestamp,
    TO_TIMESTAMP_NTZ(t.event_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')::DATE AS event_date,
    t.user_pseudo_id,
    t.article_id,
    t.section,
    a.publication,
    t.device_category,
    t.browser,
    t.os,
    t.country,
    t.city,
    t.traffic_source,
    t.traffic_medium,
    t.engagement_time_sec,
    t.scroll_pct
FROM ARCTIC_TIMES.RAW.GA4_TRACKING t
LEFT JOIN ARCTIC_TIMES.RAW.ARTICLES a
  ON t.article_id = a.article_id;

-- ---------------------------------------------------------------------------
-- Sanity
-- ---------------------------------------------------------------------------
SELECT 'ARTICLES' AS tbl, COUNT(*) AS n FROM ARCTIC_TIMES.RAW.ARTICLES
UNION ALL SELECT 'AUTHORS',    COUNT(*) FROM ARCTIC_TIMES.RAW.AUTHORS
UNION ALL SELECT 'GA4_EVENTS', COUNT(*) FROM ARCTIC_TIMES.RAW.GA4_EVENTS
UNION ALL SELECT 'GA4_EVENTS_no_pub', COUNT(*) FROM ARCTIC_TIMES.RAW.GA4_EVENTS WHERE publication IS NULL;
