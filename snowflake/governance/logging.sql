/*******************************************************************************
 * File: governance/logging.sql
 * Purpose: Configures comprehensive audit logging, access monitoring, and
 *          security analytics using Snowflake ACCOUNT_USAGE views.
 * 
 * Schema/Objects:
 * - Views: v_sensitive_data_access, v_access_anomalies,
 *   v_failed_access_attempts, v_masking_policy_references, v_user_sessions
 * - Procedures: generate_daily_access_report, check_suspicious_activity,
 *   export_audit_trail
 * - Summary views: v_monthly_compliance_summary, v_role_access_summary
 * 
 * Dependencies:
 * - Requires setup.sql, schemas.sql to be executed first
 * - Requires access to SNOWFLAKE.ACCOUNT_USAGE schema
 *
 * Privacy/Security:
 * - Tracks all access to sensitive data for compliance audits
 * - Detects anomalous access patterns (high volume, off-hours)
 * - Monitors failed authentication and authorization attempts
 * - Provides SOX, GDPR Article 30 compliance reporting
 *  
 * Usage:
 * snowsql -f snowflake/governance/logging.sql
 *
 * Author: Leslie Fernando
 * Created: 2024 (Snowflake Hackathon)
 ******************************************************************************/

-- ============================================================================
-- CrossRisk Platform - Audit Logging Configuration
-- ============================================================================
-- Sets up comprehensive audit logging for compliance and security monitoring.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- QUERY HISTORY LOGGING VIEW
-- ============================================================================

-- Create view to monitor all queries against sensitive tables
-- Captures query metadata from ACCOUNT_USAGE for compliance tracking
CREATE OR REPLACE SECURE VIEW v_sensitive_data_access AS
SELECT 
    query_id,
    query_text,
    user_name,
    role_name,
    session_id,
    warehouse_name,
    database_name,
    schema_name,
    execution_status,
    error_code,
    error_message,
    start_time,
    end_time,
    total_elapsed_time,
    bytes_scanned,
    rows_produced,
    compilation_time,
    execution_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE (database_name = 'CROSSRISK_DB' 
   AND schema_name IN ('RAW_DATA', 'ANALYTICS'))
   OR query_text ILIKE '%bank_customer_risk_summary%'
   OR query_text ILIKE '%insurance_claim_risk_summary%'
ORDER BY start_time DESC;

-- ============================================================================
-- ACCESS PATTERN ANALYSIS
-- ============================================================================

-- View to identify unusual access patterns
-- Detects high-frequency queries, large extractions, and off-hours access
CREATE OR REPLACE VIEW v_access_anomalies AS
SELECT 
    user_name,
    role_name,
    DATE_TRUNC('hour', start_time) AS access_hour,
    COUNT(*) AS query_count,
    SUM(rows_produced) AS total_rows_accessed,
    AVG(total_elapsed_time) AS avg_query_time_ms,
    CASE
        WHEN COUNT(*) > 100 THEN 'High frequency access'
        WHEN SUM(rows_produced) > 10000 THEN 'Large data extraction'
        WHEN HOUR(start_time) NOT BETWEEN 6 AND 22 THEN 'Off-hours access'
        ELSE 'Normal'
    END AS anomaly_flag
FROM v_sensitive_data_access
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY user_name, role_name, DATE_TRUNC('hour', start_time)
HAVING anomaly_flag != 'Normal'
ORDER BY access_hour DESC;

-- ============================================================================
-- FAILED ACCESS ATTEMPTS TRACKING
-- ============================================================================

CREATE OR REPLACE VIEW v_failed_access_attempts AS
SELECT 
    user_name,
    role_name,
    query_text,
    error_code,
    error_message,
    start_time,
    session_id,
    CASE
        WHEN error_code IN ('1063', '3001', '3003', '3005') THEN 'Permission denied'
        WHEN error_code IN ('2003', '2043') THEN 'Object not found'
        WHEN error_code IN ('90105') THEN 'Insufficient privileges'
        ELSE 'Other error'
    END AS error_category
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE database_name = 'CROSSRISK_DB'
  AND execution_status = 'FAIL'
  AND start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;

