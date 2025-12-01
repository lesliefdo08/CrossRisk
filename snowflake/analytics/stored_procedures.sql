-- ============================================================================
-- CrossRisk Platform - Stored Procedures
-- ============================================================================
-- Additional utility stored procedures for data loading, maintenance,
-- and operational tasks.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE WAREHOUSE CROSSRISK_ETL_WH;

-- ============================================================================
-- DATA LOADING PROCEDURES
-- ============================================================================

-- Load bank data from CSV file
CREATE OR REPLACE PROCEDURE load_bank_data()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- This assumes data has been staged in CROSSRISK_STAGE
    COPY INTO RAW_DATA.bank_customer_risk_summary
    FROM @RAW_DATA.CROSSRISK_STAGE/bank_data.csv
    FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
    ON_ERROR = 'CONTINUE'
    PURGE = FALSE;
    
    RETURN 'Bank data loaded. Rows inserted: ' || SQLROWCOUNT;
END;
$$;

-- Load insurance data from CSV file
CREATE OR REPLACE PROCEDURE load_insurance_data()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    COPY INTO RAW_DATA.insurance_claim_risk_summary
    FROM @RAW_DATA.CROSSRISK_STAGE/insurance_data.csv
    FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
    ON_ERROR = 'CONTINUE'
    PURGE = FALSE;
    
    RETURN 'Insurance data loaded. Rows inserted: ' || SQLROWCOUNT;
END;
$$;

-- ============================================================================
-- DATA QUALITY VALIDATION
-- ============================================================================

-- Validate data completeness and quality
CREATE OR REPLACE PROCEDURE validate_data_quality()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    bank_count INT;
    insurance_count INT;
    matched_count INT;
    orphan_count INT;
    quality_score FLOAT;
BEGIN
    -- Count records
    SELECT COUNT(*) INTO :bank_count FROM RAW_DATA.bank_customer_risk_summary;
    SELECT COUNT(*) INTO :insurance_count FROM RAW_DATA.insurance_claim_risk_summary;
    
    -- Count matched customers
    SELECT COUNT(DISTINCT b.customer_id) INTO :matched_count
    FROM RAW_DATA.bank_customer_risk_summary b
    INNER JOIN RAW_DATA.insurance_claim_risk_summary i ON b.customer_id = i.customer_id;
    
    -- Count orphaned records
    SELECT 
        (SELECT COUNT(*) FROM RAW_DATA.bank_customer_risk_summary WHERE customer_id NOT IN (SELECT customer_id FROM RAW_DATA.insurance_claim_risk_summary)) +
        (SELECT COUNT(*) FROM RAW_DATA.insurance_claim_risk_summary WHERE customer_id NOT IN (SELECT customer_id FROM RAW_DATA.bank_customer_risk_summary))
    INTO :orphan_count;
    
    -- Calculate quality score
    quality_score := (matched_count::FLOAT / GREATEST(bank_count, insurance_count)) * 100;
    
    -- Log results
    INSERT INTO GOVERNANCE.privacy_compliance_log (
        compliance_id,
        check_type,
        table_name,
        check_result,
        details,
        checked_at
    )
    VALUES (
        MD5(CONCAT('DATA_QUALITY', CURRENT_TIMESTAMP())),
        'DATA_QUALITY',
        'RAW_DATA',
        CASE WHEN quality_score >= 80 THEN 'PASSED' WHEN quality_score >= 60 THEN 'WARNING' ELSE 'FAILED' END,
        CONCAT('Bank records: ', :bank_count, ', Insurance records: ', :insurance_count, 
               ', Matched: ', :matched_count, ', Orphaned: ', :orphan_count, 
               ', Quality score: ', ROUND(:quality_score, 2), '%'),
        CURRENT_TIMESTAMP()
    );
    
    RETURN CONCAT('Data quality check completed. Quality score: ', ROUND(:quality_score, 2), '%. Bank: ', :bank_count, ', Insurance: ', :insurance_count, ', Matched: ', :matched_count);
END;
$$;

-- ============================================================================
-- PRIVACY COMPLIANCE CHECKS
-- ============================================================================

-- Verify k-anonymity compliance
CREATE OR REPLACE PROCEDURE check_k_anonymity_compliance()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    violation_count INT;
    total_segments INT;
