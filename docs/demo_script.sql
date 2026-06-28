-- ============================================================================
-- ARCTIC TIMES — Demo Run-Through Script
-- ============================================================================
-- Account: <YOUR_ORG-YOUR_ACCOUNT>
-- Duration: Session 1 (8 min) + Session 2 (12 min)
-- 
-- Each section addresses one of the prospect's stated concerns.
-- [COMPARE TO BIGQUERY] annotations show the contrast.
-- [TERRAFORM] annotations show IaC-ability.
-- ============================================================================

USE DATABASE ARCTIC_TIMES;
USE WAREHOUSE IDENTIFIER($warehouse);  -- Set: SET warehouse = 'YOUR_WH';

-- ============================================================================
-- SESSION 1: Why Snowflake is different from BigQuery (8 min)
-- ============================================================================

-- === SECTION 1 (0-3 min) — SCHEMA EVOLUTION ===
-- [COMPARE TO BIGQUERY] BQ requires explicit ALTER TABLE ADD COLUMN.
-- If a JSON payload adds a field, your pipeline breaks or silently drops it.
-- [TERRAFORM] snowflake_table { enable_schema_evolution = true }

-- Show: table before ingestion
DESCRIBE TABLE RAW.GA4_TRACKING;

-- Load batch 1 — standard GA4 schema
COPY INTO RAW.GA4_TRACKING
FROM @RAW.GA4_STAGE/batch_1/
FILE_FORMAT = (TYPE = 'JSON')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load batch 2 — NEW FIELDS: consent_state, engagement_score, ab_test_variant
-- No DDL change needed. The table adapts automatically.
COPY INTO RAW.GA4_TRACKING
FROM @RAW.GA4_STAGE/batch_2/
FILE_FORMAT = (TYPE = 'JSON')
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Show: new columns appeared automatically
DESCRIBE TABLE RAW.GA4_TRACKING;
-- consent_state, engagement_score, ab_test_variant are now here!

-- Query the new fields immediately
SELECT consent_state, engagement_score, ab_test_variant, COUNT(*)
FROM RAW.GA4_TRACKING
WHERE consent_state IS NOT NULL
GROUP BY 1, 2, 3
LIMIT 10;


-- === SECTION 2 (3-5 min) — VARIANT / SEMI-STRUCTURED ===
-- [COMPARE TO BIGQUERY] JSON_EXTRACT_SCALAR(raw, '$.device.browser') — verbose, no dot notation
-- [TERRAFORM] Standard table definition, VARIANT is a native type

-- Dot notation on nested JSON — no parsing functions needed
SELECT
    raw_event:user_pseudo_id::STRING AS user_id,
    raw_event:device.category::STRING AS device,
    raw_event:device.browser::STRING AS browser,
    raw_event:geo.country::STRING AS country,
    raw_event:geo.city::STRING AS city,
    raw_event:traffic_source.source::STRING AS source,
    raw_event:traffic_source.medium::STRING AS medium
FROM RAW.GA4_EVENTS_VARIANT
WHERE raw_event:geo.country = 'FR'
LIMIT 10;

-- FLATTEN — explode arrays natively
SELECT
    raw_event:user_pseudo_id::STRING AS user_id,
    f.value:key::STRING AS param_key,
    f.value:value::STRING AS param_value
FROM RAW.GA4_EVENTS_VARIANT,
    LATERAL FLATTEN(input => raw_event:event_params) f
WHERE f.value:key = 'article_section'
LIMIT 10;


-- === SECTION 3 (5-8 min) — DATA GOVERNANCE (MASKING + RBAC) ===
-- [COMPARE TO BIGQUERY] IAM-based, no column-level masking without views
-- [TERRAFORM] snowflake_masking_policy + snowflake_grant_privileges_to_account_role

-- Same query, two different roles, two different results:

-- As ADMIN: full PII visible
USE ROLE ARCTIC_TIMES_ADMIN;
SELECT user_id, full_name, email, phone, subscription_type, ltv_estimated_eur
FROM ARCTIC_TIMES.RAW.SUBSCRIBERS
LIMIT 5;

-- As ANALYST: PII is masked (email, name, phone)
USE ROLE ARCTIC_TIMES_ANALYST;
SELECT user_id, full_name, email, phone, subscription_type, ltv_estimated_eur
FROM ARCTIC_TIMES.RAW.SUBSCRIBERS
LIMIT 5;

-- Reset
USE ROLE ACCOUNTADMIN;


-- ============================================================================
-- SESSION 2: Your architecture on AWS + Snowflake (12 min)
-- ============================================================================

-- === SECTION 4 (0-2 min) — SNOWFLAKE POSTGRES ===
-- [COMPARE TO BIGQUERY] Cloud SQL is separate from BQ — separate billing, networking, no integration
-- Here: managed PG, same account, same governance, same Terraform state

SHOW POSTGRES INSTANCES;
-- ARCTIC_TIMES_CMS — READY, BURST_M, 10GB

