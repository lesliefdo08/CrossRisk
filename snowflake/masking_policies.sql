-- ============================================================================
-- CrossRisk Platform - Data Masking & Privacy Policies
-- ============================================================================
-- Implements Snowflake Horizon governance features including dynamic data
-- masking, row access policies, and conditional masking rules based on roles.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- MASKING POLICIES
-- ============================================================================

-- Mask customer identifiers for non-privileged users
CREATE OR REPLACE MASKING POLICY mask_customer_id AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN', 'PRIVACY_OFFICER') 
            THEN val
        ELSE '***MASKED***'
    END;

-- Mask detailed financial bands to broader categories
CREATE OR REPLACE MASKING POLICY mask_financial_details AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN', 'ANALYST_SENIOR') 
            THEN val
        WHEN val IN ('5k-10k', '10k-50k') THEN 'LOW'
        WHEN val IN ('50k-100k', '100k-250k') THEN 'MEDIUM'
        WHEN val IN ('250k-500k', '500k-1M', '1M+') THEN 'HIGH'
        ELSE 'UNKNOWN'
    END;

-- Mask exact risk scores to bands for lower privilege roles
CREATE OR REPLACE MASKING POLICY mask_risk_score AS (val FLOAT) RETURNS FLOAT ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN', 'ANALYST_SENIOR') 
            THEN val
        WHEN CURRENT_ROLE() IN ('ANALYST_JUNIOR', 'VIEWER') 
            THEN FLOOR(val / 10) * 10  -- Round to nearest 10
        ELSE NULL
    END;

-- Mask policy IDs
CREATE OR REPLACE MASKING POLICY mask_policy_id AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN', 'PRIVACY_OFFICER') 
            THEN val
        ELSE '***MASKED***'
    END;

-- ============================================================================
-- APPLY MASKING POLICIES TO TABLES
-- ============================================================================

-- Apply to bank data
ALTER TABLE RAW_DATA.bank_customer_risk_summary 
    MODIFY COLUMN customer_id 
    SET MASKING POLICY GOVERNANCE.mask_customer_id;

ALTER TABLE RAW_DATA.bank_customer_risk_summary 
    MODIFY COLUMN total_balance_band 
    SET MASKING POLICY GOVERNANCE.mask_financial_details;

ALTER TABLE RAW_DATA.bank_customer_risk_summary 
    MODIFY COLUMN risk_score 
    SET MASKING POLICY GOVERNANCE.mask_risk_score;

-- Apply to insurance data
ALTER TABLE RAW_DATA.insurance_claim_risk_summary 
    MODIFY COLUMN customer_id 
    SET MASKING POLICY GOVERNANCE.mask_customer_id;

ALTER TABLE RAW_DATA.insurance_claim_risk_summary 
    MODIFY COLUMN policy_id 
    SET MASKING POLICY GOVERNANCE.mask_policy_id;

ALTER TABLE RAW_DATA.insurance_claim_risk_summary 
    MODIFY COLUMN coverage_amount_band 
    SET MASKING POLICY GOVERNANCE.mask_financial_details;

ALTER TABLE RAW_DATA.insurance_claim_risk_summary 
    MODIFY COLUMN risk_score 
    SET MASKING POLICY GOVERNANCE.mask_risk_score;

-- ============================================================================
-- ROW ACCESS POLICIES
-- ============================================================================

-- Restrict access to high-risk records based on role
CREATE OR REPLACE ROW ACCESS POLICY high_risk_access AS (risk_score FLOAT) RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN', 'RISK_MANAGER') 
            THEN TRUE
        WHEN CURRENT_ROLE() IN ('ANALYST_SENIOR') AND risk_score < 80 
            THEN TRUE
        WHEN CURRENT_ROLE() IN ('ANALYST_JUNIOR', 'VIEWER') AND risk_score < 50 
            THEN TRUE
        ELSE FALSE
    END;

-- Apply row access policy to bank data
ALTER TABLE RAW_DATA.bank_customer_risk_summary 
    ADD ROW ACCESS POLICY GOVERNANCE.high_risk_access ON (risk_score);

-- Apply row access policy to insurance data
ALTER TABLE RAW_DATA.insurance_claim_risk_summary 
    ADD ROW ACCESS POLICY GOVERNANCE.high_risk_access ON (risk_score);

-- ============================================================================
-- PROJECTION POLICIES (Restrict columns returned)
-- ============================================================================

-- Create projection policy to prevent raw data export
CREATE OR REPLACE PROJECTION POLICY restrict_raw_export AS () RETURNS PROJECTION_CONSTRAINT ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN') 
            THEN PROJECTION_CONSTRAINT(ALLOWED => TRUE)
        WHEN IS_GRANTED_TO_INVOKER_ROLE('RAW_DATA_VIEWER')
            THEN PROJECTION_CONSTRAINT(ALLOWED => FALSE)
        ELSE PROJECTION_CONSTRAINT(ALLOWED => TRUE)
    END;

