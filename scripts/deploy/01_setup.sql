-- ============================================================================
-- Arctic Times — 01 Foundation: Database, Schemas, Roles, Grants, ML Stage
-- ============================================================================
-- Idempotent. Run with:
--   snow sql -f scripts/deploy/01_setup.sql --connection lemondetrial
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ---------------------------------------------------------------------------
-- Database & Schemas
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS ARCTIC_TIMES
  COMMENT = 'Demo press group — data platform on Snowflake';

CREATE SCHEMA IF NOT EXISTS ARCTIC_TIMES.RAW
  COMMENT = 'Landing zone — GA4 events, editorial CMS, subscribers';
CREATE SCHEMA IF NOT EXISTS ARCTIC_TIMES.CURATED
  COMMENT = 'Dynamic Tables — continuous aggregations';
CREATE SCHEMA IF NOT EXISTS ARCTIC_TIMES.MARTS
  COMMENT = 'dbt models — complex analytics';
CREATE SCHEMA IF NOT EXISTS ARCTIC_TIMES.GOVERNANCE
  COMMENT = 'Masking policies + RBAC';
CREATE SCHEMA IF NOT EXISTS ARCTIC_TIMES.AI
  COMMENT = 'Cortex Agent + Semantic View';
CREATE SCHEMA IF NOT EXISTS ARCTIC_TIMES.ML
  COMMENT = 'Python UDTFs + model artifacts';

-- Stage for serialized ML model artifacts
CREATE STAGE IF NOT EXISTS ARCTIC_TIMES.ML.MODELS
  COMMENT = 'Serialized model files for churn UDTF';

-- ---------------------------------------------------------------------------
-- Roles & hierarchy:  ACCOUNTADMIN > SYSADMIN > ADMIN > ANALYST > EDITORIAL
-- ---------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS ARCTIC_TIMES_ADMIN
  COMMENT = 'Full access to Arctic Times data including PII';
CREATE ROLE IF NOT EXISTS ARCTIC_TIMES_ANALYST
  COMMENT = 'Analyst role — PII columns are masked';
CREATE ROLE IF NOT EXISTS ARCTIC_TIMES_EDITORIAL
  COMMENT = 'Editorial role — article and content data only';

GRANT ROLE ARCTIC_TIMES_ADMIN     TO ROLE SYSADMIN;
GRANT ROLE ARCTIC_TIMES_ANALYST   TO ROLE ARCTIC_TIMES_ADMIN;
GRANT ROLE ARCTIC_TIMES_EDITORIAL TO ROLE ARCTIC_TIMES_ANALYST;

-- Let the current user assume the demo roles (for masking demo etc.)
GRANT ROLE ARCTIC_TIMES_ADMIN     TO USER EDENDULK;
GRANT ROLE ARCTIC_TIMES_ANALYST   TO USER EDENDULK;
GRANT ROLE ARCTIC_TIMES_EDITORIAL TO USER EDENDULK;

-- ---------------------------------------------------------------------------
-- Warehouse usage
-- ---------------------------------------------------------------------------
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ARCTIC_TIMES_ADMIN;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ARCTIC_TIMES_ANALYST;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ARCTIC_TIMES_EDITORIAL;

-- ---------------------------------------------------------------------------
-- Database / schema usage
-- ---------------------------------------------------------------------------
GRANT USAGE ON DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ADMIN;
GRANT USAGE ON DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;
GRANT USAGE ON DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_EDITORIAL;

GRANT USAGE ON ALL SCHEMAS IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ADMIN;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;

-- Editorial: content schemas only
GRANT USAGE ON SCHEMA ARCTIC_TIMES.RAW     TO ROLE ARCTIC_TIMES_EDITORIAL;
GRANT USAGE ON SCHEMA ARCTIC_TIMES.CURATED TO ROLE ARCTIC_TIMES_EDITORIAL;
GRANT USAGE ON SCHEMA ARCTIC_TIMES.AI      TO ROLE ARCTIC_TIMES_EDITORIAL;

-- ---------------------------------------------------------------------------
-- Object privileges
-- ---------------------------------------------------------------------------
-- ADMIN: build everything
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE, CREATE STAGE,
      CREATE FILE FORMAT, CREATE FUNCTION, CREATE SEMANTIC VIEW
  ON ALL SCHEMAS IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ADMIN;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE, CREATE STAGE,
      CREATE FILE FORMAT, CREATE FUNCTION, CREATE SEMANTIC VIEW
  ON FUTURE SCHEMAS IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ADMIN;

-- ANALYST: read all tables/views (PII masked via policies)
GRANT SELECT ON ALL TABLES    IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;
GRANT SELECT ON FUTURE TABLES IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;
GRANT SELECT ON ALL VIEWS     IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;
GRANT SELECT ON FUTURE VIEWS  IN DATABASE ARCTIC_TIMES TO ROLE ARCTIC_TIMES_ANALYST;

-- EDITORIAL: read content tables in RAW/CURATED
GRANT SELECT ON FUTURE TABLES IN SCHEMA ARCTIC_TIMES.RAW     TO ROLE ARCTIC_TIMES_EDITORIAL;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ARCTIC_TIMES.CURATED TO ROLE ARCTIC_TIMES_EDITORIAL;

SELECT 'Foundation complete: database, schemas, roles, grants, ML stage' AS status;
