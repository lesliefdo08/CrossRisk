"""
Database connection handler with fallback support for offline mode.
Handles Snowflake connections and provides sample data when unavailable.
"""

import streamlit as st
import pandas as pd
import numpy as np
from typing import Optional
import os

# Sample data cache
_sample_data_cache = {}

def get_sample_risk_data() -> pd.DataFrame:
    """Generate realistic sample risk data for offline mode"""
    if 'risk_data' in _sample_data_cache:
        return _sample_data_cache['risk_data'].copy()
    
    np.random.seed(42)
    regions = ['Northeast', 'Southeast', 'Midwest', 'West']
    age_groups = ['18-24', '25-34', '35-44', '45-54', '55-64', '65+']
    occupations = ['Technology', 'Healthcare', 'Finance', 'Education', 'Manufacturing', 'Retail']
    risk_categories = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
    
    data = []
    for region in regions:
        for age_group in age_groups:
            for occupation in occupations:
                if np.random.random() > 0.6:  # Not all combinations exist
                    record_count = np.random.randint(3, 25)
                    bank_risk = np.random.uniform(15, 85)
                    insurance_risk = np.random.uniform(15, 85)
                    composite = (bank_risk * 0.6) + (insurance_risk * 0.4)
                    
                    if composite >= 75:
                        category = 'CRITICAL'
                    elif composite >= 50:
                        category = 'HIGH'
                    elif composite >= 25:
                        category = 'MEDIUM'
                    else:
                        category = 'LOW'
                    
                    data.append({
                        'ANALYSIS_ID': f'A{len(data)+1:04d}',
                        'AGE_GROUP': age_group,
                        'REGION': region,
                        'OCCUPATION_CATEGORY': occupation,
                        'RECORD_COUNT': record_count,
                        'AVG_BANK_RISK_SCORE': round(bank_risk, 2),
                        'AVG_INSURANCE_RISK_SCORE': round(insurance_risk, 2),
                        'COMPOSITE_RISK_SCORE': round(composite, 2),
                        'RISK_CATEGORY': category,
                        'FRAUD_CORRELATION_SCORE': round(np.random.uniform(0.05, 0.85), 2)
                    })
    
    df = pd.DataFrame(data)
    _sample_data_cache['risk_data'] = df
    return df.copy()

def get_sample_questions() -> pd.DataFrame:
    """Generate sample approved questions data"""
    if 'questions' in _sample_data_cache:
        return _sample_data_cache['questions'].copy()
    
    questions = pd.DataFrame([
        {
            'QUESTION_ID': 'Q001',
            'QUESTION_TEXT': 'What is the overall risk distribution across customer segments?',
            'CATEGORY': 'Risk Overview',
            'AI_SUMMARY': 'Analysis shows balanced risk distribution with 45% low-medium risk and 35% high-critical risk segments.',
            'LAST_REFRESHED': pd.Timestamp.now()
        },
        {
            'QUESTION_ID': 'Q002',
            'QUESTION_TEXT': 'Which age groups show the highest risk scores?',
            'CATEGORY': 'Age Analysis',
            'AI_SUMMARY': 'Age groups 45-54 and 55-64 demonstrate elevated risk profiles with average scores above 60.',
            'LAST_REFRESHED': pd.Timestamp.now()
        },
        {
            'QUESTION_ID': 'Q003',
            'QUESTION_TEXT': 'What are the regional risk hotspots?',
            'CATEGORY': 'Regional Analysis',
            'AI_SUMMARY': 'Southeast and Midwest regions show higher average risk scores compared to coastal regions.',
            'LAST_REFRESHED': pd.Timestamp.now()
        }
    ])
    
    _sample_data_cache['questions'] = questions
    return questions.copy()

