/*******************************************************************************
 * File: analytics/risk_engine.sql
 * Purpose: Core risk analytics engine that calculates composite risk scores,
 *          detects fraud patterns, and generates cross-organizational insights.
 * 
 * Schema/Objects:
 * - Functions: calculate_composite_risk, calculate_fraud_correlation,
 *   get_risk_category
 * - Views: v_risk_join_aggregated, v_segment_risk_profile,
 *   v_age_group_comparison, v_occupation_risk_analysis
 * - Procedures: refresh_risk_aggregations, calculate_regional_trends,
 *   detect_fraud_signals, run_full_analytics_refresh
 * - Table: risk_category_definitions (populated with risk thresholds)
 * 
 * Dependencies:
 * - Requires setup.sql, schemas.sql, and masking_policies.sql executed first
 * - Needs data in RAW_DATA tables (bank and insurance)
 *
 * Privacy/Security:
 * - All aggregations enforce k-anonymity with HAVING COUNT >= 3
 * - No individual customer data exposed, only grouped statistics
 * - Fraud detection operates on aggregated patterns only
 *  
 * Usage:
 * snowsql -f snowflake/analytics/risk_engine.sql
 *
 * Author: Leslie Fernando
 * Created: 2024 (Snowflake Hackathon)
 ******************************************************************************/

-- ============================================================================
-- CrossRisk Platform - Risk Analytics Engine
-- ============================================================================
-- Core analytics logic for calculating composite risk scores, detecting
-- fraud patterns, and generating privacy-safe cross-organization insights.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CROSSRISK_ANALYTICS_WH;

-- ============================================================================
-- POPULATE RISK CATEGORY DEFINITIONS
-- ============================================================================

INSERT INTO risk_category_definitions (category, min_score, max_score, description, recommended_action) VALUES
('LOW', 0, 25, 'Minimal risk indicators across both organizations', 'Standard monitoring protocols'),
('MEDIUM', 25, 50, 'Moderate risk signals requiring attention', 'Enhanced monitoring and periodic review'),
('HIGH', 50, 75, 'Significant risk factors detected', 'Immediate review and risk mitigation required'),
('CRITICAL', 75, 100, 'Severe risk indicators requiring urgent action', 'Urgent investigation and intervention needed');

-- ============================================================================
-- COMPOSITE RISK CALCULATION FUNCTION
-- ============================================================================

-- Calculates weighted composite risk score from bank and insurance data
-- Formula: (bank_risk * 0.6 + insurance_risk * 0.4) + penalties for fraud flags
CREATE OR REPLACE FUNCTION calculate_composite_risk(
    bank_risk FLOAT,
    insurance_risk FLOAT,
    fraud_flags INT,
    claim_flags INT
)
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    -- Weighted average with fraud multipliers
    -- Bank risk weight: 60%, Insurance risk weight: 40%
    -- Additional penalty for fraud indicators
    (bank_risk * 0.6 + insurance_risk * 0.4) + 
    (fraud_flags * 5) + 
    (claim_flags * 3)
$$;

-- ============================================================================
-- FRAUD CORRELATION DETECTION FUNCTION
-- ============================================================================

-- Detects fraud correlation between banking and insurance signals
-- Returns confidence score (0.0-1.0) based on cross-organizational patterns
CREATE OR REPLACE FUNCTION calculate_fraud_correlation(
    fraud_flags INT,
    claim_flags INT,
    transaction_velocity VARCHAR,
    claim_frequency VARCHAR
)
RETURNS FLOAT
LANGUAGE SQL
AS
$$
    CASE
        -- High correlation: Multiple fraud signals + high activity
        WHEN fraud_flags > 0 AND claim_flags > 0 AND 
             transaction_velocity = 'High' AND claim_frequency IN ('Elevated', 'Critical')
        THEN 0.95
        
        -- Medium-high correlation: Some fraud signals + elevated patterns
        WHEN (fraud_flags > 0 OR claim_flags > 0) AND 
             (transaction_velocity = 'High' OR claim_frequency IN ('Elevated', 'Critical'))
        THEN 0.75
        
        -- Medium correlation: Single fraud indicator
        WHEN fraud_flags > 0 OR claim_flags > 0
        THEN 0.50
        
        -- Low correlation: Elevated patterns but no fraud flags
        WHEN transaction_velocity = 'High' OR claim_frequency = 'Elevated'
        THEN 0.25
        
        -- No correlation detected
        ELSE 0.05
    END