-- ============================================================================
-- DATA MASKING POLICY USAGE
-- ============================================================================

-- Track when masking policies are applied
CREATE OR REPLACE VIEW v_masking_policy_references AS
SELECT 
    policy_name,
    policy_kind,
    ref_entity_name,
    ref_entity_domain,
    ref_column_name,
    ref_arg_column_names,
    tag_name,
    tag_value
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE policy_db = 'CROSSRISK_DB'
  AND policy_kind = 'MASKING_POLICY'
ORDER BY policy_name, ref_entity_name;

-- ============================================================================
-- USER SESSION TRACKING
-- ============================================================================

CREATE OR REPLACE VIEW v_user_sessions AS
SELECT 
    session_id,
    user_name,
    role_name,
    created_on AS session_start,
    login_event_id,
    authentication_method,
    first_authentication_factor,
    second_authentication_factor,
    client_application_id,
    client_application_version,
    client_ip
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE user_name != 'SNOWFLAKE'
  AND created_on >= DATEADD(day, -30, CURRENT_TIMESTAMP())
ORDER BY created_on DESC;

-- ============================================================================
-- DATA SHARING AUDIT
-- ============================================================================

-- Monitor any data sharing activities
CREATE OR REPLACE VIEW v_data_sharing_audit AS
SELECT 
    share_name,
    kind AS share_kind,
    database_name,
    owner,
    comment,
    created,
    granted_to,
    granted_on
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE granted_on IN ('DATABASE', 'SCHEMA', 'TABLE', 'VIEW')
  AND grantee_name LIKE '%SHARE%'
ORDER BY created DESC;

-- ============================================================================
-- STORED PROCEDURES FOR AUDIT LOGGING
-- ============================================================================

-- Procedure to generate daily access report
CREATE OR REPLACE PROCEDURE generate_daily_access_report(report_date DATE)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    total_queries INT;
    unique_users INT;
    sensitive_accesses INT;
    failed_attempts INT;
BEGIN
    -- Count metrics
    SELECT COUNT(*) INTO :total_queries
    FROM v_sensitive_data_access
    WHERE DATE(start_time) = report_date;
    
    SELECT COUNT(DISTINCT user_name) INTO :unique_users
    FROM v_sensitive_data_access
    WHERE DATE(start_time) = report_date;
    
    SELECT COUNT(*) INTO :sensitive_accesses
    FROM v_sensitive_data_access
    WHERE DATE(start_time) = report_date
      AND schema_name = 'RAW_DATA';
    
    SELECT COUNT(*) INTO :failed_attempts
    FROM v_failed_access_attempts
    WHERE DATE(start_time) = report_date;
    
    -- Log report summary
    INSERT INTO privacy_compliance_log (
        compliance_id,
        check_type,
        table_name,
        check_result,
        details,
        checked_at
    )
    VALUES (
        MD5(CONCAT('DAILY_ACCESS_REPORT', report_date)),
        'DAILY_ACCESS_REPORT',
        'ACCOUNT_USAGE',
        'PASSED',
        CONCAT('Date: ', report_date, 
               ', Total queries: ', :total_queries,
               ', Unique users: ', :unique_users,
               ', Sensitive accesses: ', :sensitive_accesses,
               ', Failed attempts: ', :failed_attempts),
        CURRENT_TIMESTAMP()
    );
    
    RETURN CONCAT('Daily report generated. Queries: ', :total_queries, 
                  ', Users: ', :unique_users, 
                  ', Sensitive: ', :sensitive_accesses,
                  ', Failed: ', :failed_attempts);
END;
$$;

-- Procedure to alert on suspicious activity
CREATE OR REPLACE PROCEDURE check_suspicious_activity()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    anomaly_count INT;
    critical_failures INT;
