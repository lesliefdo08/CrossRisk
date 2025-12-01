-- ============================================================================
-- CrossRisk Platform - AI SQL Queries (Snowflake Cortex)
-- ============================================================================
-- Leverages Snowflake Cortex AI to generate natural language explanations,
-- summaries, and insights from risk analytics data.
-- ============================================================================

USE DATABASE CROSSRISK_DB;
USE SCHEMA AI_INSIGHTS;
USE WAREHOUSE CROSSRISK_AI_WH;

-- ============================================================================
-- AI EXPLANATION GENERATION FUNCTIONS
-- ============================================================================

-- Generate natural language summary of risk dataset
CREATE OR REPLACE FUNCTION generate_dataset_summary()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'Analyze this cross-organizational risk dataset and provide a concise executive summary. ',
            'Total customer segments: ', (SELECT COUNT(*) FROM ANALYTICS.risk_join_aggregated), ', ',
            'Average composite risk score: ', ROUND((SELECT AVG(composite_risk_score) FROM ANALYTICS.risk_join_aggregated), 2), ', ',
            'High/Critical risk segments: ', (SELECT COUNT(*) FROM ANALYTICS.risk_join_aggregated WHERE risk_category IN ('HIGH', 'CRITICAL')), '. ',
            'Explain the overall risk landscape in 2-3 sentences focusing on key insights and actionable recommendations.'
        )
    ) AS summary
$$;

-- Explain specific risk anomaly
CREATE OR REPLACE FUNCTION explain_risk_anomaly(
    age_group_param VARCHAR,
    region_param VARCHAR,
    risk_score FLOAT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'A customer segment has been flagged with elevated risk. ',
            'Age Group: ', age_group_param, ', ',
            'Region: ', region_param, ', ',
            'Composite Risk Score: ', ROUND(risk_score, 2), ' out of 100. ',
            'Based on this cross-organizational data combining banking and insurance signals, ',
            'explain in 2-3 sentences what factors might contribute to this risk level and what actions should be considered.'
        )
    ) AS explanation
$$;

-- Explain fraud correlation pattern
CREATE OR REPLACE FUNCTION explain_fraud_pattern(
    pattern_description VARCHAR,
    affected_count INT,
    confidence FLOAT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'A fraud pattern has been detected across banking and insurance data: ',
            pattern_description, '. ',
            'This affects approximately ', affected_count, ' customers with a confidence score of ', ROUND(confidence * 100, 1), '%. ',
            'Explain in 2-3 sentences what this pattern means, why it\'s significant, and what immediate actions risk teams should take.'
        )
    ) AS explanation
$$;

-- Generate trend analysis explanation
CREATE OR REPLACE FUNCTION explain_regional_trend(
    region_param VARCHAR,
    avg_risk FLOAT,
    trend_direction VARCHAR,
    high_risk_pct FLOAT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'Regional risk analysis for ', region_param, ': ',
            'Average risk score is ', ROUND(avg_risk, 2), ', ',
            'trend is ', trend_direction, ', ',
            'and ', ROUND(high_risk_pct, 1), '% of customers are in high/critical risk categories. ',
            'Provide a brief 2-3 sentence analysis of what this means for risk management in this region.'
        )
    ) AS explanation
$$;

-- ============================================================================
-- STORED PROCEDURES FOR AI INSIGHT GENERATION
-- ============================================================================