$$;

-- ============================================================================
-- RISK CATEGORY MAPPING FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_risk_category(risk_score FLOAT)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT category
    FROM risk_category_definitions
    WHERE risk_score >= min_score AND risk_score < max_score
    LIMIT 1
$$;

-- ============================================================================
-- MAIN AGGREGATED RISK JOIN VIEW
-- ============================================================================
-- This view performs privacy-safe aggregation with k-anonymity enforcement

CREATE OR REPLACE VIEW v_risk_join_aggregated AS
SELECT 
    MD5(CONCAT(b.age_group, b.region, COALESCE(b.occupation_category, 'UNKNOWN'))) AS analysis_id,
    b.age_group,
    b.region,
    b.occupation_category,
    COUNT(DISTINCT b.customer_id) AS record_count,
    AVG(b.risk_score) AS avg_bank_risk_score,
    AVG(i.risk_score) AS avg_insurance_risk_score,
    calculate_composite_risk(
        AVG(b.risk_score),
        AVG(i.risk_score),
        SUM(b.fraud_flag_history),
        SUM(i.suspicious_claim_flags)
    ) AS composite_risk_score,
    get_risk_category(
        calculate_composite_risk(
            AVG(b.risk_score),
            AVG(i.risk_score),
            SUM(b.fraud_flag_history),
            SUM(i.suspicious_claim_flags)
        )
    ) AS risk_category,
    AVG(
        calculate_fraud_correlation(
            b.fraud_flag_history,
            i.suspicious_claim_flags,
            b.transaction_velocity,
            i.claim_frequency_pattern
        )
    ) AS fraud_correlation_score,
    CURRENT_TIMESTAMP() AS analysis_timestamp
FROM RAW_DATA.bank_customer_risk_summary b
INNER JOIN RAW_DATA.insurance_claim_risk_summary i
    ON b.customer_id = i.customer_id
GROUP BY b.age_group, b.region, b.occupation_category
HAVING COUNT(DISTINCT b.customer_id) >= 3  -- k-anonymity enforcement
ORDER BY composite_risk_score DESC;

-- ============================================================================
-- REFRESH AGGREGATED RISK TABLE
-- ============================================================================
-- Procedure to populate the risk_join_aggregated table from the view

CREATE OR REPLACE PROCEDURE refresh_risk_aggregations()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Clear existing data
    DELETE FROM risk_join_aggregated;
    
    -- Insert fresh aggregations
    INSERT INTO risk_join_aggregated (
        analysis_id,
        age_group,
        region,
        occupation_category,
        record_count,
        avg_bank_risk_score,
        avg_insurance_risk_score,
        composite_risk_score,
        risk_category,
        fraud_correlation_score,
        analysis_timestamp
    )
    SELECT 
        analysis_id,
        age_group,
        region,
        occupation_category,
        record_count,
        avg_bank_risk_score,
        avg_insurance_risk_score,
        composite_risk_score,
        risk_category,
        fraud_correlation_score,
        analysis_timestamp
    FROM v_risk_join_aggregated;
    
    RETURN 'Risk aggregations refreshed successfully. Total rows: ' || (SELECT COUNT(*) FROM risk_join_aggregated);
END;
$$;

-- ============================================================================
-- REGIONAL RISK TRENDS ANALYSIS
-- ============================================================================

