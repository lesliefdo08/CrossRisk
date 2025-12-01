-- ============================================================================
-- CrossRisk Platform - Dynamic Tables
-- ============================================================================
-- Creates dynamic tables that automatically refresh based on underlying
-- data changes, providing always-current analytics views.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA ANALYTICS;
USE WAREHOUSE CROSSRISK_ANALYTICS_WH;

-- ============================================================================
-- REAL-TIME RISK AGGREGATION DYNAMIC TABLE
-- ============================================================================

-- Dynamic table for real-time risk aggregations
-- Automatically refreshes when source data changes
CREATE OR REPLACE DYNAMIC TABLE dt_realtime_risk_aggregation
    TARGET_LAG = '5 minutes'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Real-time risk aggregations with automatic refresh'
AS
SELECT 
    MD5(CONCAT(b.age_group, b.region, COALESCE(b.occupation_category, 'UNKNOWN'))) AS analysis_id,
    b.age_group,
    b.region,
    b.occupation_category,
    COUNT(DISTINCT b.customer_id) AS record_count,
    AVG(b.risk_score) AS avg_bank_risk_score,
    AVG(i.risk_score) AS avg_insurance_risk_score,
    (AVG(b.risk_score) * 0.6 + AVG(i.risk_score) * 0.4 + 
     SUM(b.fraud_flag_history) * 5 + 
     SUM(i.suspicious_claim_flags) * 3) AS composite_risk_score,
    CASE
        WHEN (AVG(b.risk_score) * 0.6 + AVG(i.risk_score) * 0.4 + 
              SUM(b.fraud_flag_history) * 5 + 
              SUM(i.suspicious_claim_flags) * 3) >= 75 THEN 'CRITICAL'
        WHEN (AVG(b.risk_score) * 0.6 + AVG(i.risk_score) * 0.4 + 
              SUM(b.fraud_flag_history) * 5 + 
              SUM(i.suspicious_claim_flags) * 3) >= 50 THEN 'HIGH'
        WHEN (AVG(b.risk_score) * 0.6 + AVG(i.risk_score) * 0.4 + 
              SUM(b.fraud_flag_history) * 5 + 
              SUM(i.suspicious_claim_flags) * 3) >= 25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS risk_category,
    SUM(b.fraud_flag_history) AS total_fraud_flags,
    SUM(i.suspicious_claim_flags) AS total_claim_flags,
    CURRENT_TIMESTAMP() AS last_updated
FROM RAW_DATA.bank_customer_risk_summary b
INNER JOIN RAW_DATA.insurance_claim_risk_summary i
    ON b.customer_id = i.customer_id
GROUP BY b.age_group, b.region, b.occupation_category
HAVING COUNT(DISTINCT b.customer_id) >= 3;

-- ============================================================================
-- AGE GROUP STATISTICS DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_age_group_stats
    TARGET_LAG = '10 minutes'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Age group risk statistics with automatic updates'
AS
SELECT 
    age_group,
    COUNT(*) AS segment_count,
    SUM(record_count) AS total_customers,
    AVG(composite_risk_score) AS avg_risk_score,
    MIN(composite_risk_score) AS min_risk_score,
    MAX(composite_risk_score) AS max_risk_score,
    STDDEV(composite_risk_score) AS risk_stddev,
    SUM(CASE WHEN risk_category = 'CRITICAL' THEN record_count ELSE 0 END) AS critical_customers,
    SUM(CASE WHEN risk_category = 'HIGH' THEN record_count ELSE 0 END) AS high_customers,
    SUM(CASE WHEN risk_category = 'MEDIUM' THEN record_count ELSE 0 END) AS medium_customers,
    SUM(CASE WHEN risk_category = 'LOW' THEN record_count ELSE 0 END) AS low_customers,
    (SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / 
     SUM(record_count)) AS high_risk_percentage,
    CURRENT_TIMESTAMP() AS last_updated
FROM dt_realtime_risk_aggregation
GROUP BY age_group
HAVING SUM(record_count) >= 3;