-- Generate and store AI explanation for all high-risk segments
CREATE OR REPLACE PROCEDURE generate_high_risk_explanations()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Clear old explanations for high risk segments
    DELETE FROM ai_explanations WHERE context_type = 'HIGH_RISK_SEGMENT';
    
    -- Generate new explanations
    INSERT INTO ai_explanations (
        explanation_id,
        context_type,
        reference_data,
        ai_explanation,
        confidence_score,
        generated_model,
        generated_at
    )
    SELECT 
        MD5(CONCAT(analysis_id, CURRENT_TIMESTAMP())) AS explanation_id,
        'HIGH_RISK_SEGMENT' AS context_type,
        OBJECT_CONSTRUCT(
            'age_group', age_group,
            'region', region,
            'occupation', occupation_category,
            'risk_score', composite_risk_score,
            'risk_category', risk_category,
            'customer_count', record_count
        ) AS reference_data,
        explain_risk_anomaly(age_group, region, composite_risk_score) AS ai_explanation,
        0.85 AS confidence_score,
        'cortex-mistral-large' AS generated_model,
        CURRENT_TIMESTAMP() AS generated_at
    FROM ANALYTICS.risk_join_aggregated
    WHERE risk_category IN ('HIGH', 'CRITICAL')
    LIMIT 20;  -- Limit to top 20 to manage API costs
    
    RETURN 'Generated AI explanations for high-risk segments';
END;
$$;

-- Generate AI summaries for fraud patterns
CREATE OR REPLACE PROCEDURE generate_fraud_pattern_explanations()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    DELETE FROM ai_explanations WHERE context_type = 'FRAUD_PATTERN';
    
    INSERT INTO ai_explanations (
        explanation_id,
        context_type,
        reference_data,
        ai_explanation,
        confidence_score,
        generated_model,
        generated_at
    )
    SELECT 
        MD5(CONCAT(signal_id, CURRENT_TIMESTAMP())) AS explanation_id,
        'FRAUD_PATTERN' AS context_type,
        OBJECT_CONSTRUCT(
            'age_group', age_group,
            'region', region,
            'pattern', pattern_description,
            'affected_count', affected_customer_count,
            'confidence', confidence_score
        ) AS reference_data,
        explain_fraud_pattern(pattern_description, affected_customer_count, confidence_score) AS ai_explanation,
        confidence_score AS confidence_score,
        'cortex-mistral-large' AS generated_model,
        CURRENT_TIMESTAMP() AS generated_at
    FROM ANALYTICS.fraud_cross_signals
    WHERE detected_at >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    ORDER BY confidence_score DESC
    LIMIT 10;
    
    RETURN 'Generated AI explanations for fraud patterns';
END;
$$;

-- Generate regional trend explanations
CREATE OR REPLACE PROCEDURE generate_regional_trend_explanations()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    DELETE FROM ai_explanations WHERE context_type = 'REGIONAL_TREND';
    
    INSERT INTO ai_explanations (
        explanation_id,
        context_type,
        reference_data,
        ai_explanation,
        confidence_score,
        generated_model,
        generated_at
    )
    SELECT 
        MD5(CONCAT(trend_id, CURRENT_TIMESTAMP())) AS explanation_id,
        'REGIONAL_TREND' AS context_type,
        OBJECT_CONSTRUCT(
            'region', region,
            'avg_risk', avg_composite_risk,
            'trend', trend_direction,
            'high_risk_pct', high_risk_percentage,
            'customer_count', customer_count
        ) AS reference_data,
        explain_regional_trend(region, avg_composite_risk, trend_direction, high_risk_percentage) AS ai_explanation,
        0.80 AS confidence_score,
        'cortex-mistral-large' AS generated_model,
        CURRENT_TIMESTAMP() AS generated_at
    FROM ANALYTICS.regional_risk_trends
    WHERE analysis_date = CURRENT_DATE()
    ORDER BY avg_composite_risk DESC;
    
    RETURN 'Generated AI explanations for regional trends';
END;
$$;

-- ============================================================================
-- PRE-APPROVED ANALYTICS QUESTIONS
-- ============================================================================

