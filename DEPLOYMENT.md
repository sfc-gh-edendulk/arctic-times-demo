# Deployment Guide — Arctic Times Demo

## Prerequisites

| Requirement | Detail |
|-------------|--------|
| Snowflake edition | Enterprise (required for masking policies) |
| Snowflake region | AWS (any region; us-west-2 tested) |
| Snowflake features | Postgres, Openflow, Cortex AI, Iceberg, dbt Projects |
| Snowflake role | ACCOUNTADMIN or SYSADMIN with CREATE DATABASE |
| AWS account | For S3 bucket + IAM role (Iceberg + Snowpipe) |
| Local tools | Terraform 1.5+, Python 3.11+, Snowflake CLI (`snow`) |
| Warehouse | XS or S (named in `terraform/variables.tf`) |

## Estimated credits

| Phase | Credits | Notes |
|-------|---------|-------|
| Terraform apply | ~2 | DDL operations |
| Data generation + COPY INTO | ~5 | 300K events + 80K subscribers |
| Dynamic Table initial refresh | ~3 | Two DTs |
| dbt Project deploy + run | ~5 | 3 models |
| Iceberg table creation | ~2 | CTAS from DTs |
| Cortex Agent creation | ~1 | Semantic view + agent |
| ML model training (notebook) | ~5 | GradientBoosting on 80K rows |
| Demo run-through | ~5 | Ad-hoc queries |
| **Total** | **~28-50** | Depends on warehouse size |

## Step-by-step deployment

### 1. Configure Terraform variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
# Required — your values
snowflake_warehouse = "YOUR_WAREHOUSE"  # e.g. "COMPUTE_WH"
iceberg_s3_bucket   = "YOUR_BUCKET"     # e.g. "my-iceberg-data"

# Optional — defaults work for most setups
project_name     = "arctic_times"
iceberg_base_path = "arctic_times"
```

### 2. Apply Terraform

```bash
terraform init
terraform plan    # Review what will be created
terraform apply   # Creates: database, schemas, roles, grants, S3, IAM, masking policies
```

This creates:
- Database `ARCTIC_TIMES` with 7 schemas
- 3 roles (ARCTIC_TIMES_ADMIN, ANALYST, EDITORIAL) with proper hierarchy
- S3 buckets for Iceberg + landing zone
- IAM role with trust policy for Snowflake
- Masking policies (email, name, phone)

### 3. Create Snowflake Postgres instance

```sql
-- Run in Snowsight or via snow CLI
CREATE POSTGRES INSTANCE ARCTIC_TIMES_CMS
  COMPUTE_FAMILY = 'BURST_M'
  STORAGE_SIZE_GB = 10
  AUTHENTICATION_AUTHORITY = POSTGRES;
```

Wait for the instance to reach `READY` state:
```sql
SHOW POSTGRES INSTANCES;
```

Then create the editorial tables (connect via psql or any PG client):
```sql
CREATE TABLE articles (
    article_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    slug TEXT,
    author_id INT,
    section TEXT,
    publication TEXT,
    published_at TIMESTAMPTZ DEFAULT NOW(),
    word_count INT,
    paywall_type TEXT DEFAULT 'none',
    tags JSONB,
    status TEXT DEFAULT 'draft'
);

CREATE TABLE authors (
    author_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    section TEXT,
    seniority TEXT,
    bio TEXT
);

