-- ============================================================================
-- CrossRisk Platform - Automated Tasks
-- ============================================================================
-- Defines Snowflake tasks to automate data pipeline execution, analytics
-- refresh, and maintenance operations.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE WAREHOUSE CROSSRISK_ETL_WH;

-- ============================================================================
-- ROOT TASK - ORCHESTRATION
-- ============================================================================

-- Main orchestration task that runs every 6 hours
CREATE OR REPLACE TASK crossrisk_main_orchestrator
    WAREHOUSE = CROSSRISK_ETL_WH
    SCHEDULE = 'USING CRON 0 */6 * * * UTC'  -- Every 6 hours
    COMMENT = 'Main orchestration task for CrossRisk analytics pipeline'
AS
    CALL run_complete_data_refresh();

-- ============================================================================
-- CHILD TASKS - TRIGGERED BY DATA CHANGES
-- ============================================================================

-- Task to refresh analytics when bank data changes
CREATE OR REPLACE TASK refresh_on_bank_changes
    WAREHOUSE = CROSSRISK_ETL_WH
    AFTER crossrisk_main_orchestrator
    WHEN SYSTEM$STREAM_HAS_DATA('bank_data_changes')
    COMMENT = 'Refresh analytics when bank data is updated'
AS
    CALL ANALYTICS.run_full_analytics_refresh();

-- Task to refresh analytics when insurance data changes
CREATE OR REPLACE TASK refresh_on_insurance_changes
    WAREHOUSE = CROSSRISK_ETL_WH
    AFTER crossrisk_main_orchestrator
    WHEN SYSTEM$STREAM_HAS_DATA('insurance_data_changes')
    COMMENT = 'Refresh analytics when insurance data is updated'
AS
    CALL ANALYTICS.run_full_analytics_refresh();

-- ============================================================================
-- AI INSIGHTS GENERATION TASKS
-- ============================================================================

-- Task to generate AI insights after analytics refresh
CREATE OR REPLACE TASK generate_ai_insights_task
    WAREHOUSE = CROSSRISK_AI_WH
    AFTER refresh_on_bank_changes, refresh_on_insurance_changes
    COMMENT = 'Generate AI-powered insights after analytics update'
AS
    CALL AI_INSIGHTS.refresh_all_ai_insights();

-- Task to refresh pre-approved questions daily
CREATE OR REPLACE TASK refresh_approved_questions_task
    WAREHOUSE = CROSSRISK_AI_WH
    SCHEDULE = 'USING CRON 0 8 * * * UTC'  -- Daily at 8 AM UTC
    COMMENT = 'Refresh pre-approved analytics questions daily'
AS
    CALL AI_INSIGHTS.populate_approved_questions();

-- ============================================================================
-- COMPLIANCE AND MONITORING TASKS
-- ============================================================================

-- Task to check k-anonymity compliance hourly
CREATE OR REPLACE TASK check_compliance_hourly
    WAREHOUSE = CROSSRISK_ETL_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour
    COMMENT = 'Hourly privacy compliance verification'
AS
    CALL check_k_anonymity_compliance();

-- Task to monitor for suspicious access patterns
CREATE OR REPLACE TASK monitor_suspicious_access
    WAREHOUSE = CROSSRISK_ETL_WH
    SCHEDULE = 'USING CRON 0 */2 * * * UTC'  -- Every 2 hours
    WHEN SYSTEM$STREAM_HAS_DATA('audit_log_stream')
    COMMENT = 'Monitor audit logs for suspicious access patterns'
AS
DECLARE
    suspicious_count INT;
BEGIN
    -- Count unusual access patterns (e.g., high volume queries, off-hours access)
    SELECT COUNT(*) INTO :suspicious_count
    FROM audit_log_stream
    WHERE row_count > 1000  -- Large data extracts
       OR HOUR(executed_at) NOT BETWEEN 6 AND 22;  -- Off-hours activity
    
    IF (:suspicious_count > 0) THEN
        -- Log warning
        INSERT INTO GOVERNANCE.privacy_compliance_log (
            compliance_id,
            check_type,
            table_name,
            check_result,
            details,
            checked_at
        )
        VALUES (
            MD5(CONCAT('SUSPICIOUS_ACCESS', CURRENT_TIMESTAMP())),
            'ACCESS_MONITORING',
            'access_audit_log',
            'WARNING',
            CONCAT('Detected ', :suspicious_count, ' potentially suspicious access patterns'),
            CURRENT_TIMESTAMP()
        );
    END IF;
END;

-- ============================================================================
-- MAINTENANCE TASKS
-- ============================================================================

-- Task to archive old audit logs weekly
CREATE OR REPLACE TASK archive_logs_weekly
    WAREHOUSE = CROSSRISK_ETL_WH
    SCHEDULE = 'USING CRON 0 2 * * 0 UTC'  -- Every Sunday at 2 AM UTC
    COMMENT = 'Weekly archival of old audit logs'
AS
    CALL archive_old_audit_logs(90);  -- Archive logs older than 90 days

