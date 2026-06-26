# Arctic Times — Snowflake Demo Platform

Full-stack data platform demo for a fictional French press group, showcasing AWS + Snowflake architecture.

## What this demonstrates

| Component | Snowflake Feature | Replaces (GCP) |
|-----------|------------------|----------------|
| Editorial CMS database | Snowflake Postgres | Cloud SQL |
| Real-time replication | Openflow CDC | Data Stream |
| Event ingestion | Snowpipe + Schema Evolution | BigQuery streaming |
| Continuous aggregations | Dynamic Tables | Scheduled queries |
| Complex transforms | dbt Projects on Snowflake | Dataform |
| Orchestration | Snowflake Tasks | Composer/Airflow |
| Open format storage | Iceberg on S3 | N/A (lock-in answer) |
| Data governance | Masking + RBAC | BigQuery IAM |
| AI assistant | Cortex Agent | N/A |
| ML inference | Python UDTF (scikit-learn) | SageMaker / Vertex |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ AWS (owned by customer)                                  │
│  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ Snowflake PG    │  │ S3                           │  │
│  │ (arctic_times_  │  │  ├── landing/  (GA4 exports) │  │
│  │  cms)           │  │  └── iceberg/  (open format) │  │
│  └────────┬────────┘  └──────────────┬──────────────┘  │
└───────────┼───────────────────────────┼─────────────────┘
            │ CDC < 5s                  │ auto-ingest
            ▼                           ▼
┌─────────────────────────────────────────────────────────┐
│ Snowflake (analytical platform)                          │
│                                                          │
│  RAW ──► CURATED (Dynamic Tables)                       │
│      ──► MARTS   (dbt Project, orchestrated by Tasks)   │
│      ──► PORTABLE (Iceberg tables → S3)                 │
│                                                          │
│  GOVERNANCE (masking policies, RBAC)                     │
│  ML        (Python UDTF churn model)                    │
│  AI        (Cortex Agent, Semantic View)                │
└─────────────────────────────────────────────────────────┘
            │
            ▼ (open access, no lock-in)
    Athena / Spark / Trino read Iceberg from S3
```

## Project structure

```
├── terraform/          # IaC for all Snowflake + AWS objects
├── dbt/                # dbt project (staging + marts models)
├── scripts/            # Data generation, setup, and demo helpers
├── notebooks/          # Snowflake notebooks (exploration, ML training)
├── docs/               # Demo run-through script, talking points
└── README.md
```

## Snowflake account

- **Account:** SFSENORTHAMERICA-LIZZY_USWEST (AWS us-west-2)
- **Database:** ARCTIC_TIMES
- **Iceberg volume:** ICEBERG_EXTERNAL_VOLUME → s3://edendulksnow/

## Quick start

```bash
# 1. Apply Terraform
cd terraform && terraform init && terraform plan

# 2. Generate synthetic data
cd ../scripts && python data_generation/generate_all.py

# 3. Deploy dbt project
cd ../dbt && snow dbt deploy

# 4. Run the demo
# Open docs/demo_script.sql in Snowsight
```
