/*******************************************************************************
 * File: governance/tags.sql
 * Purpose: Creates and applies semantic tags for data classification,
 *          compliance tracking, and governance metadata management.
 * 
 * Schema/Objects:
 * - Tags: sensitivity_level, regulatory_requirement, retention_policy,
 *   business_criticality, data_owner, update_frequency
 * - Applied to: CROSSRISK_DB, all schemas, and critical tables
 * 
 * Dependencies:
 * - Requires setup.sql and schemas.sql to be executed first
 * - Requires TAG ADMIN privileges
 *
 * Privacy/Security:
 * - Enables automated policy enforcement based on tag values
 * - Supports compliance reporting and audit requirements
 * - Tags identify GDPR, CCPA, and other regulatory data
 *  
 * Usage:
 * snowsql -f snowflake/governance/tags.sql
 *
 * Author: Leslie Fernando
 * Created: 2024 (Snowflake Hackathon)
 ******************************************************************************/

-- ============================================================================
-- CrossRisk Platform - Governance Tags
-- ============================================================================
-- Defines semantic tags for data classification and compliance tracking.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- CREATE GOVERNANCE TAGS
-- ============================================================================

-- Data sensitivity classification tag
-- Drives access control and masking policy decisions
CREATE TAG IF NOT EXISTS sensitivity_level 
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'HIGHLY_CONFIDENTIAL'
    COMMENT = 'Data sensitivity classification for access control';

-- Regulatory compliance tags
CREATE TAG IF NOT EXISTS regulatory_requirement 
    COMMENT = 'Applicable regulatory requirements (GDPR, CCPA, SOX, etc.)';

-- Data retention requirements
CREATE TAG IF NOT EXISTS retention_policy 
    ALLOWED_VALUES '30_DAYS', '90_DAYS', '180_DAYS', '1_YEAR', '3_YEARS', '7_YEARS', 'INDEFINITE'
    COMMENT = 'Required data retention period';

-- Business criticality
CREATE TAG IF NOT EXISTS business_criticality 
    ALLOWED_VALUES 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
    COMMENT = 'Business impact level of the data';

-- Data ownership
CREATE TAG IF NOT EXISTS data_owner 
    COMMENT = 'Team or individual responsible for data governance';

-- Update frequency
CREATE TAG IF NOT EXISTS update_frequency 
    ALLOWED_VALUES 'REAL_TIME', 'HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'ON_DEMAND'
    COMMENT = 'How frequently data is updated';

-- ============================================================================
-- APPLY TAGS TO DATABASES AND SCHEMAS
-- ============================================================================

-- Tag the main database
ALTER DATABASE CROSSRISK_DB SET TAG 
    sensitivity_level = 'CONFIDENTIAL',
    business_criticality = 'HIGH',
    data_owner = 'Risk Analytics Team';

-- Tag RAW_DATA schema
ALTER SCHEMA RAW_DATA SET TAG 
    sensitivity_level = 'HIGHLY_CONFIDENTIAL',
    regulatory_requirement = 'GDPR,CCPA,Financial Privacy',
    retention_policy = '7_YEARS',
    business_criticality = 'CRITICAL',
    update_frequency = 'DAILY';

-- Tag ANALYTICS schema
ALTER SCHEMA ANALYTICS SET TAG 
    sensitivity_level = 'CONFIDENTIAL',
    retention_policy = '3_YEARS',
    business_criticality = 'HIGH',
    update_frequency = 'HOURLY';

-- Tag GOVERNANCE schema
ALTER SCHEMA GOVERNANCE SET TAG 
    sensitivity_level = 'HIGHLY_CONFIDENTIAL',
    regulatory_requirement = 'SOX,Audit Requirements',
    retention_policy = '7_YEARS',
    business_criticality = 'CRITICAL',
    update_frequency = 'REAL_TIME';

-- ============================================================================
-- TAG SPECIFIC TABLES
-- ============================================================================

-- Tag bank data
ALTER TABLE RAW_DATA.bank_customer_risk_summary SET TAG 
    sensitivity_level = 'HIGHLY_CONFIDENTIAL',
    regulatory_requirement = 'GDPR,CCPA,Bank Secrecy Act',
    data_owner = 'Bank Alpha',
    update_frequency = 'DAILY';

-- Tag insurance data
ALTER TABLE RAW_DATA.insurance_claim_risk_summary SET TAG 
    sensitivity_level = 'HIGHLY_CONFIDENTIAL',
    regulatory_requirement = 'HIPAA,GDPR,CCPA',
    data_owner = 'Insurance Beta',
    update_frequency = 'DAILY';

-- Tag analytics tables
ALTER TABLE ANALYTICS.risk_join_aggregated SET TAG 
    sensitivity_level = 'CONFIDENTIAL',
    business_criticality = 'HIGH',
    data_owner = 'CrossRisk Platform',
    update_frequency = 'HOURLY';

ALTER TABLE ANALYTICS.fraud_cross_signals SET TAG 
    sensitivity_level = 'HIGHLY_CONFIDENTIAL',
    business_criticality = 'CRITICAL',
    data_owner = 'Fraud Detection Team',
    update_frequency = 'REAL_TIME';

-- Tag audit logs
ALTER TABLE GOVERNANCE.access_audit_log SET TAG 
    sensitivity_level = 'HIGHLY_CONFIDENTIAL',
    regulatory_requirement = 'SOX,GDPR Article 30',
    retention_policy = '7_YEARS',
    business_criticality = 'CRITICAL',
    update_frequency = 'REAL_TIME';

SELECT 'Governance tags created and applied successfully!' AS status;
