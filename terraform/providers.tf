terraform {
  required_version = ">= 1.5"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 1.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "snowflake" {
  # Configure via environment variables or CLI config:
  # SNOWFLAKE_ORGANIZATION_NAME, SNOWFLAKE_ACCOUNT_NAME
  # Or set directly here:
  # organization_name = "YOUR_ORG"
  # account_name      = "YOUR_ACCOUNT"
}

provider "aws" {
  region = "us-west-2"
}
