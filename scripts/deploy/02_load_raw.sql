-- ============================================================================
-- Arctic Times — 02 Load Raw: Stages + PUT + COPY INTO
-- ============================================================================
-- Loads GA4 tracking (batch_1, schema-evolution enabled), VARIANT events,
-- and subscribers. batch_2 is uploaded but NOT loaded (reserved for the live
-- schema-evolution demo).
--   snow sql -f scripts/deploy/02_load_raw.sql --connection lemondetrial
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARCTIC_TIMES;
USE SCHEMA RAW;
USE WAREHOUSE COMPUTE_WH;

-- ---------------------------------------------------------------------------
-- File format + stages
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FILE FORMAT ARCTIC_TIMES.RAW.JSON_NDJSON
  TYPE = JSON
  STRIP_OUTER_ARRAY = FALSE;

CREATE STAGE IF NOT EXISTS ARCTIC_TIMES.RAW.GA4_STAGE;
CREATE STAGE IF NOT EXISTS ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE;
CREATE STAGE IF NOT EXISTS ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE;

-- ---------------------------------------------------------------------------
-- Upload local files (absolute paths; snow sql executes PUT client-side)
-- ---------------------------------------------------------------------------
PUT 'file:///Users/edendulk/code/lemonde/scripts/data_generation/output/ga4_stage/batch_1/*'
  @ARCTIC_TIMES.RAW.GA4_STAGE/batch_1/ OVERWRITE = TRUE AUTO_COMPRESS = TRUE;
PUT 'file:///Users/edendulk/code/lemonde/scripts/data_generation/output/ga4_stage/batch_2/*'
  @ARCTIC_TIMES.RAW.GA4_STAGE/batch_2/ OVERWRITE = TRUE AUTO_COMPRESS = TRUE;
PUT 'file:///Users/edendulk/code/lemonde/scripts/data_generation/output/ga4_variant/*'
  @ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE/ OVERWRITE = TRUE AUTO_COMPRESS = TRUE;
PUT 'file:///Users/edendulk/code/lemonde/scripts/data_generation/output/subscribers/*'
  @ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE/ OVERWRITE = TRUE AUTO_COMPRESS = TRUE;

-- ---------------------------------------------------------------------------
-- GA4_TRACKING — schema-evolution enabled; load batch_1 only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARCTIC_TIMES.RAW.GA4_TRACKING (
    event_name           VARCHAR,
    event_timestamp      VARCHAR,
    user_pseudo_id       VARCHAR,
    article_id           VARCHAR,
    section              VARCHAR,
    device_category      VARCHAR,
    browser              VARCHAR,
    os                   VARCHAR,
    country              VARCHAR,
    city                 VARCHAR,
    traffic_source       VARCHAR,
    traffic_medium       VARCHAR,
    engagement_time_sec  NUMBER,
    scroll_pct           NUMBER
)
ENABLE_SCHEMA_EVOLUTION = TRUE;

COPY INTO ARCTIC_TIMES.RAW.GA4_TRACKING
  FROM @ARCTIC_TIMES.RAW.GA4_STAGE/batch_1/
  FILE_FORMAT = (FORMAT_NAME = 'ARCTIC_TIMES.RAW.JSON_NDJSON')
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  ON_ERROR = ABORT_STATEMENT;

-- ---------------------------------------------------------------------------
-- GA4_EVENTS_VARIANT — nested VARIANT for dot-notation demo
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARCTIC_TIMES.RAW.GA4_EVENTS_VARIANT (raw_event VARIANT);

COPY INTO ARCTIC_TIMES.RAW.GA4_EVENTS_VARIANT
  FROM @ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE/
  FILE_FORMAT = (FORMAT_NAME = 'ARCTIC_TIMES.RAW.JSON_NDJSON')
  ON_ERROR = ABORT_STATEMENT;

-- ---------------------------------------------------------------------------
-- SUBSCRIBERS — PII + churn_flag/segment for ML
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE ARCTIC_TIMES.RAW.SUBSCRIBERS (
    user_id              VARCHAR,
    full_name            VARCHAR,
    email                VARCHAR,
    phone                VARCHAR,
    subscription_type    VARCHAR,
    start_date           DATE,
    last_login           TIMESTAMP_NTZ,
    articles_read_30d    NUMBER,
    avg_session_sec      NUMBER,
    paywall_bounces_30d  NUMBER,
    ltv_estimated_eur    FLOAT,
    segment              VARCHAR,
    churn_flag           BOOLEAN
);

COPY INTO ARCTIC_TIMES.RAW.SUBSCRIBERS
  FROM @ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE/
  FILE_FORMAT = (FORMAT_NAME = 'ARCTIC_TIMES.RAW.JSON_NDJSON')
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
  ON_ERROR = ABORT_STATEMENT;

-- ---------------------------------------------------------------------------
-- Sanity counts
-- ---------------------------------------------------------------------------
SELECT 'GA4_TRACKING'   AS tbl, COUNT(*) AS n FROM ARCTIC_TIMES.RAW.GA4_TRACKING
UNION ALL SELECT 'GA4_EVENTS_VARIANT', COUNT(*) FROM ARCTIC_TIMES.RAW.GA4_EVENTS_VARIANT
UNION ALL SELECT 'SUBSCRIBERS', COUNT(*) FROM ARCTIC_TIMES.RAW.SUBSCRIBERS;