BEGIN
    -- Check for segments with fewer than k=3 records
    SELECT COUNT(*) INTO :violation_count
    FROM ANALYTICS.risk_join_aggregated
    WHERE record_count < 3;
    
    SELECT COUNT(*) INTO :total_segments
    FROM ANALYTICS.risk_join_aggregated;
    
    -- Log compliance check
    INSERT INTO GOVERNANCE.privacy_compliance_log (
        compliance_id,
        check_type,
        table_name,
        check_result,
        details,
        checked_at
    )
    VALUES (
        MD5(CONCAT('K_ANONYMITY', CURRENT_TIMESTAMP())),
        'K_ANONYMITY',
        'ANALYTICS.risk_join_aggregated',
        CASE WHEN :violation_count = 0 THEN 'PASSED' ELSE 'FAILED' END,
        CONCAT('Total segments: ', :total_segments, ', Violations (k<3): ', :violation_count),
        CURRENT_TIMESTAMP()
    );
    
    IF (:violation_count > 0) THEN
        RETURN CONCAT('WARNING: ', :violation_count, ' segments violate k-anonymity (k=3) requirement out of ', :total_segments, ' total segments');
    ELSE
        RETURN CONCAT('PASSED: All ', :total_segments, ' segments comply with k-anonymity (k=3) requirement');
    END IF;
END;
$$;

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