CREATE TABLE editorial_calendar (
    entry_id SERIAL PRIMARY KEY,
    article_id INT REFERENCES articles(article_id),
    planned_date DATE,
    editor_notes TEXT,
    priority TEXT DEFAULT 'normal',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 4. Set up Openflow CDC

Deploy an Openflow CDC connector from ARCTIC_TIMES_CMS to ARCTIC_TIMES.RAW:
- Source: `ARCTIC_TIMES_CMS` PostgreSQL instance
- Destination schema: `ARCTIC_TIMES.RAW`
- Tables: `articles`, `authors`, `editorial_calendar`
- Mode: CDC (logical replication)

### 5. Generate and load synthetic data

```bash
cd scripts/data_generation
pip install -r ../../requirements.txt
python generate_all.py
```

Then upload to Snowflake stages and load:
```sql
-- Create stages
CREATE STAGE ARCTIC_TIMES.RAW.GA4_STAGE;
CREATE STAGE ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE;
CREATE STAGE ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE;

-- Upload files (from scripts/data_generation/)
PUT file://output/ga4_stage/batch_1/* @ARCTIC_TIMES.RAW.GA4_STAGE/batch_1/;
PUT file://output/ga4_stage/batch_2/* @ARCTIC_TIMES.RAW.GA4_STAGE/batch_2/;
PUT file://output/ga4_variant/* @ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE/;
PUT file://output/subscribers/* @ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE/;

-- Create tables and load (schema evolution demo)
CREATE TABLE ARCTIC_TIMES.RAW.GA4_TRACKING
  ENABLE_SCHEMA_EVOLUTION = TRUE
  AS SELECT * FROM @ARCTIC_TIMES.RAW.GA4_STAGE/batch_1/ (FILE_FORMAT => 'JSON') WHERE 1=0;

CREATE TABLE ARCTIC_TIMES.RAW.GA4_EVENTS_VARIANT (raw_event VARIANT);

CREATE TABLE ARCTIC_TIMES.RAW.SUBSCRIBERS (
    user_id VARCHAR, full_name VARCHAR, email VARCHAR, phone VARCHAR,
    subscription_type VARCHAR, start_date DATE, last_login TIMESTAMP_NTZ,
    articles_read_30d NUMBER, avg_session_sec NUMBER, paywall_bounces_30d NUMBER,
    ltv_estimated_eur FLOAT
);

-- Load subscribers
COPY INTO ARCTIC_TIMES.RAW.SUBSCRIBERS
FROM @ARCTIC_TIMES.RAW.SUBSCRIBER_STAGE
FILE_FORMAT = (TYPE='JSON');

-- Load VARIANT events
COPY INTO ARCTIC_TIMES.RAW.GA4_EVENTS_VARIANT
FROM @ARCTIC_TIMES.RAW.GA4_VARIANT_STAGE
FILE_FORMAT = (TYPE='JSON');
```

Note: GA4_TRACKING batch loads are done during the demo to show schema evolution live.

### 6. Deploy dbt project

```bash
cd dbt
snow dbt deploy
```

Run the models:
```sql
EXECUTE DBT PROJECT ARCTIC_TIMES.MARTS.ARCTIC_TIMES_DBT;
```

### 7. Create Dynamic Tables

See `docs/demo_script.sql` Section 6, or create them directly:

```sql
CREATE OR REPLACE DYNAMIC TABLE ARCTIC_TIMES.CURATED.READER_ENGAGEMENT
  TARGET_LAG = '5 minutes'
  WAREHOUSE = <YOUR_WAREHOUSE>
AS
SELECT
    DATE_TRUNC('day', event_timestamp) AS day,
    section, COUNT(DISTINCT user_pseudo_id) AS unique_readers,
    COUNT(*) AS page_views, AVG(engagement_time_sec) AS avg_engagement_sec,
    COUNT_IF(event_name = 'paywall_hit') AS paywall_hits,
    COUNT_IF(event_name = 'subscribe_click') AS subscribe_clicks
FROM ARCTIC_TIMES.RAW.GA4_EVENTS
GROUP BY 1, 2;
```

### 8. Create Iceberg tables

Requires an External Volume pointing to your S3 bucket:
```sql
CREATE OR REPLACE EXTERNAL VOLUME ICEBERG_EXTERNAL_VOLUME
  STORAGE_LOCATIONS = (
    (NAME = 'iceberg-s3' STORAGE_BASE_URL = 's3://<YOUR_BUCKET>/'
     STORAGE_PROVIDER = 'S3' STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<YOUR_ACCOUNT>:role/...')
  ) ALLOW_WRITES = TRUE;

CREATE ICEBERG TABLE ARCTIC_TIMES.PORTABLE.ARTICLE_METRICS
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'ICEBERG_EXTERNAL_VOLUME'
  BASE_LOCATION = 'arctic_times/article_metrics/'
AS SELECT * FROM ARCTIC_TIMES.CURATED.ARTICLE_PERFORMANCE;
```

### 9. Train and deploy ML model

Open `notebooks/churn_model_training.ipynb` in Snowflake Notebooks and run all cells. This trains a GradientBoosting churn model and deploys it as `ARCTIC_TIMES.ML.PREDICT_CHURN` UDTF.

### 10. Create Cortex Agent

Run the setup script:
```sql
-- Execute scripts/setup_cortex_agent.sql in Snowsight
-- This creates:
--   1. ARCTIC_TIMES.AI.CONTENT_SV (semantic view over articles + engagement)
--   2. ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT (French-speaking Cortex Agent)
```

Or use the Snowflake CLI:
```bash
snow sql -f scripts/setup_cortex_agent.sql
```

Verify:
```sql
SELECT SNOWFLAKE.CORTEX.AGENT(
  'ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT',
  'Quels articles ont le meilleur engagement?'
);
```

## Post-deployment verification

| Check | Command |
|-------|---------|
| Database exists | `SHOW DATABASES LIKE 'ARCTIC_TIMES'` |
| Schemas created | `SHOW SCHEMAS IN DATABASE ARCTIC_TIMES` |
| Roles exist | `SHOW ROLES LIKE 'ARCTIC_TIMES%'` |
| PG instance ready | `SHOW POSTGRES INSTANCES` |
| Data loaded | `SELECT COUNT(*) FROM ARCTIC_TIMES.RAW.SUBSCRIBERS` (expect 80,000) |
| Masking works | `USE ROLE ARCTIC_TIMES_ANALYST; SELECT email FROM ARCTIC_TIMES.RAW.SUBSCRIBERS LIMIT 1;` |
| DT refreshing | `SELECT * FROM TABLE(INFORMATION_SCHEMA.DYNAMIC_TABLE_REFRESH_HISTORY(...))` |
| Iceberg files | Check S3 console for Parquet files |
| Agent responds | Ask: "Quels articles ont le meilleur engagement?" |

## Cleanup / Teardown

```sql
-- Remove all demo objects
DROP DATABASE IF EXISTS ARCTIC_TIMES;
DROP ROLE IF EXISTS ARCTIC_TIMES_ADMIN;
DROP ROLE IF EXISTS ARCTIC_TIMES_ANALYST;
DROP ROLE IF EXISTS ARCTIC_TIMES_EDITORIAL;

-- Postgres instance
DROP POSTGRES INSTANCE IF EXISTS ARCTIC_TIMES_CMS;

-- External volume (if created for this demo only)
DROP EXTERNAL VOLUME IF EXISTS ICEBERG_EXTERNAL_VOLUME;
```

For AWS resources:
```bash
cd terraform && terraform destroy
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Masking policy doesn't apply | Ensure role grants are applied: `GRANT ROLE ARCTIC_TIMES_ANALYST TO USER <you>` |
| Schema evolution doesn't show new cols | Verify `ENABLE_SCHEMA_EVOLUTION = TRUE` on GA4_TRACKING table |
| Openflow latency > 5s | Check Openflow runtime status; may need RESUME |
| Iceberg table creation fails | Verify External Volume trust policy has your Snowflake account's IAM user ARN |
| dbt deploy fails | Ensure `snow` CLI is authenticated and dbt Projects feature is enabled |
| Cortex Agent errors | Verify Cortex AI is available in your region; check semantic view exists |
| Notebook kernel fails | Ensure scikit-learn, pandas, numpy are available in the notebook environment |
