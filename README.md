# Arctic Times — Snowflake Demo Platform

Full-stack data platform demo for a fictional French press group, showcasing AWS + Snowflake architecture as a replacement for a GCP/BigQuery stack.

*Arctic Times is a fictional media company created for this demo.*

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
├── terraform/                  # IaC for all Snowflake + AWS objects
├── dbt/                        # dbt project (staging + marts models)
├── scripts/data_generation/    # Synthetic data generation
├── notebooks/                  # Snowflake notebooks (ML model training)
├── docs/                       # Demo run-through SQL script
├── bills/                      # Mock invoice comparison (GCP vs Snowflake)
├── DEPLOYMENT.md               # Full deployment guide
└── README.md
```

## Quick start

See [DEPLOYMENT.md](DEPLOYMENT.md) for full step-by-step instructions.

```bash
# 1. Apply Terraform (creates database, schemas, roles, S3 infra)
cd terraform && terraform init && terraform apply

# 2. Generate synthetic data
cd ../scripts/data_generation && pip install -r ../../requirements.txt && python generate_all.py

# 3. Deploy dbt project
cd ../../dbt && snow dbt deploy

# 4. Run the demo
# Open docs/demo_script.sql in Snowsight
```

## Prerequisites

- Snowflake account with Enterprise edition (for masking policies)
- AWS account (for S3 + IAM, used by Iceberg and Snowpipe)
- Snowflake features enabled: Postgres, Openflow, Cortex AI, Iceberg, dbt Projects
- Python 3.11+ (for data generation and notebook)
- Terraform 1.5+ with Snowflake provider

## Estimated cost

- **Snowflake credits:** ~50 credits for full demo setup and run-through
- **AWS:** Minimal (S3 storage + SQS — under $1/month for demo data volumes)
- **Warehouse:** XS or S sufficient for all operations

## Credits

Built for internal Snowflake demo purposes.
