# ------------------------------------------------------------------------------
# AWS Resources — S3 + IAM for Iceberg & Snowpipe
# ------------------------------------------------------------------------------
#
# This shows what the customer would provision on their side.
#

# S3 bucket for Iceberg table data (open format)
resource "aws_s3_bucket" "iceberg" {
  bucket = "${var.iceberg_s3_bucket}"

  tags = {
    Project     = var.project_name
    Purpose     = "Iceberg table storage — open format, queryable from Athena/Spark"
    ManagedBy   = "Terraform"
  }
}

# S3 bucket for GA4 landing zone (Snowpipe auto-ingest)
resource "aws_s3_bucket" "landing" {
  bucket = "${var.iceberg_s3_bucket}-landing"

  tags = {
    Project   = var.project_name
    Purpose   = "GA4 export landing zone — Snowpipe auto-ingest"
    ManagedBy = "Terraform"
  }
}

# IAM role that Snowflake assumes to read/write Iceberg data
resource "aws_iam_role" "snowflake_iceberg" {
  name = "${var.project_name}-snowflake-iceberg"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = var.snowflake_iam_user_arn  # From DESC STORAGE INTEGRATION
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.snowflake_external_id  # From DESC STORAGE INTEGRATION
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "snowflake_s3_access" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.snowflake_iceberg.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.iceberg_s3_bucket}",
          "arn:aws:s3:::${var.iceberg_s3_bucket}/*"
        ]
      }
    ]
  })
}

# SQS queue for Snowpipe auto-ingest notifications
resource "aws_sqs_queue" "snowpipe_notifications" {
  name                       = "${var.project_name}-snowpipe-notifications"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 300

  tags = {
    Project   = var.project_name
    Purpose   = "S3 event notifications for Snowpipe auto-ingest"
    ManagedBy = "Terraform"
  }
}

# S3 event notification → SQS when new GA4 files land
resource "aws_s3_bucket_notification" "ga4_landing" {
  bucket = aws_s3_bucket.landing.id

  queue {
    queue_arn     = aws_sqs_queue.snowpipe_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "ga4/"
    filter_suffix = ".json"
  }
}