-- Task to validate data quality daily
CREATE OR REPLACE TASK validate_quality_daily
    WAREHOUSE = CROSSRISK_ETL_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'  -- Daily at 6 AM UTC
    COMMENT = 'Daily data quality validation'
AS
    CALL validate_data_quality();

-- Task to calculate regional trends daily
CREATE OR REPLACE TASK calculate_trends_daily
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'  -- Daily at 7 AM UTC
    COMMENT = 'Daily regional risk trend calculation'
AS
    CALL ANALYTICS.calculate_regional_trends();

-- ============================================================================
-- FRAUD DETECTION TASKS
-- ============================================================================

-- Task to detect fraud signals every 4 hours
CREATE OR REPLACE TASK detect_fraud_patterns_task
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 */4 * * * UTC'  -- Every 4 hours
    COMMENT = 'Periodic fraud pattern detection'
AS
    CALL ANALYTICS.detect_fraud_signals();

-- Task to alert on critical fraud patterns
CREATE OR REPLACE TASK alert_critical_fraud
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    AFTER detect_fraud_patterns_task
    WHEN SYSTEM$STREAM_HAS_DATA('fraud_signal_changes')
    COMMENT = 'Alert when critical fraud patterns are detected'
AS
DECLARE
    critical_count INT;
BEGIN
    -- Check for critical fraud patterns
    SELECT COUNT(*) INTO :critical_count
    FROM fraud_signal_changes
    WHERE METADATA$ACTION = 'INSERT'
      AND confidence_score > 0.8;
    
    IF (:critical_count > 0) THEN
        -- Log critical alert
        INSERT INTO GOVERNANCE.privacy_compliance_log (
            compliance_id,
            check_type,
            table_name,
            check_result,
            details,
            checked_at
        )
        VALUES (
            MD5(CONCAT('CRITICAL_FRAUD', CURRENT_TIMESTAMP())),
            'FRAUD_ALERT',
            'fraud_cross_signals',
            'WARNING',
            CONCAT('ALERT: ', :critical_count, ' critical fraud patterns detected with high confidence'),
            CURRENT_TIMESTAMP()
        );
    END IF;
END;

-- ============================================================================
-- TASK MANAGEMENT PROCEDURES
-- ============================================================================

-- Resume all tasks
CREATE OR REPLACE PROCEDURE resume_all_tasks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    ALTER TASK crossrisk_main_orchestrator RESUME;
    ALTER TASK refresh_on_bank_changes RESUME;
    ALTER TASK refresh_on_insurance_changes RESUME;
    ALTER TASK generate_ai_insights_task RESUME;
    ALTER TASK refresh_approved_questions_task RESUME;
    ALTER TASK check_compliance_hourly RESUME;
    ALTER TASK monitor_suspicious_access RESUME;
    ALTER TASK archive_logs_weekly RESUME;
    ALTER TASK validate_quality_daily RESUME;
    ALTER TASK calculate_trends_daily RESUME;
    ALTER TASK detect_fraud_patterns_task RESUME;
    ALTER TASK alert_critical_fraud RESUME;
    
    RETURN 'All tasks resumed successfully';
END;
$$;

-- Suspend all tasks
CREATE OR REPLACE PROCEDURE suspend_all_tasks()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    ALTER TASK alert_critical_fraud SUSPEND;
    ALTER TASK detect_fraud_patterns_task SUSPEND;
    ALTER TASK calculate_trends_daily SUSPEND;
    ALTER TASK validate_quality_daily SUSPEND;
    ALTER TASK archive_logs_weekly SUSPEND;
    ALTER TASK monitor_suspicious_access SUSPEND;
    ALTER TASK check_compliance_hourly SUSPEND;
    ALTER TASK refresh_approved_questions_task SUSPEND;
    ALTER TASK generate_ai_insights_task SUSPEND;
    ALTER TASK refresh_on_insurance_changes SUSPEND;
    ALTER TASK refresh_on_bank_changes SUSPEND;
    ALTER TASK crossrisk_main_orchestrator SUSPEND;
    
    RETURN 'All tasks suspended successfully';
END;
$$;

-- Get task status
CREATE OR REPLACE PROCEDURE get_task_status()
RETURNS TABLE (
    task_name VARCHAR,
    state VARCHAR,
    schedule VARCHAR,
    last_run TIMESTAMP_NTZ,
    next_run TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
BEGIN
    RETURN TABLE(
        SELECT 
            name AS task_name,
            state,
            schedule,
            last_committed_on AS last_run,
            scheduled_time AS next_run
        FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
        WHERE database_name = 'CROSSRISK_DB'
        ORDER BY name
    );
END;
$$;

-- ============================================================================
-- INITIAL TASK SETUP
-- ============================================================================

-- Note: Tasks are created in SUSPENDED state by default
-- Uncomment the following line to activate all tasks:
-- CALL resume_all_tasks();

SELECT 'Tasks created successfully! Run resume_all_tasks() to activate automation.' AS status;