CREATE OR REPLACE PROCEDURE calculate_regional_trends()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Calculate current trends
    INSERT INTO regional_risk_trends (
        trend_id,
        region,
        analysis_date,
        customer_count,
        avg_composite_risk,
        high_risk_percentage,
        trend_direction,
        created_at
    )
    SELECT 
        MD5(CONCAT(region, CURRENT_DATE())) AS trend_id,
        region,
        CURRENT_DATE() AS analysis_date,
        SUM(record_count) AS customer_count,
        AVG(composite_risk_score) AS avg_composite_risk,
        (SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / SUM(record_count)) AS high_risk_percentage,
        CASE
            WHEN AVG(composite_risk_score) > (
                SELECT AVG(avg_composite_risk) 
                FROM regional_risk_trends 
                WHERE region = rja.region 
                AND analysis_date = DATEADD(day, -7, CURRENT_DATE())
            ) THEN 'INCREASING'
            WHEN AVG(composite_risk_score) < (
                SELECT AVG(avg_composite_risk) 
                FROM regional_risk_trends 
                WHERE region = rja.region 
                AND analysis_date = DATEADD(day, -7, CURRENT_DATE())
            ) THEN 'DECREASING'
            ELSE 'STABLE'
        END AS trend_direction,
        CURRENT_TIMESTAMP() AS created_at
    FROM risk_join_aggregated rja
    GROUP BY region
    HAVING SUM(record_count) >= 3;
    
    RETURN 'Regional trends calculated successfully. Total regions: ' || (SELECT COUNT(DISTINCT region) FROM regional_risk_trends WHERE analysis_date = CURRENT_DATE());
END;
$$;

-- ============================================================================
-- FRAUD CROSS-SIGNAL DETECTION
-- ============================================================================

CREATE OR REPLACE PROCEDURE detect_fraud_signals()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Detect patterns of coordinated fraud signals
    INSERT INTO fraud_cross_signals (
        signal_id,
        age_group,
        region,
        pattern_description,
        affected_customer_count,
        confidence_score,
        detected_at
    )
    SELECT 
        MD5(CONCAT(age_group, region, CURRENT_TIMESTAMP())) AS signal_id,
        age_group,
        region,
        CASE
            WHEN AVG(fraud_correlation_score) > 0.8 THEN 'Critical: High correlation between banking fraud flags and insurance claim anomalies'
            WHEN AVG(fraud_correlation_score) > 0.6 THEN 'Elevated: Moderate cross-organizational fraud indicators detected'
            WHEN AVG(fraud_correlation_score) > 0.4 THEN 'Warning: Some coordinated suspicious activity patterns'
            ELSE 'Low: Minimal fraud correlation detected'
        END AS pattern_description,
        SUM(record_count) AS affected_customer_count,
        AVG(fraud_correlation_score) AS confidence_score,
        CURRENT_TIMESTAMP() AS detected_at
    FROM risk_join_aggregated
    WHERE fraud_correlation_score > 0.3  -- Only flag meaningful correlations
    GROUP BY age_group, region
    HAVING SUM(record_count) >= 3
    AND AVG(fraud_correlation_score) > 0.4;
    
    RETURN 'Fraud signals detected and logged. Total signals: ' || (SELECT COUNT(*) FROM fraud_cross_signals WHERE detected_at >= DATEADD(hour, -1, CURRENT_TIMESTAMP()));
END;
$$;

-- ============================================================================
-- SEGMENT RISK PROFILING
-- ============================================================================
-- Creates detailed risk profiles for specific customer segments

