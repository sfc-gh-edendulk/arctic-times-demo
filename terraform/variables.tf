variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "arctic_times"
}

variable "snowflake_warehouse" {
  description = "Default warehouse for queries and transforms"
  type        = string
  default     = "COMPUTE_WH"
}

variable "iceberg_s3_bucket" {
  description = "S3 bucket for Iceberg table storage"
  type        = string
  default     = "my-iceberg-bucket"
}

variable "iceberg_base_path" {
  description = "Base path within S3 bucket for Iceberg data"
  type        = string
  default     = "arctic_times"
}

variable "snowflake_iam_user_arn" {
  description = "Snowflake IAM user ARN (from DESC STORAGE INTEGRATION)"
  type        = string
  default     = ""
}

variable "snowflake_external_id" {
  description = "Snowflake external ID for STS trust (from DESC STORAGE INTEGRATION)"
  type        = string
  default     = ""
}