def get_sample_fraud_signals() -> pd.DataFrame:
    """Generate sample fraud detection data"""
    if 'fraud' in _sample_data_cache:
        return _sample_data_cache['fraud'].copy()
    
    fraud_data = pd.DataFrame([
        {
            'SIGNAL_ID': 'FS001',
            'AGE_GROUP': '35-44',
            'REGION': 'Midwest',
            'PATTERN_DESCRIPTION': 'Elevated transaction velocity with simultaneous claim activity',
            'AFFECTED_CUSTOMER_COUNT': 12,
            'CONFIDENCE_SCORE': 0.87,
            'DETECTED_AT': pd.Timestamp.now() - pd.Timedelta(days=5)
        },
        {
            'SIGNAL_ID': 'FS002',
            'AGE_GROUP': '45-54',
            'REGION': 'Southeast',
            'PATTERN_DESCRIPTION': 'Unusual claim frequency pattern across insurance products',
            'AFFECTED_CUSTOMER_COUNT': 8,
            'CONFIDENCE_SCORE': 0.72,
            'DETECTED_AT': pd.Timestamp.now() - pd.Timedelta(days=12)
        }
    ])
    
    _sample_data_cache['fraud'] = fraud_data
    return fraud_data.copy()

def get_sample_compliance_log() -> pd.DataFrame:
    """Generate sample compliance log data"""
    if 'compliance' in _sample_data_cache:
        return _sample_data_cache['compliance'].copy()
    
    compliance = pd.DataFrame([
        {
            'COMPLIANCE_ID': 'C001',
            'CHECK_TYPE': 'K_ANONYMITY',
            'TABLE_NAME': 'risk_join_aggregated',
            'CHECK_RESULT': 'PASSED',
            'DETAILS': 'All segments meet k>=3 requirement',
            'CHECKED_AT': pd.Timestamp.now() - pd.Timedelta(hours=2)
        },
        {
            'COMPLIANCE_ID': 'C002',
            'CHECK_TYPE': 'DATA_QUALITY',
            'TABLE_NAME': 'bank_customer_risk_summary',
            'CHECK_RESULT': 'PASSED',
            'DETAILS': 'No data quality issues detected',
            'CHECKED_AT': pd.Timestamp.now() - pd.Timedelta(hours=4)
        },
        {
            'COMPLIANCE_ID': 'C003',
            'CHECK_TYPE': 'MASKING',
            'TABLE_NAME': 'insurance_claim_risk_summary',
            'CHECK_RESULT': 'PASSED',
            'DETAILS': 'All masking policies are active',
            'CHECKED_AT': pd.Timestamp.now() - pd.Timedelta(hours=6)
        }
    ])
    
    _sample_data_cache['compliance'] = compliance
    return compliance.copy()