CREATE OR REPLACE VIEW v_segment_risk_profile AS
SELECT 
    age_group,
    region,
    occupation_category,
    record_count,
    composite_risk_score,
    risk_category,
    fraud_correlation_score,
    avg_bank_risk_score,
    avg_insurance_risk_score,
    -- Risk drivers analysis
    CASE
        WHEN avg_bank_risk_score > avg_insurance_risk_score + 10 THEN 'Primary driver: Banking risk'
        WHEN avg_insurance_risk_score > avg_bank_risk_score + 10 THEN 'Primary driver: Insurance claims'
        ELSE 'Balanced risk across both organizations'
    END AS primary_risk_driver,
    -- Relative risk ranking
    PERCENT_RANK() OVER (ORDER BY composite_risk_score) AS risk_percentile,
    -- Risk concentration
    CASE
        WHEN fraud_correlation_score > 0.7 THEN 'High fraud correlation'
        WHEN composite_risk_score > 60 THEN 'High individual risk'
        WHEN record_count > 10 THEN 'Large segment volume'
        ELSE 'Standard risk profile'
    END AS segment_flag
FROM risk_join_aggregated
WHERE record_count >= 3
ORDER BY composite_risk_score DESC;

-- ============================================================================
-- AGE GROUP RISK COMPARISON
-- ============================================================================

CREATE OR REPLACE VIEW v_age_group_comparison AS
SELECT 
    age_group,
    COUNT(DISTINCT analysis_id) AS segment_count,
    SUM(record_count) AS total_customers,
    AVG(composite_risk_score) AS avg_risk,
    MIN(composite_risk_score) AS min_risk,
    MAX(composite_risk_score) AS max_risk,
    STDDEV(composite_risk_score) AS risk_variance,
    AVG(fraud_correlation_score) AS avg_fraud_correlation,
    SUM(CASE WHEN risk_category = 'CRITICAL' THEN record_count ELSE 0 END) AS critical_count,
    SUM(CASE WHEN risk_category = 'HIGH' THEN record_count ELSE 0 END) AS high_count,
    SUM(CASE WHEN risk_category = 'MEDIUM' THEN record_count ELSE 0 END) AS medium_count,
    SUM(CASE WHEN risk_category = 'LOW' THEN record_count ELSE 0 END) AS low_count
FROM risk_join_aggregated
GROUP BY age_group
HAVING SUM(record_count) >= 3
ORDER BY avg_risk DESC;

-- ============================================================================
-- OCCUPATION RISK ANALYSIS
-- ============================================================================

CREATE OR REPLACE VIEW v_occupation_risk_analysis AS
SELECT 
    occupation_category,
    COUNT(DISTINCT analysis_id) AS segment_count,
    SUM(record_count) AS total_customers,
    AVG(composite_risk_score) AS avg_risk,
    AVG(avg_bank_risk_score) AS avg_bank_risk,
    AVG(avg_insurance_risk_score) AS avg_insurance_risk,
    AVG(fraud_correlation_score) AS avg_fraud_correlation,
    (SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / SUM(record_count)) AS high_risk_percentage
FROM risk_join_aggregated
WHERE occupation_category IS NOT NULL
GROUP BY occupation_category
HAVING SUM(record_count) >= 3
ORDER BY avg_risk DESC;

-- ============================================================================
-- MASTER ANALYTICS REFRESH PROCEDURE
-- ============================================================================
-- Orchestrates all analytics calculations in proper sequence

CREATE OR REPLACE PROCEDURE run_full_analytics_refresh()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result1 VARCHAR;
    result2 VARCHAR;
    result3 VARCHAR;
BEGIN
    -- Step 1: Refresh risk aggregations
    CALL refresh_risk_aggregations() INTO :result1;
    
    -- Step 2: Calculate regional trends
    CALL calculate_regional_trends() INTO :result2;
    
    -- Step 3: Detect fraud signals
    CALL detect_fraud_signals() INTO :result3;
    
    RETURN 'Full analytics refresh completed. ' || :result1 || ' | ' || :result2 || ' | ' || :result3;
END;
$$;

-- ============================================================================
-- EXECUTE INITIAL ANALYTICS CALCULATION
-- ============================================================================

-- Run the full analytics pipeline
CALL run_full_analytics_refresh();

SELECT 'Risk analytics engine initialized successfully!' AS status;