-- Same psql you already know:
-- psql "service=arctic_times_cms connect_timeout=10" -c "SELECT COUNT(*) FROM articles;"


-- === SECTION 5 (2-5 min) — OPENFLOW CDC ===
-- [COMPARE TO BIGQUERY] Data Stream + Dataflow (Java/Beam code) → complex, fragile
-- Here: fully managed, zero code, < 5 seconds

-- INSERT a new article in Postgres (done via psql or shown in terminal):
-- INSERT INTO articles (title, author_id, section, publication, published_at, status)
-- VALUES ('Breaking: Arctic Ice Record Low', 3, 'Sciences', 'Arctic Times', NOW(), 'published');

-- Wait 3 seconds...
SELECT article_id, title, section, published_at
FROM RAW.ARTICLES
ORDER BY published_at DESC
LIMIT 5;
-- The new article is here. < 5 seconds, no code, no Beam pipeline.


-- === SECTION 6 (5-7 min) — DYNAMIC TABLES + dbt + TASKS ===
-- [COMPARE TO BIGQUERY] Scheduled queries (fragile cron) + Dataform (GCP lock-in)
-- Here: Dynamic Tables for continuous, dbt for complex, Tasks for orchestration

-- Dynamic Table — continuous, incremental, declarative
SELECT * FROM CURATED.READER_ENGAGEMENT
WHERE day >= DATEADD('day', -7, CURRENT_DATE())
ORDER BY unique_readers DESC
LIMIT 10;

-- Check it's actually refreshing incrementally
SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(
    NAME => 'ARCTIC_TIMES.CURATED.READER_ENGAGEMENT'
)) ORDER BY REFRESH_START_TIME DESC LIMIT 5;

-- dbt project — complex models, deployed to Snowflake, orchestrated by Task
SHOW TASKS IN SCHEMA ARCTIC_TIMES.MARTS;
-- RUN_DBT_CONTENT — CRON every 4 hours

-- Show a dbt mart result
SELECT performance_tier, COUNT(*) AS articles, AVG(conversion_rate_pct) AS avg_conversion
FROM MARTS.CONTENT_ANALYTICS
GROUP BY 1 ORDER BY 2 DESC;


-- === SECTION 7 (7-9 min) — ICEBERG ON S3 ===
-- [COMPARE TO BIGQUERY] Data is locked in BigQuery. Export is a batch job.
-- Here: Iceberg = open Parquet on YOUR S3. Athena, Spark, Trino read it now.
-- [TERRAFORM] aws_s3_bucket + snowflake_external_volume + CREATE ICEBERG TABLE

SELECT article_id, title, section, unique_readers, performance_tier
FROM PORTABLE.ARTICLE_METRICS
WHERE section = 'Sciences'
ORDER BY unique_readers DESC
LIMIT 10;

-- Show: same query, same performance. But the data is Parquet in S3.
-- Open AWS console → s3://<YOUR_BUCKET>/arctic_times/article_metrics/data/
-- These files are readable by Athena / Spark / Trino RIGHT NOW.


-- === SECTION 8 (9-11 min) — CORTEX AGENT ===
-- [COMPARE TO BIGQUERY] Nothing equivalent. Would need Vertex AI + custom code.
-- Here: editorial staff ask questions in French. No SQL. No dashboard training.

-- Example queries the agent handles:
-- "Quels articles ont le meilleur engagement cette semaine?"
-- "Quelle section perd des lecteurs par rapport au mois dernier?"
-- "Montre-moi les articles premium avec un fort taux de rebond"

-- (Demo in Snowflake Intelligence UI or via API call)


-- === SECTION 9 (11-12 min) — BONUS: PYTHON UDTF CHURN MODEL ===
-- [COMPARE TO BIGQUERY] Needs Vertex AI or SageMaker. Data leaves the warehouse.
-- Here: scikit-learn model runs inside Snowflake as a SQL function. Zero data movement.
-- [TERRAFORM] Model artifact on stage, function definition in SQL

SELECT 
    s.user_id,
    s.subscription_type,
    s.ltv_estimated_eur,
    c.churn_probability,
    c.risk_segment
FROM RAW.SUBSCRIBERS s,
    TABLE(ML.PREDICT_CHURN(
        DATEDIFF('day', s.last_login, CURRENT_DATE()),
        s.articles_read_30d,
        DATEDIFF('month', s.start_date, CURRENT_DATE()),
        s.avg_session_sec,
        s.paywall_bounces_30d
    )) c
WHERE c.risk_segment = 'HIGH'
ORDER BY s.ltv_estimated_eur DESC
LIMIT 20;

-- "80 subscribers at high churn risk, sorted by lifetime value.
-- Marketing can act on this TODAY. No ML pipeline to build."


-- ============================================================================
-- RESET (for re-running the demo)
-- ============================================================================
-- TRUNCATE TABLE RAW.GA4_TRACKING;
-- (re-run data generation scripts to repopulate)
