# ------------------------------------------------------------------------------
# Masking Policies (Data Governance)
# ------------------------------------------------------------------------------

resource "snowflake_masking_policy" "mask_email" {
  database = snowflake_database.arctic_times.name
  schema   = snowflake_schema.governance.name
  name     = "MASK_EMAIL"
  comment  = "Masks email addresses for non-admin roles"

  argument {
    name = "val"
    type = "VARCHAR"
  }
  body            = <<-EOT
    CASE
      WHEN CURRENT_ROLE() IN ('ARCTIC_TIMES_ADMIN', 'ACCOUNTADMIN') THEN val
      ELSE REGEXP_REPLACE(val, '.+@', '****@')
    END
  EOT
  return_data_type = "VARCHAR"
}

resource "snowflake_masking_policy" "mask_name" {
  database = snowflake_database.arctic_times.name
  schema   = snowflake_schema.governance.name
  name     = "MASK_NAME"
  comment  = "Masks full names for non-admin roles"

  argument {
    name = "val"
    type = "VARCHAR"
  }
  body            = <<-EOT
    CASE
      WHEN CURRENT_ROLE() IN ('ARCTIC_TIMES_ADMIN', 'ACCOUNTADMIN') THEN val
      ELSE '*** MASKED ***'
    END
  EOT
  return_data_type = "VARCHAR"
}

resource "snowflake_masking_policy" "mask_phone" {
  database = snowflake_database.arctic_times.name
  schema   = snowflake_schema.governance.name
  name     = "MASK_PHONE"
  comment  = "Masks phone numbers — shows only last 2 digits"

  argument {
    name = "val"
    type = "VARCHAR"
  }
  body            = <<-EOT
    CASE
      WHEN CURRENT_ROLE() IN ('ARCTIC_TIMES_ADMIN', 'ACCOUNTADMIN') THEN val
      ELSE CONCAT('+33 **** ** ', RIGHT(val, 2))
    END
  EOT
  return_data_type = "VARCHAR"
}