-- ============================================================================
-- AGGREGATION POLICIES (Enforce k-anonymity)
-- ============================================================================

-- Create a policy to enforce minimum group size in aggregations
CREATE OR REPLACE AGGREGATION POLICY enforce_k_anonymity AS () RETURNS AGGREGATION_CONSTRAINT ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROSSRISK_ADMIN') 
            THEN AGGREGATION_CONSTRAINT(MIN_GROUP_SIZE => 1)
        ELSE AGGREGATION_CONSTRAINT(MIN_GROUP_SIZE => 3)  -- k=3 anonymity
    END;

-- Apply aggregation policy to analytics tables
ALTER TABLE ANALYTICS.risk_join_aggregated 
    SET AGGREGATION POLICY GOVERNANCE.enforce_k_anonymity;

-- ============================================================================
-- OBJECT TAGGING FOR COMPLIANCE
-- ============================================================================

-- Create semantic tags for data classification
CREATE TAG IF NOT EXISTS data_classification 
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED';

CREATE TAG IF NOT EXISTS pii_category 
    ALLOWED_VALUES 'NONE', 'INDIRECT', 'DIRECT', 'SENSITIVE';

CREATE TAG IF NOT EXISTS retention_period 
    ALLOWED_VALUES '30_DAYS', '90_DAYS', '1_YEAR', '3_YEARS', '7_YEARS', 'INDEFINITE';

-- Tag raw data tables
ALTER TABLE RAW_DATA.bank_customer_risk_summary 
    SET TAG data_classification = 'CONFIDENTIAL', 
        pii_category = 'INDIRECT',
        retention_period = '7_YEARS';

ALTER TABLE RAW_DATA.insurance_claim_risk_summary 
    SET TAG data_classification = 'CONFIDENTIAL', 
        pii_category = 'INDIRECT',
        retention_period = '7_YEARS';

-- Tag analytics tables
ALTER TABLE ANALYTICS.risk_join_aggregated 
    SET TAG data_classification = 'INTERNAL', 
        pii_category = 'NONE',
        retention_period = '1_YEAR';

-- Tag governance tables
ALTER TABLE GOVERNANCE.access_audit_log 
    SET TAG data_classification = 'INTERNAL', 
        pii_category = 'INDIRECT',
        retention_period = '3_YEARS';

-- ============================================================================
-- CREATE SECURE VIEWS FOR CLEAN ROOM ACCESS
-- ============================================================================

-- Secure view for aggregated bank data only
CREATE OR REPLACE SECURE VIEW CLEAN_ROOM.bank_aggregated_view AS
SELECT 
    age_group,
    region,
    occupation_category,
    COUNT(*) AS customer_count,
    AVG(risk_score) AS avg_risk_score,
    STDDEV(risk_score) AS risk_stddev
FROM RAW_DATA.bank_customer_risk_summary
GROUP BY age_group, region, occupation_category
HAVING COUNT(*) >= 3;  -- k-anonymity enforcement

-- Secure view for aggregated insurance data only
CREATE OR REPLACE SECURE VIEW CLEAN_ROOM.insurance_aggregated_view AS
SELECT 
    age_group,
    region,
    occupation_category,
    policy_type,
    COUNT(*) AS policy_count,
    AVG(risk_score) AS avg_risk_score,
    SUM(claim_count_12m) AS total_claims
FROM RAW_DATA.insurance_claim_risk_summary
GROUP BY age_group, region, occupation_category, policy_type
HAVING COUNT(*) >= 3;  -- k-anonymity enforcement

-- Combined secure view for cross-organization insights
CREATE OR REPLACE SECURE VIEW CLEAN_ROOM.cross_org_insights AS
SELECT 
    b.age_group,
    b.region,
    b.occupation_category,
    COUNT(DISTINCT b.customer_id) AS unique_customers,
    AVG(b.risk_score) AS avg_bank_risk,
    AVG(i.risk_score) AS avg_insurance_risk,
    (AVG(b.risk_score) * 0.6 + AVG(i.risk_score) * 0.4) AS composite_risk,
    SUM(i.claim_count_12m) AS total_claims,
    SUM(b.fraud_flag_history) AS total_fraud_flags
FROM RAW_DATA.bank_customer_risk_summary b
JOIN RAW_DATA.insurance_claim_risk_summary i
    ON b.customer_id = i.customer_id
    AND b.age_group = i.age_group
    AND b.region = i.region
GROUP BY b.age_group, b.region, b.occupation_category
HAVING COUNT(DISTINCT b.customer_id) >= 3;  -- k-anonymity enforcement

-- Grant access to clean room views
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEAN_ROOM TO ROLE ANALYST_JUNIOR;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEAN_ROOM TO ROLE ANALYST_SENIOR;

SELECT 'Masking policies and governance controls applied successfully!' AS status;
