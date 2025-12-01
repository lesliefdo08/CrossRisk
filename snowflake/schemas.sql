/*******************************************************************************
 * File: schemas.sql
 * Purpose: Defines all table schemas for raw data, analytics, governance,
 *          and AI insights including privacy-safe data structures.
 * 
 * Schema/Objects:
 * - RAW_DATA tables: bank_customer_risk_summary, insurance_claim_risk_summary
 * - ANALYTICS tables: risk_join_aggregated, risk_category_definitions,
 *   regional_risk_trends, fraud_cross_signals
 * - GOVERNANCE tables: access_audit_log, data_access_requests,
 *   privacy_compliance_log
 * - AI_INSIGHTS tables: ai_explanations, approved_questions_cache
 * 
 * Dependencies:
 * - Requires setup.sql to be executed first
 * - CROSSRISK_DB database must exist
 *
 * Privacy/Security:
 * - All tables use masked/generalized fields (age_group, region bands)
 * - Enforces k-anonymity with record_count >= 3 constraints
 * - No direct PII storage (customer_id is pre-hashed)
 *  
 * Usage:
 * snowsql -f snowflake/schemas.sql
 *
 * Author: Leslie Fernando
 * Created: 2024 (Snowflake Hackathon)
 ******************************************************************************/

-- ============================================================================
-- CrossRisk Platform - Schema Definitions
-- ============================================================================
-- Defines all table schemas for the CrossRisk platform including raw data
-- tables, analytics tables, and audit tables.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE WAREHOUSE CROSSRISK_ETL_WH;

-- ============================================================================
-- RAW DATA SCHEMA - Source organization data (pre-masked)
-- ============================================================================

USE SCHEMA RAW_DATA;

-- Bank customer risk summary table
-- Contains pre-masked banking data with generalized fields for privacy
CREATE OR REPLACE TABLE bank_customer_risk_summary (
    customer_id VARCHAR(50) NOT NULL,           -- Hashed customer identifier
    age_group VARCHAR(20) NOT NULL,             -- Age bracket (e.g., '25-34', '35-44')
    region VARCHAR(50) NOT NULL,                -- Geographic region
    occupation_category VARCHAR(50),            -- Occupation type (generalized)
    account_tenure_years INT,                   -- Years as customer
    product_count INT,                          -- Number of active products
    total_balance_band VARCHAR(20),             -- Balance range (e.g., '10k-50k')
    credit_score_band VARCHAR(20),              -- Credit score range
    transaction_velocity VARCHAR(20),           -- Transaction frequency category
    fraud_flag_history INT DEFAULT 0,           -- Historical fraud flags count
    risk_score FLOAT,                           -- Bank's internal risk score (0-100)
    last_updated TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    data_source VARCHAR(50) DEFAULT 'BANK_ALPHA',
    CONSTRAINT pk_bank PRIMARY KEY (customer_id)
);

-- Insurance claim risk summary table
-- Contains pre-masked insurance data with privacy-safe aggregations
CREATE OR REPLACE TABLE insurance_claim_risk_summary (
    policy_id VARCHAR(50) NOT NULL,             -- Hashed policy identifier
    customer_id VARCHAR(50) NOT NULL,           -- Hashed customer identifier (linkable)
    age_group VARCHAR(20) NOT NULL,             -- Age bracket
    region VARCHAR(50) NOT NULL,                -- Geographic region
    occupation_category VARCHAR(50),            -- Occupation type
    policy_type VARCHAR(50),                    -- Insurance product type
    coverage_amount_band VARCHAR(20),           -- Coverage range
    premium_band VARCHAR(20),                   -- Premium range
    claim_count_12m INT DEFAULT 0,              -- Claims in last 12 months
    claim_amount_band VARCHAR(20),              -- Total claim amount range
    claim_frequency_pattern VARCHAR(20),        -- Pattern indicator
    suspicious_claim_flags INT DEFAULT 0,       -- Red flag indicators
    risk_score FLOAT,                           -- Insurer's risk score (0-100)
    last_updated TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    data_source VARCHAR(50) DEFAULT 'INSURANCE_BETA',
    CONSTRAINT pk_insurance PRIMARY KEY (policy_id)
);

-- ============================================================================
-- ANALYTICS SCHEMA - Derived insights and risk calculations
-- ============================================================================

USE SCHEMA ANALYTICS;