class SnowflakeConnection:
    """Handle Snowflake connections with fallback to sample data"""
    
    def __init__(self):
        self._connection = None
        self._is_offline = False
        self._offline_message_shown = False
        self._initialize_connection()
    
    def _initialize_connection(self):
        """Try to establish Snowflake connection"""
        try:
            # Check if running in Streamlit in Snowflake
            self._connection = st.connection("snowflake")
            self._is_offline = False
        except Exception as e:
            # Fallback to sample data mode
            self._is_offline = True
            if not self._offline_message_shown:
                st.info("Running in offline mode with sample data. Configure Snowflake credentials in .streamlit/secrets.toml for live data.")
                self._offline_message_shown = True
    
    def query(self, sql: str, ttl: int = 300) -> pd.DataFrame:
        """Execute query with fallback to sample data"""
        if not self._is_offline and self._connection:
            try:
                return self._connection.query(sql, ttl=ttl)
            except Exception as e:
                st.warning(f"Query failed, using sample data: {str(e)[:100]}")
                return self._get_sample_data_for_query(sql)
        else:
            return self._get_sample_data_for_query(sql)
    
    def _get_sample_data_for_query(self, sql: str) -> pd.DataFrame:
        """Return appropriate sample data based on query pattern"""
        sql_lower = sql.lower()
        
        try:
            # Risk analysis queries
            if 'risk_join_aggregated' in sql_lower:
                df = get_sample_risk_data()
                
                # Apply basic filtering based on WHERE clauses
                if 'where' in sql_lower:
                    # Extract age group filter
                    if "age_group in" in sql_lower:
                        # Return filtered data (simplified)
                        pass
                    # Extract region filter
                    if "region in" in sql_lower:
                        pass
                
                # Apply basic aggregations
                if 'count(*)' in sql_lower and 'group by risk_category' in sql_lower:
                    return df.groupby('RISK_CATEGORY').agg({
                        'ANALYSIS_ID': 'count',
                        'RECORD_COUNT': 'sum'
                    }).reset_index().rename(columns={'ANALYSIS_ID': 'SEGMENT_COUNT', 'RECORD_COUNT': 'CUSTOMER_COUNT'})
                
                if 'group by age_group' in sql_lower:
                    return df.groupby('AGE_GROUP').agg({
                        'RECORD_COUNT': 'sum',
                        'COMPOSITE_RISK_SCORE': 'mean'
                    }).reset_index().rename(columns={'RECORD_COUNT': 'TOTAL_CUSTOMERS', 'COMPOSITE_RISK_SCORE': 'AVG_RISK_SCORE'})
                
                if 'group by region' in sql_lower:
                    return df.groupby('REGION').agg({
                        'RECORD_COUNT': 'sum',
                        'COMPOSITE_RISK_SCORE': 'mean'
                    }).reset_index().rename(columns={'RECORD_COUNT': 'CUSTOMER_COUNT', 'COMPOSITE_RISK_SCORE': 'AVG_RISK'})
                
                # Summary statistics
                if 'count(*)' in sql_lower and 'sum(record_count)' in sql_lower:
                    return pd.DataFrame([{
                        'TOTAL_SEGMENTS': len(df),
                        'TOTAL_CUSTOMERS': df['RECORD_COUNT'].sum(),
                        'AVG_RISK': df['COMPOSITE_RISK_SCORE'].mean(),
                        'HIGH_RISK_COUNT': df[df['RISK_CATEGORY'].isin(['HIGH', 'CRITICAL'])]['RECORD_COUNT'].sum()
                    }])
                
                return df
            
            # Approved questions queries
            elif 'approved_questions_cache' in sql_lower:
                return get_sample_questions()
            
            # Fraud detection queries
            elif 'fraud_cross_signals' in sql_lower:
                return get_sample_fraud_signals()
            
            # Compliance queries
            elif 'privacy_compliance_log' in sql_lower:
                return get_sample_compliance_log()
            
            # AI explanation queries
            elif 'explain_risk_anomaly' in sql_lower or 'ai_insights' in sql_lower:
                return pd.DataFrame([{
                    'EXPLANATION': 'This segment shows elevated risk patterns driven by higher-than-average transaction velocity and claim frequency. The composite risk score reflects both banking and insurance risk factors.',
                    'AI_SUMMARY': 'Risk analysis indicates moderate correlation between banking and insurance risk signals in this demographic segment.'
                }])
            
            # Default empty result
            else:
                return pd.DataFrame()
        
        except Exception as e:
            st.error(f"Error processing sample data: {str(e)}")
            return pd.DataFrame()
    
    @property
    def is_offline(self) -> bool:
        """Check if running in offline mode"""
        return self._is_offline

# Global connection instance
_global_connection = None

@st.cache_resource
def get_snowflake_connection() -> SnowflakeConnection:
    """Get cached Snowflake connection instance"""
    global _global_connection
    if _global_connection is None:
        _global_connection = SnowflakeConnection()
    return _global_connection

@st.cache_data(ttl=300)
def run_query(query: str) -> pd.DataFrame:
    """Execute query with caching and error handling"""
    try:
        conn = get_snowflake_connection()
        df = conn.query(query)
        
        if df is None or (isinstance(df, pd.DataFrame) and df.empty):
            return pd.DataFrame()
        
        return df
    
    except Exception as e:
        st.error(f"Query execution failed: {str(e)[:200]}")
        return pd.DataFrame()

def is_offline_mode() -> bool:
    """Check if application is running in offline mode"""
    conn = get_snowflake_connection()
    return conn.is_offline
