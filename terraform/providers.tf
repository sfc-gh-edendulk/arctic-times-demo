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
  organization_name = "SFSENORTHAMERICA"
  account_name      = "LIZZY_USWEST"
  role              = "ACCOUNTADMIN"
}

provider "aws" {
  region = "us-west-2"
}
