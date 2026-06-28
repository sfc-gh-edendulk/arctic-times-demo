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

# PROVISIONING NOTE:
# The Terraform resource for Snowflake Postgres is in preview.
# Until GA, provision the instance via SQL:
#
#   CREATE POSTGRES INSTANCE ARCTIC_TIMES_CMS
#     COMPUTE_FAMILY = 'BURST_M'
#     STORAGE_SIZE_GB = 10
#     AUTHENTICATION_AUTHORITY = POSTGRES;
#
# Or use the Snowflake CLI: snow postgres create --name ARCTIC_TIMES_CMS ...
#
# Once the TF provider supports it, uncomment and apply:
#
# resource "snowflake_postgres_instance" "cms" {
#   name                     = "ARCTIC_TIMES_CMS"
#   compute_family           = "BURST_M"
#   storage_size_gb          = 10
#   authentication_authority = "POSTGRES"
#   comment                  = "Editorial CMS — articles, authors, calendar"
# }