-- Log query access for governance
CREATE OR REPLACE PROCEDURE log_query_access(
    query_text_param VARCHAR,
    query_type_param VARCHAR,
    tables_accessed_param ARRAY,
    row_count_param INT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO GOVERNANCE.access_audit_log (
        audit_id,
        user_name,
        role_name,
        query_text,
        query_type,
        tables_accessed,
        row_count,
        execution_time_ms,
        session_id,
        executed_at
    )
    VALUES (
        MD5(CONCAT(CURRENT_USER(), CURRENT_TIMESTAMP())),
        CURRENT_USER(),
        CURRENT_ROLE(),
        query_text_param,
        query_type_param,
        tables_accessed_param,
        row_count_param,
        NULL,  -- Execution time would need to be calculated separately
        CURRENT_SESSION(),
        CURRENT_TIMESTAMP()
    );
    
    RETURN 'Query access logged successfully';
END;
$$;

-- ============================================================================
-- DATA REFRESH AND MAINTENANCE
-- ============================================================================

-- Complete data refresh pipeline
CREATE OR REPLACE PROCEDURE run_complete_data_refresh()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    quality_result VARCHAR;
    analytics_result VARCHAR;
    ai_result VARCHAR;
    compliance_result VARCHAR;
BEGIN
    -- Step 1: Validate data quality
    CALL validate_data_quality() INTO :quality_result;
    
    -- Step 2: Run analytics refresh
    CALL ANALYTICS.run_full_analytics_refresh() INTO :analytics_result;
    
    -- Step 3: Generate AI insights
    CALL AI_INSIGHTS.refresh_all_ai_insights() INTO :ai_result;
    
    -- Step 4: Check compliance
    CALL check_k_anonymity_compliance() INTO :compliance_result;
    
    RETURN CONCAT(
        'Complete refresh pipeline finished. ',
        'Quality: ', :quality_result, ' | ',
        'Analytics: ', :analytics_result, ' | ',
        'AI: ', :ai_result, ' | ',
        'Compliance: ', :compliance_result
    );
END;
$$;

-- ============================================================================
-- CLEANUP AND ARCHIVAL
-- ============================================================================

-- Archive old audit logs
CREATE OR REPLACE PROCEDURE archive_old_audit_logs(retention_days INT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    archived_count INT;
BEGIN
    -- Create archive table if not exists
    CREATE TABLE IF NOT EXISTS GOVERNANCE.access_audit_log_archive LIKE GOVERNANCE.access_audit_log;
    
    -- Move old records to archive
    INSERT INTO GOVERNANCE.access_audit_log_archive
    SELECT * FROM GOVERNANCE.access_audit_log
    WHERE executed_at < DATEADD(day, -retention_days, CURRENT_TIMESTAMP());
    
    archived_count := SQLROWCOUNT;
    
    -- Delete archived records from main table
    DELETE FROM GOVERNANCE.access_audit_log
    WHERE executed_at < DATEADD(day, -retention_days, CURRENT_TIMESTAMP());
    
    RETURN CONCAT('Archived ', :archived_count, ' audit log records older than ', retention_days, ' days');
END;
$$;

-- ============================================================================
-- EMERGENCY PROCEDURES
-- ============================================================================

-- Emergency data freeze (prevent updates during incident)
CREATE OR REPLACE PROCEDURE emergency_data_freeze()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Create a flag table to indicate freeze status
    CREATE TABLE IF NOT EXISTS GOVERNANCE.system_status (
        status_key VARCHAR PRIMARY KEY,
        status_value VARCHAR,
        updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    );
    
    MERGE INTO GOVERNANCE.system_status AS target
    USING (SELECT 'DATA_FREEZE' AS status_key, 'ACTIVE' AS status_value) AS source
    ON target.status_key = source.status_key
    WHEN MATCHED THEN
        UPDATE SET status_value = source.status_value, updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN
        INSERT (status_key, status_value, updated_at)
        VALUES (source.status_key, source.status_value, CURRENT_TIMESTAMP());
    
    -- Log the freeze
    INSERT INTO GOVERNANCE.privacy_compliance_log (
        compliance_id,
        check_type,
        table_name,
        check_result,
        details,
        checked_at
    )
    VALUES (
        MD5(CONCAT('EMERGENCY_FREEZE', CURRENT_TIMESTAMP())),
        'EMERGENCY_FREEZE',
        'SYSTEM_WIDE',
        'WARNING',
        CONCAT('Data freeze activated by ', CURRENT_USER(), ' at ', CURRENT_TIMESTAMP()),
        CURRENT_TIMESTAMP()
    );
    
    RETURN 'EMERGENCY DATA FREEZE ACTIVATED. All data update operations should be suspended.';
END;
$$;

-- Unfreeze data operations
CREATE OR REPLACE PROCEDURE unfreeze_data_operations()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE GOVERNANCE.system_status
    SET status_value = 'INACTIVE', updated_at = CURRENT_TIMESTAMP()
    WHERE status_key = 'DATA_FREEZE';
    
    INSERT INTO GOVERNANCE.privacy_compliance_log (
        compliance_id,
        check_type,
        table_name,
        check_result,
        details,
        checked_at
    )
    VALUES (
        MD5(CONCAT('UNFREEZE', CURRENT_TIMESTAMP())),
        'UNFREEZE',
        'SYSTEM_WIDE',
        'PASSED',
        CONCAT('Data freeze deactivated by ', CURRENT_USER(), ' at ', CURRENT_TIMESTAMP()),
        CURRENT_TIMESTAMP()
    );
    
    RETURN 'Data operations unfrozen. Normal operations can resume.';
END;
$$;

-- ============================================================================
-- HEALTH CHECK
-- ============================================================================

-- Comprehensive system health check
CREATE OR REPLACE PROCEDURE system_health_check()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    bank_rows INT;
    insurance_rows INT;
    analytics_rows INT;
    ai_explanations INT;
    audit_rows_today INT;
    freeze_status VARCHAR;
    health_status VARCHAR;
BEGIN
    -- Check data volumes
    SELECT COUNT(*) INTO :bank_rows FROM RAW_DATA.bank_customer_risk_summary;
    SELECT COUNT(*) INTO :insurance_rows FROM RAW_DATA.insurance_claim_risk_summary;
    SELECT COUNT(*) INTO :analytics_rows FROM ANALYTICS.risk_join_aggregated;
    SELECT COUNT(*) INTO :ai_explanations FROM AI_INSIGHTS.ai_explanations;
    SELECT COUNT(*) INTO :audit_rows_today FROM GOVERNANCE.access_audit_log WHERE executed_at >= CURRENT_DATE();
    
    -- Check freeze status
    SELECT COALESCE(status_value, 'INACTIVE') INTO :freeze_status
    FROM GOVERNANCE.system_status
    WHERE status_key = 'DATA_FREEZE';
    
    -- Determine overall health
    IF (:bank_rows > 0 AND :insurance_rows > 0 AND :analytics_rows > 0 AND :freeze_status = 'INACTIVE') THEN
        health_status := 'HEALTHY';
    ELSIF (:freeze_status = 'ACTIVE') THEN
        health_status := 'FROZEN';
    ELSIF (:bank_rows = 0 OR :insurance_rows = 0) THEN
        health_status := 'NO_DATA';
    ELSE
        health_status := 'DEGRADED';
    END IF;
    
    RETURN OBJECT_CONSTRUCT(
        'status', :health_status,
        'bank_records', :bank_rows,
        'insurance_records', :insurance_rows,
        'analytics_segments', :analytics_rows,
        'ai_explanations', :ai_explanations,
        'audit_entries_today', :audit_rows_today,
        'freeze_status', :freeze_status,
        'timestamp', CURRENT_TIMESTAMP()
    )::VARCHAR;
END;
$$;

SELECT 'Stored procedures created successfully!' AS status;