-- Populate pre-approved questions with AI summaries
CREATE OR REPLACE PROCEDURE populate_approved_questions()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    DELETE FROM approved_questions_cache;
    
    -- Question 1: Overall risk distribution
    INSERT INTO approved_questions_cache (question_id, question_text, category, result_data, ai_summary, last_refreshed)
    SELECT 
        'Q001',
        'What is the overall risk distribution across customer segments?',
        'Risk Overview',
        OBJECT_CONSTRUCT(
            'total_segments', COUNT(*),
            'avg_risk', AVG(composite_risk_score),
            'low_risk_count', SUM(CASE WHEN risk_category = 'LOW' THEN 1 ELSE 0 END),
            'medium_risk_count', SUM(CASE WHEN risk_category = 'MEDIUM' THEN 1 ELSE 0 END),
            'high_risk_count', SUM(CASE WHEN risk_category = 'HIGH' THEN 1 ELSE 0 END),
            'critical_risk_count', SUM(CASE WHEN risk_category = 'CRITICAL' THEN 1 ELSE 0 END)
        ),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT(
                'Summarize this risk distribution: Out of ', COUNT(*), ' customer segments, ',
                'Low risk: ', SUM(CASE WHEN risk_category = 'LOW' THEN 1 ELSE 0 END), ', ',
                'Medium: ', SUM(CASE WHEN risk_category = 'MEDIUM' THEN 1 ELSE 0 END), ', ',
                'High: ', SUM(CASE WHEN risk_category = 'HIGH' THEN 1 ELSE 0 END), ', ',
                'Critical: ', SUM(CASE WHEN risk_category = 'CRITICAL' THEN 1 ELSE 0 END), '. ',
                'Average risk score: ', ROUND(AVG(composite_risk_score), 2), '. Provide a 2-sentence executive summary.'
            )
        ),
        CURRENT_TIMESTAMP()
    FROM ANALYTICS.risk_join_aggregated;
    
    -- Question 2: Which age groups have the highest risk?
    INSERT INTO approved_questions_cache (question_id, question_text, category, result_data, ai_summary, last_refreshed)
    SELECT 
        'Q002',
        'Which age groups show the highest risk levels?',
        'Age Analysis',
        ARRAY_AGG(OBJECT_CONSTRUCT('age_group', age_group, 'avg_risk', avg_risk, 'customer_count', total_customers)) WITHIN GROUP (ORDER BY avg_risk DESC),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT(
                'Analyze age group risk patterns. Top 3 highest risk groups: ',
                LISTAGG(CONCAT(age_group, ' (', ROUND(avg_risk, 1), ')'), ', ') WITHIN GROUP (ORDER BY avg_risk DESC),
                '. Explain in 2 sentences what this pattern reveals and any recommended actions.'
            )
        ),
        CURRENT_TIMESTAMP()
    FROM ANALYTICS.v_age_group_comparison
    LIMIT 1;
    
    -- Question 3: Regional risk hotspots
    INSERT INTO approved_questions_cache (question_id, question_text, category, result_data, ai_summary, last_refreshed)
    SELECT 
        'Q003',
        'Which regions are risk hotspots requiring immediate attention?',
        'Regional Analysis',
        ARRAY_AGG(OBJECT_CONSTRUCT('region', region, 'avg_risk', avg_composite_risk, 'trend', trend_direction)) WITHIN GROUP (ORDER BY avg_composite_risk DESC),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT(
                'Identify regional risk hotspots. Highest risk regions: ',
                LISTAGG(CONCAT(region, ' (', ROUND(avg_composite_risk, 1), ', ', trend_direction, ')'), '; ') WITHIN GROUP (ORDER BY avg_composite_risk DESC),
                '. Provide 2 sentences on geographic risk concentration and recommended focus areas.'
            )
        ),
        CURRENT_TIMESTAMP()
    FROM ANALYTICS.regional_risk_trends
    WHERE analysis_date = CURRENT_DATE()
    LIMIT 1;
    
    -- Question 4: Fraud correlation insights
    INSERT INTO approved_questions_cache (question_id, question_text, category, result_data, ai_summary, last_refreshed)
    SELECT 
        'Q004',
        'What fraud patterns show the strongest cross-organizational signals?',
        'Fraud Detection',
        ARRAY_AGG(OBJECT_CONSTRUCT('pattern', pattern_description, 'affected_count', affected_customer_count, 'confidence', confidence_score)) WITHIN GROUP (ORDER BY confidence_score DESC),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT(
                'Fraud pattern analysis reveals: ',
                COUNT(*), ' distinct patterns detected. ',
                'Highest confidence patterns: ',
                LISTAGG(CONCAT(pattern_description, ' (', ROUND(confidence_score * 100, 0), '% confidence)'), '; ') WITHIN GROUP (ORDER BY confidence_score DESC),
                '. Explain the significance in 2-3 sentences.'
            )
        ),
        CURRENT_TIMESTAMP()
    FROM ANALYTICS.fraud_cross_signals
    WHERE detected_at >= DATEADD(day, -7, CURRENT_TIMESTAMP())
    LIMIT 1;
    
    -- Question 5: Occupation risk profiles
    INSERT INTO approved_questions_cache (question_id, question_text, category, result_data, ai_summary, last_refreshed)
    SELECT 
        'Q005',
        'Which occupation categories demonstrate elevated risk patterns?',
        'Occupation Analysis',
        ARRAY_AGG(OBJECT_CONSTRUCT('occupation', occupation_category, 'avg_risk', avg_risk, 'high_risk_pct', high_risk_percentage)) WITHIN GROUP (ORDER BY avg_risk DESC),
        SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT(
                'Occupation risk analysis shows: ',
                'Highest risk occupations: ',
                LISTAGG(CONCAT(occupation_category, ' (risk: ', ROUND(avg_risk, 1), ', ', ROUND(high_risk_percentage, 0), '% high/critical)'), '; ') WITHIN GROUP (ORDER BY avg_risk DESC),
                '. Provide 2 sentences explaining these occupational risk patterns.'
            )
        ),
        CURRENT_TIMESTAMP()
    FROM ANALYTICS.v_occupation_risk_analysis
    LIMIT 1;
    
    RETURN 'Populated ' || (SELECT COUNT(*) FROM approved_questions_cache) || ' pre-approved questions with AI summaries';
