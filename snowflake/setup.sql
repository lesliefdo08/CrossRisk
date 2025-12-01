-- ============================================================================
-- CrossRisk Platform - Initial Setup
-- ============================================================================
-- This script initializes the core database and schema structure for the
-- CrossRisk privacy-safe multi-organization analytics platform.
-- ============================================================================

-- Create the main database
CREATE DATABASE IF NOT EXISTS CROSSRISK_DB
    COMMENT = 'CrossRisk: Privacy-safe cross-organization risk analytics platform';

-- Use the database
USE DATABASE CROSSRISK_DB;

-- Create schemas for different functional areas
CREATE SCHEMA IF NOT EXISTS RAW_DATA
    COMMENT = 'Raw data from partner organizations (masked at source)';

CREATE SCHEMA IF NOT EXISTS CLEAN_ROOM
    COMMENT = 'Secure Data Clean Room for cross-organization analytics';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Derived analytics, risk scores, and aggregated insights';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE
    COMMENT = 'Audit logs, access policies, and compliance tracking';

CREATE SCHEMA IF NOT EXISTS AI_INSIGHTS
    COMMENT = 'AI-generated summaries and explanations using Snowflake Cortex';

-- Create warehouses for different workloads
CREATE WAREHOUSE IF NOT EXISTS CROSSRISK_ETL_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for ETL and data processing tasks';

CREATE WAREHOUSE IF NOT EXISTS CROSSRISK_ANALYTICS_WH
    WITH WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for analytics queries and Streamlit app';

CREATE WAREHOUSE IF NOT EXISTS CROSSRISK_AI_WH
    WITH WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for AI/ML operations using Cortex';

-- Set context
USE SCHEMA RAW_DATA;
USE WAREHOUSE CROSSRISK_ETL_WH;

-- Create file format for CSV imports
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE
    COMPRESSION = 'AUTO'
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';

-- Create stage for data loading
CREATE OR REPLACE STAGE CROSSRISK_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Staging area for loading partner data files';

-- Grant initial permissions (modify based on your role structure)
GRANT USAGE ON DATABASE CROSSRISK_DB TO ROLE SYSADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CROSSRISK_DB TO ROLE SYSADMIN;
GRANT ALL ON SCHEMA RAW_DATA TO ROLE SYSADMIN;
GRANT ALL ON SCHEMA CLEAN_ROOM TO ROLE SYSADMIN;
GRANT ALL ON SCHEMA ANALYTICS TO ROLE SYSADMIN;
GRANT ALL ON SCHEMA GOVERNANCE TO ROLE SYSADMIN;
GRANT ALL ON SCHEMA AI_INSIGHTS TO ROLE SYSADMIN;

-- Create notification integration (optional, for monitoring)
-- Note: This requires account admin privileges
-- CREATE NOTIFICATION INTEGRATION IF NOT EXISTS crossrisk_alerts
--     TYPE = EMAIL
--     ENABLED = TRUE;

SELECT 'CrossRisk database setup completed successfully!' AS status;
