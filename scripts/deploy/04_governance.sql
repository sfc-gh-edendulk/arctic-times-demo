-- ============================================================================
-- Arctic Times — 04 Governance: Masking Policies on Subscriber PII
-- ============================================================================
-- ADMIN/ACCOUNTADMIN see clear values; everyone else (e.g. ANALYST) sees masked.
--   snow sql -f scripts/deploy/04_governance.sql --connection lemondetrial
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARCTIC_TIMES;
USE SCHEMA GOVERNANCE;
USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE MASKING POLICY ARCTIC_TIMES.GOVERNANCE.MASK_EMAIL
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN CURRENT_ROLE() IN ('ARCTIC_TIMES_ADMIN','ACCOUNTADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '.+@', '****@')
  END
  COMMENT = 'Masks email addresses for non-admin roles';

CREATE OR REPLACE MASKING POLICY ARCTIC_TIMES.GOVERNANCE.MASK_NAME
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN CURRENT_ROLE() IN ('ARCTIC_TIMES_ADMIN','ACCOUNTADMIN') THEN val
    ELSE '*** MASKED ***'
  END
  COMMENT = 'Masks full names for non-admin roles';

CREATE OR REPLACE MASKING POLICY ARCTIC_TIMES.GOVERNANCE.MASK_PHONE
  AS (val VARCHAR) RETURNS VARCHAR ->
  CASE
    WHEN CURRENT_ROLE() IN ('ARCTIC_TIMES_ADMIN','ACCOUNTADMIN') THEN val
    ELSE CONCAT('+33 **** ** ', RIGHT(val, 2))
  END
  COMMENT = 'Masks phone numbers — shows only last 2 digits';

-- Apply to subscriber PII columns
ALTER TABLE ARCTIC_TIMES.RAW.SUBSCRIBERS
  MODIFY COLUMN email     SET MASKING POLICY ARCTIC_TIMES.GOVERNANCE.MASK_EMAIL;
ALTER TABLE ARCTIC_TIMES.RAW.SUBSCRIBERS
  MODIFY COLUMN full_name SET MASKING POLICY ARCTIC_TIMES.GOVERNANCE.MASK_NAME;
ALTER TABLE ARCTIC_TIMES.RAW.SUBSCRIBERS
  MODIFY COLUMN phone     SET MASKING POLICY ARCTIC_TIMES.GOVERNANCE.MASK_PHONE;

SELECT 'Masking policies created and applied to SUBSCRIBERS' AS status;