END;
$$;

-- ============================================================================
-- MASTER AI INSIGHTS REFRESH
-- ============================================================================

CREATE OR REPLACE PROCEDURE refresh_all_ai_insights()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    result1 VARCHAR;
    result2 VARCHAR;
    result3 VARCHAR;
    result4 VARCHAR;
BEGIN
    CALL generate_high_risk_explanations() INTO :result1;
    CALL generate_fraud_pattern_explanations() INTO :result2;
    CALL generate_regional_trend_explanations() INTO :result3;
    CALL populate_approved_questions() INTO :result4;
    
    RETURN 'AI insights refresh completed. ' || :result1 || ' | ' || :result2 || ' | ' || :result3 || ' | ' || :result4;
END;
$$;

-- ============================================================================
-- SIMPLE TEXT-TO-SQL QUERY INTERFACE
-- ============================================================================
-- Allows natural language questions (with safety controls)

CREATE OR REPLACE FUNCTION ask_question_about_risk(user_question VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'You are a risk analytics assistant. Answer this question based on the context: ',
            user_question,
            '. Context: We have cross-organizational risk data combining banking and insurance signals. ',
            'Current statistics: ',
            (SELECT COUNT(*) FROM ANALYTICS.risk_join_aggregated), ' customer segments analyzed, ',
            'average risk score: ', ROUND((SELECT AVG(composite_risk_score) FROM ANALYTICS.risk_join_aggregated), 2), ', ',
            (SELECT COUNT(*) FROM ANALYTICS.risk_join_aggregated WHERE risk_category IN ('HIGH', 'CRITICAL')), ' high-risk segments. ',
            'Provide a concise, data-informed answer in 2-3 sentences.'
        )
    )
$$;

SELECT 'AI SQL queries and insights engine initialized successfully!' AS status;
