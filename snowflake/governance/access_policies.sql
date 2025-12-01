-- ============================================================================
-- CrossRisk Platform - Access Policies
-- ============================================================================
-- Defines role-based access control policies for secure data sharing.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- CREATE ROLES
-- ============================================================================

-- Administrative roles
CREATE ROLE IF NOT EXISTS CROSSRISK_ADMIN 
    COMMENT = 'Full administrative access to CrossRisk platform';

CREATE ROLE IF NOT EXISTS PRIVACY_OFFICER 
    COMMENT = 'Privacy and compliance oversight role';

-- Analyst roles
CREATE ROLE IF NOT EXISTS ANALYST_SENIOR 
    COMMENT = 'Senior analysts with broader data access';

CREATE ROLE IF NOT EXISTS ANALYST_JUNIOR 
    COMMENT = 'Junior analysts with restricted access to aggregated data only';

-- Data provider roles
CREATE ROLE IF NOT EXISTS BANK_DATA_PROVIDER 
    COMMENT = 'Bank organization data provider role';

CREATE ROLE IF NOT EXISTS INSURANCE_DATA_PROVIDER 
    COMMENT = 'Insurance organization data provider role';

-- Application roles
CREATE ROLE IF NOT EXISTS STREAMLIT_APP_ROLE 
    COMMENT = 'Role for Streamlit application queries';

CREATE ROLE IF NOT EXISTS VIEWER 
    COMMENT = 'Read-only viewer for dashboard access';

-- ============================================================================
-- GRANT DATABASE AND WAREHOUSE ACCESS
-- ============================================================================

-- Admin role gets full access
GRANT ALL ON DATABASE CROSSRISK_DB TO ROLE CROSSRISK_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE CROSSRISK_DB TO ROLE CROSSRISK_ADMIN;
GRANT ALL ON ALL TABLES IN DATABASE CROSSRISK_DB TO ROLE CROSSRISK_ADMIN;
GRANT ALL ON ALL VIEWS IN DATABASE CROSSRISK_DB TO ROLE CROSSRISK_ADMIN;
GRANT USAGE ON ALL WAREHOUSES IN ACCOUNT TO ROLE CROSSRISK_ADMIN;

-- Privacy officer access
GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE PRIVACY_OFFICER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CROSSRISK_DB TO ROLE PRIVACY_OFFICER;
GRANT SELECT ON ALL TABLES IN SCHEMA GOVERNANCE TO ROLE PRIVACY_OFFICER;
GRANT SELECT ON ALL TABLES IN SCHEMA RAW_DATA TO ROLE PRIVACY_OFFICER;
GRANT USAGE ON WAREHOUSE CROSSRISK_ANALYTICS_WH TO ROLE PRIVACY_OFFICER;

-- ============================================================================
-- ANALYST ROLE PERMISSIONS
-- ============================================================================

-- Senior analyst access
GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE ANALYST_SENIOR;
GRANT USAGE ON SCHEMA ANALYTICS TO ROLE ANALYST_SENIOR;
GRANT USAGE ON SCHEMA CLEAN_ROOM TO ROLE ANALYST_SENIOR;
GRANT USAGE ON SCHEMA AI_INSIGHTS TO ROLE ANALYST_SENIOR;
GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS TO ROLE ANALYST_SENIOR;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEAN_ROOM TO ROLE ANALYST_SENIOR;
GRANT SELECT ON ALL TABLES IN SCHEMA AI_INSIGHTS TO ROLE ANALYST_SENIOR;
GRANT USAGE ON WAREHOUSE CROSSRISK_ANALYTICS_WH TO ROLE ANALYST_SENIOR;

-- Junior analyst access (aggregated data only)
GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE ANALYST_JUNIOR;
GRANT USAGE ON SCHEMA CLEAN_ROOM TO ROLE ANALYST_JUNIOR;
GRANT USAGE ON SCHEMA AI_INSIGHTS TO ROLE ANALYST_JUNIOR;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEAN_ROOM TO ROLE ANALYST_JUNIOR;
GRANT SELECT ON TABLE AI_INSIGHTS.approved_questions_cache TO ROLE ANALYST_JUNIOR;
GRANT USAGE ON WAREHOUSE CROSSRISK_ANALYTICS_WH TO ROLE ANALYST_JUNIOR;

-- ============================================================================
-- DATA PROVIDER PERMISSIONS
-- ============================================================================

-- Bank data provider (can only insert into their table)
GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE BANK_DATA_PROVIDER;
GRANT USAGE ON SCHEMA RAW_DATA TO ROLE BANK_DATA_PROVIDER;
GRANT INSERT ON TABLE RAW_DATA.bank_customer_risk_summary TO ROLE BANK_DATA_PROVIDER;
GRANT UPDATE ON TABLE RAW_DATA.bank_customer_risk_summary TO ROLE BANK_DATA_PROVIDER;
GRANT SELECT ON TABLE RAW_DATA.bank_customer_risk_summary TO ROLE BANK_DATA_PROVIDER;
GRANT USAGE ON WAREHOUSE CROSSRISK_ETL_WH TO ROLE BANK_DATA_PROVIDER;

