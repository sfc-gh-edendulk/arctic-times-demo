# Arctic Times Demo — Agent Context

## Purpose

Full-stack Snowflake data platform demo targeting prospects migrating from GCP/BigQuery. Demonstrates 10 Snowflake capabilities in a connected story about a fictional French press group (Arctic Times).

## Key files

| File | Role |
|------|------|
| `terraform/*.tf` | IaC for all Snowflake + AWS objects |
| `dbt/` | dbt project with staging + mart models |
| `scripts/data_generation/generate_all.py` | Synthetic data generator (GA4 events, subscribers) |
| `scripts/setup_cortex_agent.sql` | Semantic View + Cortex Agent creation |
| `notebooks/churn_model_training.ipynb` | ML model training + UDTF deployment |
| `docs/demo_script.sql` | Full demo run-through (2 sessions, 20 min total) |
| `bills/` | Mock invoice comparison HTML files |
| `DEPLOYMENT.md` | Step-by-step deployment instructions |

## Snowflake objects

| Object | Schema | Purpose |
|--------|--------|---------|
| `ARCTIC_TIMES` | — | Main database |
| `RAW.GA4_TRACKING` | RAW | Schema evolution demo table |
| `RAW.GA4_EVENTS_VARIANT` | RAW | VARIANT dot-notation demo |
| `RAW.SUBSCRIBERS` | RAW | PII masking demo (80K rows) |
| `RAW.ARTICLES` | RAW | CDC from Postgres |
| `CURATED.READER_ENGAGEMENT` | CURATED | Dynamic Table (5-min lag) |
| `CURATED.ARTICLE_PERFORMANCE` | CURATED | Dynamic Table (10-min lag) |
| `MARTS.CONTENT_ANALYTICS` | MARTS | dbt mart |
| `MARTS.SUBSCRIBER_JOURNEY` | MARTS | dbt mart |
| `PORTABLE.ARTICLE_METRICS` | PORTABLE | Iceberg table on S3 |
| `GOVERNANCE.MASK_EMAIL` | GOVERNANCE | Masking policy |
| `ML.PREDICT_CHURN` | ML | Python UDTF |
| `AI.EDITORIAL_ASSISTANT` | AI | Cortex Agent |
| `AI.CONTENT_SV` | AI | Semantic View |
| `ARCTIC_TIMES_CMS` | — | Snowflake Postgres instance |

## Roles

- `ARCTIC_TIMES_ADMIN` — full access including PII
- `ARCTIC_TIMES_ANALYST` — SELECT with masked PII
- `ARCTIC_TIMES_EDITORIAL` — article/content data only

## Demo flow

- **Session 1 (8 min):** Schema evolution, VARIANT querying, column masking
- **Session 2 (12 min):** Postgres, Openflow CDC, Dynamic Tables + dbt, Iceberg, Cortex Agent, Python UDTF

## Development conventions

- Terraform manages all infrastructure; SQL manages runtime objects (DTs, agents)
- dbt project uses `snow dbt deploy` (Snowflake-native dbt)
- Data generation is Python-based, outputs JSON for COPY INTO
- All SQL in demo_script.sql is idempotent and annotated with `[COMPARE TO BIGQUERY]` and `[TERRAFORM]` markers

## Known issues

- `terraform/postgres.tf` is commented out (TF resource not GA yet) — provision PG via SQL
- Openflow connector must be deployed manually via UI/API

## Connection info

- Default warehouse: configurable in `terraform/variables.tf`
- dbt profile: `dbt/profiles.yml` (uses external auth, no embedded credentials)
- Notebook connection: uses Snowflake CLI connection config
