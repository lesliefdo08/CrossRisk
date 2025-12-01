-- ============================================================================
-- CrossRisk Platform - Stream Creation
-- ============================================================================
-- Creates Snowflake streams to track changes in source tables for
-- real-time analytics updates.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE WAREHOUSE CROSSRISK_ETL_WH;

-- ============================================================================
-- STREAMS ON RAW DATA TABLES
-- ============================================================================

-- Stream to track changes in bank data
CREATE OR REPLACE STREAM bank_data_changes
    ON TABLE RAW_DATA.bank_customer_risk_summary
    COMMENT = 'Tracks inserts, updates, and deletes in bank customer data';

-- Stream to track changes in insurance data
CREATE OR REPLACE STREAM insurance_data_changes
    ON TABLE RAW_DATA.insurance_claim_risk_summary
    COMMENT = 'Tracks inserts, updates, and deletes in insurance claim data';

-- ============================================================================
-- STREAMS ON ANALYTICS TABLES
-- ============================================================================

-- Stream to track new risk aggregations
CREATE OR REPLACE STREAM risk_aggregation_changes
    ON TABLE ANALYTICS.risk_join_aggregated
    COMMENT = 'Tracks changes in aggregated risk calculations';

-- Stream to track fraud signal detections
CREATE OR REPLACE STREAM fraud_signal_changes
    ON TABLE ANALYTICS.fraud_cross_signals
    COMMENT = 'Tracks newly detected fraud patterns';

-- ============================================================================
-- MONITORING STREAMS
-- ============================================================================

-- Stream to monitor audit log for suspicious activity
CREATE OR REPLACE STREAM audit_log_stream
    ON TABLE GOVERNANCE.access_audit_log
    COMMENT = 'Monitors access patterns for compliance review';

-- Stream to track compliance violations
CREATE OR REPLACE STREAM compliance_log_stream
    ON TABLE GOVERNANCE.privacy_compliance_log
    COMMENT = 'Tracks compliance check results for alerting';

-- ============================================================================
-- UTILITY PROCEDURE TO CHECK STREAM STATUS
-- ============================================================================

CREATE OR REPLACE PROCEDURE check_stream_status()
RETURNS TABLE (
    stream_name VARCHAR,
    table_name VARCHAR,
    rows_pending INT,
    last_updated TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        SELECT 
            'bank_data_changes' AS stream_name,
            'bank_customer_risk_summary' AS table_name,
            (SELECT COUNT(*) FROM bank_data_changes) AS rows_pending,
            CURRENT_TIMESTAMP() AS last_updated
        UNION ALL
        SELECT 
            'insurance_data_changes',
            'insurance_claim_risk_summary',
            (SELECT COUNT(*) FROM insurance_data_changes),
            CURRENT_TIMESTAMP()
        UNION ALL
        SELECT 
            'risk_aggregation_changes',
            'risk_join_aggregated',
            (SELECT COUNT(*) FROM risk_aggregation_changes),
            CURRENT_TIMESTAMP()
        UNION ALL
        SELECT 
            'fraud_signal_changes',
            'fraud_cross_signals',
            (SELECT COUNT(*) FROM fraud_signal_changes),
            CURRENT_TIMESTAMP()
        UNION ALL
        SELECT 
            'audit_log_stream',
            'access_audit_log',
            (SELECT COUNT(*) FROM audit_log_stream),
            CURRENT_TIMESTAMP()
        UNION ALL
        SELECT 
            'compliance_log_stream',
            'privacy_compliance_log',
            (SELECT COUNT(*) FROM compliance_log_stream),
            CURRENT_TIMESTAMP()
    );
    RETURN TABLE(res);
END;
$$;

SELECT 'Streams created successfully!' AS status;