-- Insurance data provider
GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE INSURANCE_DATA_PROVIDER;
GRANT USAGE ON SCHEMA RAW_DATA TO ROLE INSURANCE_DATA_PROVIDER;
GRANT INSERT ON TABLE RAW_DATA.insurance_claim_risk_summary TO ROLE INSURANCE_DATA_PROVIDER;
GRANT UPDATE ON TABLE RAW_DATA.insurance_claim_risk_summary TO ROLE INSURANCE_DATA_PROVIDER;
GRANT SELECT ON TABLE RAW_DATA.insurance_claim_risk_summary TO ROLE INSURANCE_DATA_PROVIDER;
GRANT USAGE ON WAREHOUSE CROSSRISK_ETL_WH TO ROLE INSURANCE_DATA_PROVIDER;

-- ============================================================================
-- STREAMLIT APP PERMISSIONS
-- ============================================================================

GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON SCHEMA ANALYTICS TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON SCHEMA CLEAN_ROOM TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON SCHEMA AI_INSIGHTS TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON SCHEMA GOVERNANCE TO ROLE STREAMLIT_APP_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS TO ROLE STREAMLIT_APP_ROLE;
GRANT SELECT ON ALL VIEWS IN SCHEMA CLEAN_ROOM TO ROLE STREAMLIT_APP_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA AI_INSIGHTS TO ROLE STREAMLIT_APP_ROLE;
GRANT SELECT ON TABLE GOVERNANCE.access_audit_log TO ROLE STREAMLIT_APP_ROLE;
GRANT SELECT ON TABLE GOVERNANCE.privacy_compliance_log TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON WAREHOUSE CROSSRISK_ANALYTICS_WH TO ROLE STREAMLIT_APP_ROLE;

-- Allow Streamlit app to call stored procedures
GRANT USAGE ON ALL PROCEDURES IN SCHEMA ANALYTICS TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA ANALYTICS TO ROLE STREAMLIT_APP_ROLE;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA AI_INSIGHTS TO ROLE STREAMLIT_APP_ROLE;

-- ============================================================================
-- VIEWER PERMISSIONS
-- ============================================================================

GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE VIEWER;
GRANT USAGE ON SCHEMA AI_INSIGHTS TO ROLE VIEWER;
GRANT SELECT ON TABLE AI_INSIGHTS.approved_questions_cache TO ROLE VIEWER;
GRANT SELECT ON TABLE AI_INSIGHTS.ai_explanations TO ROLE VIEWER;
GRANT USAGE ON WAREHOUSE CROSSRISK_ANALYTICS_WH TO ROLE VIEWER;

-- ============================================================================
-- FUTURE GRANTS (automatically apply to new objects)
-- ============================================================================

-- Analytics schema
GRANT SELECT ON FUTURE TABLES IN SCHEMA ANALYTICS TO ROLE ANALYST_SENIOR;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA ANALYTICS TO ROLE ANALYST_SENIOR;
GRANT SELECT ON FUTURE TABLES IN SCHEMA ANALYTICS TO ROLE STREAMLIT_APP_ROLE;

-- Clean room schema
GRANT SELECT ON FUTURE VIEWS IN SCHEMA CLEAN_ROOM TO ROLE ANALYST_SENIOR;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA CLEAN_ROOM TO ROLE ANALYST_JUNIOR;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA CLEAN_ROOM TO ROLE STREAMLIT_APP_ROLE;

-- AI insights schema
GRANT SELECT ON FUTURE TABLES IN SCHEMA AI_INSIGHTS TO ROLE ANALYST_SENIOR;
GRANT SELECT ON FUTURE TABLES IN SCHEMA AI_INSIGHTS TO ROLE STREAMLIT_APP_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA AI_INSIGHTS TO ROLE VIEWER;

-- ============================================================================
-- ROLE HIERARCHY
-- ============================================================================

-- Grant junior role to senior role
GRANT ROLE ANALYST_JUNIOR TO ROLE ANALYST_SENIOR;

-- Grant analyst roles to admin
GRANT ROLE ANALYST_SENIOR TO ROLE CROSSRISK_ADMIN;
GRANT ROLE ANALYST_JUNIOR TO ROLE CROSSRISK_ADMIN;

-- Grant viewer to all analyst roles
GRANT ROLE VIEWER TO ROLE ANALYST_JUNIOR;

-- Grant app role to admin
GRANT ROLE STREAMLIT_APP_ROLE TO ROLE CROSSRISK_ADMIN;

-- ============================================================================
-- NETWORK POLICIES (Optional - uncomment if needed)
-- ============================================================================

-- Create network policy to restrict access by IP
-- CREATE NETWORK POLICY crossrisk_network_policy
--     ALLOWED_IP_LIST = ('192.168.1.0/24', '10.0.0.0/8')
--     BLOCKED_IP_LIST = ()
--     COMMENT = 'Restrict CrossRisk access to approved networks';

-- Apply to specific roles
-- ALTER USER your_username SET NETWORK_POLICY = crossrisk_network_policy;

-- ============================================================================
-- SESSION POLICIES
-- ============================================================================

-- Session timeout for inactive sessions
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE = FALSE;
ALTER ACCOUNT SET CLIENT_SESSION_KEEP_ALIVE_HEARTBEAT_FREQUENCY = 900; -- 15 minutes

SELECT 'Access policies and roles created successfully!' AS status;
