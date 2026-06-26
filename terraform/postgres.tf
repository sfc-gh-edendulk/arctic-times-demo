# ------------------------------------------------------------------------------
# Snowflake Postgres Instance (Editorial CMS)
# ------------------------------------------------------------------------------
#
# Snowflake-managed PostgreSQL instance simulating the editorial CMS.
# Replaces Cloud SQL in the GCP stack.
#
# Note: Snowflake Postgres Terraform resource is preview. This documents the
# equivalent SQL: CREATE POSTGRES INSTANCE ARCTIC_TIMES_CMS
#   COMPUTE_FAMILY = 'BURST_M'
#   STORAGE_SIZE_GB = 10
#   AUTHENTICATION_AUTHORITY = POSTGRES;
#

# Placeholder — use pg_connect.py for actual provisioning until TF resource GA
# resource "snowflake_postgres_instance" "cms" {
#   name                     = "ARCTIC_TIMES_CMS"
#   compute_family           = "BURST_M"
#   storage_size_gb          = 10
#   authentication_authority = "POSTGRES"
#   comment                  = "Editorial CMS — articles, authors, calendar"
# }