BEGIN
    -- Check for anomalies in last hour
    SELECT COUNT(*) INTO :anomaly_count
    FROM v_access_anomalies
    WHERE access_hour >= DATEADD(hour, -1, CURRENT_TIMESTAMP());
    
    -- Check for critical permission failures
    SELECT COUNT(*) INTO :critical_failures
    FROM v_failed_access_attempts
    WHERE start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
      AND error_category = 'Permission denied';
    
    IF (:anomaly_count > 5 OR :critical_failures > 10) THEN
        -- Log alert
        INSERT INTO privacy_compliance_log (
            compliance_id,
            check_type,
            table_name,
            check_result,
            details,
            checked_at
        )
        VALUES (
            MD5(CONCAT('SUSPICIOUS_ACTIVITY', CURRENT_TIMESTAMP())),
            'SECURITY_ALERT',
            'ACCESS_PATTERNS',
            'WARNING',
            CONCAT('ALERT: Anomalies detected: ', :anomaly_count, 
                   ', Permission failures: ', :critical_failures),
            CURRENT_TIMESTAMP()
        );
        
        RETURN CONCAT('ALERT: Suspicious activity detected. Anomalies: ', :anomaly_count, 
                     ', Failures: ', :critical_failures);
    ELSE
        RETURN 'No suspicious activity detected';
    END IF;
END;
$$;

-- ============================================================================
-- COMPLIANCE REPORTING VIEWS
-- ============================================================================

-- Monthly compliance summary
CREATE OR REPLACE VIEW v_monthly_compliance_summary AS
SELECT 
    DATE_TRUNC('month', checked_at) AS compliance_month,
    check_type,
    check_result,
    COUNT(*) AS check_count,
    COUNT(CASE WHEN check_result = 'PASSED' THEN 1 END) AS passed_count,
    COUNT(CASE WHEN check_result = 'FAILED' THEN 1 END) AS failed_count,
    COUNT(CASE WHEN check_result = 'WARNING' THEN 1 END) AS warning_count
FROM privacy_compliance_log
WHERE checked_at >= DATEADD(month, -12, CURRENT_TIMESTAMP())
GROUP BY DATE_TRUNC('month', checked_at), check_type, check_result
ORDER BY compliance_month DESC, check_type;

-- Data access by role summary
CREATE OR REPLACE VIEW v_role_access_summary AS
SELECT 
    role_name,
    schema_name,
    COUNT(*) AS query_count,
    COUNT(DISTINCT user_name) AS unique_users,
    SUM(rows_produced) AS total_rows_accessed,
    AVG(total_elapsed_time) AS avg_query_time_ms,
    MIN(start_time) AS first_access,
    MAX(start_time) AS last_access
FROM v_sensitive_data_access
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY role_name, schema_name
ORDER BY query_count DESC;

-- ============================================================================
-- AUDIT TRAIL EXPORT FUNCTION
-- ============================================================================

-- Function to generate audit trail for specific date range
CREATE OR REPLACE PROCEDURE export_audit_trail(
    start_date DATE,
    end_date DATE
)
RETURNS TABLE (
    audit_date DATE,
    user_name VARCHAR,
    role_name VARCHAR,
    action VARCHAR,
    object_name VARCHAR,
    details VARCHAR,
    timestamp TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
BEGIN
    RETURN TABLE(
        SELECT 
            DATE(start_time) AS audit_date,
            user_name,
            role_name,
            'QUERY' AS action,
            database_name || '.' || schema_name AS object_name,
            LEFT(query_text, 200) AS details,
            start_time AS timestamp
        FROM v_sensitive_data_access
        WHERE DATE(start_time) BETWEEN start_date AND end_date
        
        UNION ALL
        
        SELECT 
            DATE(checked_at) AS audit_date,
            'SYSTEM' AS user_name,
            check_type AS role_name,
            'COMPLIANCE_CHECK' AS action,
            table_name AS object_name,
            details,
            checked_at AS timestamp
        FROM privacy_compliance_log
        WHERE DATE(checked_at) BETWEEN start_date AND end_date
        
        ORDER BY timestamp DESC
    );
END;
$$;

SELECT 'Audit logging and compliance monitoring configured successfully!' AS status;