-- Combined risk profile table
-- Aggregates cross-organizational risk data with k-anonymity enforcement
CREATE OR REPLACE TABLE risk_join_aggregated (
    analysis_id VARCHAR(50) NOT NULL,
    age_group VARCHAR(20) NOT NULL,
    region VARCHAR(50) NOT NULL,
    occupation_category VARCHAR(50),
    record_count INT,                           -- Must be >= 3 for privacy
    avg_bank_risk_score FLOAT,
    avg_insurance_risk_score FLOAT,
    composite_risk_score FLOAT,                 -- Weighted combination
    risk_category VARCHAR(20),                  -- LOW, MEDIUM, HIGH, CRITICAL
    fraud_correlation_score FLOAT,              -- Cross-signal correlation
    analysis_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_risk_join PRIMARY KEY (analysis_id),
    CONSTRAINT chk_min_records CHECK (record_count >= 3)  -- k-anonymity rule
);

-- Risk category mapping
CREATE OR REPLACE TABLE risk_category_definitions (
    category VARCHAR(20) PRIMARY KEY,
    min_score FLOAT NOT NULL,
    max_score FLOAT NOT NULL,
    description VARCHAR(500),
    recommended_action VARCHAR(500)
);

-- Regional risk trends
CREATE OR REPLACE TABLE regional_risk_trends (
    trend_id VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL,
    analysis_date DATE NOT NULL,
    customer_count INT,
    avg_composite_risk FLOAT,
    high_risk_percentage FLOAT,
    trend_direction VARCHAR(20),                -- INCREASING, STABLE, DECREASING
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_regional_trends PRIMARY KEY (trend_id)
);

-- Fraud signal cross-detection
CREATE OR REPLACE TABLE fraud_cross_signals (
    signal_id VARCHAR(50) NOT NULL,
    age_group VARCHAR(20),
    region VARCHAR(50),
    pattern_description VARCHAR(500),
    affected_customer_count INT,
    confidence_score FLOAT,                     -- 0-1 confidence level
    detected_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_fraud_signals PRIMARY KEY (signal_id),
    CONSTRAINT chk_min_customers CHECK (affected_customer_count >= 3)
);

-- ============================================================================
-- GOVERNANCE SCHEMA - Audit and compliance
-- ============================================================================

USE SCHEMA GOVERNANCE;

-- Access audit log
CREATE OR REPLACE TABLE access_audit_log (
    audit_id VARCHAR(50) NOT NULL,
    user_name VARCHAR(100),
    role_name VARCHAR(100),
    query_text VARCHAR(5000),
    query_type VARCHAR(50),                     -- SELECT, INSERT, UPDATE, etc.
    tables_accessed ARRAY,                      -- List of tables accessed
    row_count INT,
    execution_time_ms INT,
    session_id VARCHAR(100),
    client_ip VARCHAR(50),
    executed_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_audit PRIMARY KEY (audit_id)
);

-- Data access requests (for clean room queries)
CREATE OR REPLACE TABLE data_access_requests (
    request_id VARCHAR(50) NOT NULL,
    requesting_user VARCHAR(100),
    requesting_org VARCHAR(100),
    query_purpose VARCHAR(500),
    requested_data_elements ARRAY,
    approval_status VARCHAR(20),                -- PENDING, APPROVED, REJECTED
    approved_by VARCHAR(100),
    approved_at TIMESTAMP_NTZ,
    request_created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_access_requests PRIMARY KEY (request_id)
);

-- Privacy compliance log
CREATE OR REPLACE TABLE privacy_compliance_log (
    compliance_id VARCHAR(50) NOT NULL,
    check_type VARCHAR(50),                     -- K_ANONYMITY, MASKING, etc.
    table_name VARCHAR(200),
    check_result VARCHAR(20),                   -- PASSED, FAILED, WARNING
    details VARCHAR(1000),
    checked_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_compliance PRIMARY KEY (compliance_id)
);

-- ============================================================================
-- AI_INSIGHTS SCHEMA - Cortex-generated content
-- ============================================================================

USE SCHEMA AI_INSIGHTS;

-- AI-generated explanations
CREATE OR REPLACE TABLE ai_explanations (
    explanation_id VARCHAR(50) NOT NULL,
    context_type VARCHAR(50),                   -- ANOMALY, TREND, PATTERN, etc.
    reference_data VARIANT,                     -- JSON with source data summary
    ai_explanation TEXT,                        -- Natural language explanation
    confidence_score FLOAT,
    generated_model VARCHAR(50),                -- e.g., 'cortex-sql', 'cortex-complete'
    generated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_ai_explain PRIMARY KEY (explanation_id)
);

-- Pre-approved analytics questions cache
CREATE OR REPLACE TABLE approved_questions_cache (
    question_id VARCHAR(50) NOT NULL,
    question_text VARCHAR(500) NOT NULL,
    category VARCHAR(50),
    result_data VARIANT,                        -- Cached query results as JSON
    ai_summary TEXT,                            -- Plain English summary
    last_refreshed TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_questions PRIMARY KEY (question_id)
);

SELECT 'All schemas and tables created successfully!' AS status;
