# ------------------------------------------------------------------------------
# Iceberg Tables — Open Format on S3
# ------------------------------------------------------------------------------
#
# Uses the External Volume configured in your account (see DEPLOYMENT.md step 8).
# In production, the customer would create their own external volume with their
# IAM role and S3 bucket — shown in aws.tf
#

resource "snowflake_table" "article_metrics_iceberg" {
  # Note: As of provider v1.x, Iceberg tables use SQL-based provisioning
  # This is the Terraform representation of what the SQL creates.
  # Actual creation via: scripts/setup_iceberg.sql
  database = snowflake_database.arctic_times.name
  schema   = snowflake_schema.portable.name
  name     = "ARTICLE_METRICS"
  comment  = "Article performance metrics — Iceberg format on S3 (open, portable)"

  column {
    name = "ARTICLE_ID"
    type = "VARCHAR"
  }
  column {
    name = "TITLE"
    type = "VARCHAR"
  }
  column {
    name = "SECTION"
    type = "VARCHAR"
  }
  column {
    name = "UNIQUE_READERS"
    type = "NUMBER(38,0)"
  }
  column {
    name = "AVG_READ_TIME_SEC"
    type = "FLOAT"
  }
  column {
    name = "DEEP_READS"
    type = "NUMBER(38,0)"
  }
  column {
    name = "SHARES"
    type = "NUMBER(38,0)"
  }

  # In practice, this is created as:
  # CREATE ICEBERG TABLE ... CATALOG='SNOWFLAKE'
  #   EXTERNAL_VOLUME='ICEBERG_EXTERNAL_VOLUME'
  #   BASE_LOCATION='arctic_times/article_metrics/'
}

# ------------------------------------------------------------------------------
# Dynamic Tables
# ------------------------------------------------------------------------------

# Note: Dynamic Tables are managed via SQL (scripts/setup_dynamic_tables.sql)
# Terraform resource for documentation/drift detection:

# CREATE DYNAMIC TABLE ARCTIC_TIMES.CURATED.READER_ENGAGEMENT
#   TARGET_LAG = '5 minutes'
#   WAREHOUSE = var.snowflake_warehouse
#   AS SELECT ... FROM ARCTIC_TIMES.RAW.ARTICLES a JOIN ARCTIC_TIMES.RAW.GA4_EVENTS e ...;