-- ============================================================================
-- REGIONAL DASHBOARD METRICS DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_regional_metrics
    TARGET_LAG = '10 minutes'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Regional risk metrics for dashboard display'
AS
SELECT 
    region,
    COUNT(*) AS segment_count,
    SUM(record_count) AS total_customers,
    AVG(composite_risk_score) AS avg_risk_score,
    AVG(avg_bank_risk_score) AS avg_bank_risk,
    AVG(avg_insurance_risk_score) AS avg_insurance_risk,
    SUM(total_fraud_flags) AS total_fraud_flags,
    SUM(total_claim_flags) AS total_claim_flags,
    SUM(CASE WHEN risk_category = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_segments,
    SUM(CASE WHEN risk_category = 'HIGH' THEN 1 ELSE 0 END) AS high_segments,
    (SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / 
     SUM(record_count)) AS high_risk_percentage,
    CURRENT_TIMESTAMP() AS last_updated
FROM dt_realtime_risk_aggregation
GROUP BY region
HAVING SUM(record_count) >= 3;

-- ============================================================================
-- OCCUPATION RISK PROFILE DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_occupation_risk_profile
    TARGET_LAG = '15 minutes'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Occupation-based risk profiles'
AS
SELECT 
    occupation_category,
    COUNT(*) AS segment_count,
    SUM(record_count) AS total_customers,
    AVG(composite_risk_score) AS avg_risk_score,
    AVG(avg_bank_risk_score) AS avg_bank_risk,
    AVG(avg_insurance_risk_score) AS avg_insurance_risk,
    MAX(composite_risk_score) AS max_risk_score,
    (SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / 
     SUM(record_count)) AS high_risk_percentage,
    SUM(total_fraud_flags) AS fraud_indicator_count,
    RANK() OVER (ORDER BY AVG(composite_risk_score) DESC) AS risk_rank,
    CURRENT_TIMESTAMP() AS last_updated
FROM dt_realtime_risk_aggregation
WHERE occupation_category IS NOT NULL
GROUP BY occupation_category
HAVING SUM(record_count) >= 3;

-- ============================================================================
-- HIGH RISK SEGMENT TRACKER DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_high_risk_tracker
    TARGET_LAG = '5 minutes'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Tracks high and critical risk segments for immediate attention'
AS
SELECT 
    analysis_id,
    age_group,
    region,
    occupation_category,
    record_count AS customer_count,
    composite_risk_score,
    risk_category,
    avg_bank_risk_score,
    avg_insurance_risk_score,
    total_fraud_flags,
    total_claim_flags,
    CASE
        WHEN avg_bank_risk_score > avg_insurance_risk_score + 10 THEN 'Banking-driven'
        WHEN avg_insurance_risk_score > avg_bank_risk_score + 10 THEN 'Insurance-driven'
        ELSE 'Balanced'
    END AS risk_driver,
    CASE
        WHEN total_fraud_flags > 0 AND total_claim_flags > 0 THEN 'Cross-org fraud signals'
        WHEN total_fraud_flags > 0 THEN 'Banking fraud signals'
        WHEN total_claim_flags > 0 THEN 'Insurance fraud signals'
        ELSE 'High risk score'
    END AS primary_concern,
    last_updated
FROM dt_realtime_risk_aggregation
WHERE risk_category IN ('HIGH', 'CRITICAL')
ORDER BY composite_risk_score DESC;

-- ============================================================================
-- FRAUD CORRELATION TRACKER DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_fraud_correlation
    TARGET_LAG = '10 minutes'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Tracks fraud correlation patterns across organizations'
AS
SELECT 
    age_group,
    region,
    COUNT(*) AS segment_count,
    SUM(record_count) AS customer_count,
    AVG(composite_risk_score) AS avg_risk,
    SUM(total_fraud_flags) AS fraud_flags,
    SUM(total_claim_flags) AS claim_flags,
    CASE
        WHEN SUM(total_fraud_flags) > 0 AND SUM(total_claim_flags) > 0 THEN 'High correlation'
        WHEN SUM(total_fraud_flags) > 0 OR SUM(total_claim_flags) > 0 THEN 'Moderate correlation'
        ELSE 'Low correlation'
    END AS correlation_level,
    CASE
        WHEN SUM(total_fraud_flags) > 0 AND SUM(total_claim_flags) > 0 THEN 0.85
        WHEN SUM(total_fraud_flags) > 0 OR SUM(total_claim_flags) > 0 THEN 0.50
        ELSE 0.10
    END AS correlation_score,
    CURRENT_TIMESTAMP() AS last_updated
FROM dt_realtime_risk_aggregation
GROUP BY age_group, region
HAVING SUM(record_count) >= 3
   AND (SUM(total_fraud_flags) > 0 OR SUM(total_claim_flags) > 0);

-- ============================================================================
-- DAILY RISK SUMMARY DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_daily_summary
    TARGET_LAG = '1 hour'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Daily summary statistics for executive dashboard'
AS
SELECT 
    CURRENT_DATE() AS summary_date,
    COUNT(*) AS total_segments,
    SUM(record_count) AS total_customers,
    AVG(composite_risk_score) AS overall_avg_risk,
    MIN(composite_risk_score) AS min_risk,
    MAX(composite_risk_score) AS max_risk,
    STDDEV(composite_risk_score) AS risk_variance,
    SUM(CASE WHEN risk_category = 'CRITICAL' THEN record_count ELSE 0 END) AS critical_customers,
    SUM(CASE WHEN risk_category = 'HIGH' THEN record_count ELSE 0 END) AS high_customers,
    SUM(CASE WHEN risk_category = 'MEDIUM' THEN record_count ELSE 0 END) AS medium_customers,
    SUM(CASE WHEN risk_category = 'LOW' THEN record_count ELSE 0 END) AS low_customers,
    (SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / 
     SUM(record_count)) AS high_risk_percentage,
    SUM(total_fraud_flags) AS total_fraud_indicators,
    SUM(total_claim_flags) AS total_claim_indicators,
    COUNT(DISTINCT region) AS active_regions,
    COUNT(DISTINCT age_group) AS active_age_groups,
    CURRENT_TIMESTAMP() AS generated_at
FROM dt_realtime_risk_aggregation;

-- ============================================================================
-- TREND COMPARISON DYNAMIC TABLE
-- ============================================================================

CREATE OR REPLACE DYNAMIC TABLE dt_trend_comparison
    TARGET_LAG = '1 hour'
    WAREHOUSE = CROSSRISK_ANALYTICS_WH
    COMMENT = 'Compares current metrics with historical trends'
AS
SELECT 
    CURRENT_DATE() AS analysis_date,
    age_group,
    region,
    AVG(composite_risk_score) AS current_avg_risk,
    SUM(record_count) AS current_customer_count,
    COUNT(*) AS current_segment_count,
    LAG(AVG(composite_risk_score)) OVER (PARTITION BY age_group, region ORDER BY CURRENT_DATE()) AS previous_avg_risk,
    CASE
        WHEN LAG(AVG(composite_risk_score)) OVER (PARTITION BY age_group, region ORDER BY CURRENT_DATE()) IS NULL THEN 'NEW'
        WHEN AVG(composite_risk_score) > LAG(AVG(composite_risk_score)) OVER (PARTITION BY age_group, region ORDER BY CURRENT_DATE()) + 5 THEN 'INCREASING'
        WHEN AVG(composite_risk_score) < LAG(AVG(composite_risk_score)) OVER (PARTITION BY age_group, region ORDER BY CURRENT_DATE()) - 5 THEN 'DECREASING'
        ELSE 'STABLE'
    END AS trend_direction,
    CURRENT_TIMESTAMP() AS last_updated
FROM dt_realtime_risk_aggregation
GROUP BY age_group, region;

SELECT 'Dynamic tables created successfully! They will refresh automatically based on TARGET_LAG settings.' AS status;
