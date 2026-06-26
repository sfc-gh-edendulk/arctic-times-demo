# ------------------------------------------------------------------------------
# Database & Schemas
# ------------------------------------------------------------------------------

resource "snowflake_database" "arctic_times" {
  name    = "ARCTIC_TIMES"
  comment = "Demo press group — data platform on AWS + Snowflake"
}

resource "snowflake_schema" "raw" {
  database = snowflake_database.arctic_times.name
  name     = "RAW"
  comment  = "Landing zone — GA4 events, CMS CDC, subscribers"
}

resource "snowflake_schema" "curated" {
  database = snowflake_database.arctic_times.name
  name     = "CURATED"
  comment  = "Dynamic Tables — continuous aggregations"
}

resource "snowflake_schema" "marts" {
  database = snowflake_database.arctic_times.name
  name     = "MARTS"
  comment  = "dbt models — complex analytics"
}

resource "snowflake_schema" "portable" {
  database = snowflake_database.arctic_times.name
  name     = "PORTABLE"
  comment  = "Iceberg tables — open format on S3"
}

resource "snowflake_schema" "governance" {
  database = snowflake_database.arctic_times.name
  name     = "GOVERNANCE"
  comment  = "Masking policies + RBAC"
}

resource "snowflake_schema" "ml" {
  database = snowflake_database.arctic_times.name
  name     = "ML"
  comment  = "Python UDTFs + model artifacts"
}

resource "snowflake_schema" "ai" {
  database = snowflake_database.arctic_times.name
  name     = "AI"
  comment  = "Cortex Agent + Semantic View"
}

# ------------------------------------------------------------------------------
# Roles & Grants
# ------------------------------------------------------------------------------

resource "snowflake_account_role" "admin" {
  name    = "ARCTIC_TIMES_ADMIN"
  comment = "Full access to Arctic Times data including PII"
}

resource "snowflake_account_role" "analyst" {
  name    = "ARCTIC_TIMES_ANALYST"
  comment = "Analyst role — PII columns are masked"
}

resource "snowflake_account_role" "editorial" {
  name    = "ARCTIC_TIMES_EDITORIAL"
  comment = "Editorial role — article and content data only"
}

# Role hierarchy: ADMIN -> ANALYST -> EDITORIAL
resource "snowflake_grant_account_role" "admin_to_sysadmin" {
  role_name        = snowflake_account_role.admin.name
  parent_role_name = "SYSADMIN"
}

resource "snowflake_grant_account_role" "analyst_to_admin" {
  role_name        = snowflake_account_role.analyst.name
  parent_role_name = snowflake_account_role.admin.name
}

resource "snowflake_grant_account_role" "editorial_to_analyst" {
  role_name        = snowflake_account_role.editorial.name
  parent_role_name = snowflake_account_role.analyst.name
}

# Database grants
resource "snowflake_grant_privileges_to_account_role" "admin_db" {
  account_role_name = snowflake_account_role.admin.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.arctic_times.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_db" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.arctic_times.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "editorial_db" {
  account_role_name = snowflake_account_role.editorial.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.arctic_times.name
  }
}

# Schema grants — all schemas to ADMIN
resource "snowflake_grant_privileges_to_account_role" "admin_all_schemas" {
  account_role_name = snowflake_account_role.admin.name
  privileges        = ["USAGE", "CREATE TABLE", "CREATE VIEW", "CREATE DYNAMIC TABLE"]
  on_schema {
    all_schemas_in_database = snowflake_database.arctic_times.name
  }
}

# Analyst gets SELECT on all tables
resource "snowflake_grant_privileges_to_account_role" "analyst_select" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["SELECT"]
  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_database        = snowflake_database.arctic_times.name
    }
  }
}

# Warehouse grant
resource "snowflake_grant_privileges_to_account_role" "admin_wh" {
  account_role_name = snowflake_account_role.admin.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.snowflake_warehouse
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_wh" {
  account_role_name = snowflake_account_role.analyst.name
  privileges        = ["USAGE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.snowflake_warehouse
  }
}
