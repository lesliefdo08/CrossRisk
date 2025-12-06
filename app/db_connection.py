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

def get_sample_bank_data() -> pd.DataFrame:
    """Generate sample bank customer data"""
    if 'bank_raw' in _sample_data_cache:
        return _sample_data_cache['bank_raw'].copy()
    
    np.random.seed(42)
    n_records = 100
    
    data = []
    for i in range(n_records):
        data.append({
            'CUSTOMER_ID': f'CUST_{i+1:05d}',
            'AGE_GROUP': np.random.choice(['18-24', '25-34', '35-44', '45-54', '55-64', '65+']),
            'REGION': np.random.choice(['Northeast', 'Southeast', 'Midwest', 'West']),
            'RISK_SCORE': round(np.random.uniform(15, 85), 2),
            'FRAUD_FLAG_HISTORY': np.random.randint(0, 3)
        })
    
    df = pd.DataFrame(data)
    _sample_data_cache['bank_raw'] = df
    return df.copy()

def get_sample_insurance_data() -> pd.DataFrame:
    """Generate sample insurance claim data"""
    if 'insurance_raw' in _sample_data_cache:
        return _sample_data_cache['insurance_raw'].copy()
    
    np.random.seed(43)
    n_records = 100
    
    data = []
    for i in range(n_records):
        data.append({
            'CUSTOMER_ID': f'CUST_{i+1:05d}',
            'AGE_GROUP': np.random.choice(['18-24', '25-34', '35-44', '45-54', '55-64', '65+']),
            'REGION': np.random.choice(['Northeast', 'Southeast', 'Midwest', 'West']),
            'RISK_SCORE': round(np.random.uniform(15, 85), 2),
            'SUSPICIOUS_CLAIM_FLAGS': np.random.randint(0, 3)
        })
    
    df = pd.DataFrame(data)
    _sample_data_cache['insurance_raw'] = df
    return df.copy()

def get_sample_correlation_data() -> pd.DataFrame:
    """Generate sample correlation data for bank and insurance"""
    if 'correlation' in _sample_data_cache:
        return _sample_data_cache['correlation'].copy()
    
    np.random.seed(44)
    n_records = 80
    
    data = []
    for i in range(n_records):
        age_group = np.random.choice(['18-24', '25-34', '35-44', '45-54', '55-64', '65+'])
        region = np.random.choice(['Northeast', 'Southeast', 'Midwest', 'West'])
        data.append({
            'AGE_GROUP': age_group,
            'REGION': region,
            'BANK_RISK': round(np.random.uniform(20, 80), 2),
            'INSURANCE_RISK': round(np.random.uniform(20, 80), 2),
            'FRAUD_FLAG_HISTORY': np.random.randint(0, 2),
            'SUSPICIOUS_CLAIM_FLAGS': np.random.randint(0, 2)
        })
    
    df = pd.DataFrame(data)
    _sample_data_cache['correlation'] = df
    return df.copy()

def get_sample_composite_risk_data() -> pd.DataFrame:
    """Generate sample composite risk data"""
    if 'composite_risk' in _sample_data_cache:
        return _sample_data_cache['composite_risk'].copy()
    
    np.random.seed(45)
    
    risk_categories = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
    risk_drivers = ['Bank-Driven', 'Insurance-Driven', 'Balanced']
    
    data = []
    for category in risk_categories:
        for driver in risk_drivers:
            data.append({
                'COMPOSITE_RISK_CATEGORY': category,
                'RISK_DRIVER': driver,
                'SEGMENT_COUNT': np.random.randint(5, 30),
                'CUSTOMER_COUNT': np.random.randint(50, 500)
            })
    
    df = pd.DataFrame(data)
    _sample_data_cache['composite_risk'] = df
    return df.copy()

def get_sample_access_audit_data() -> pd.DataFrame:
    """Generate sample access audit log data"""
    if 'access_audit' in _sample_data_cache:
        return _sample_data_cache['access_audit'].copy()
    
    data = []
    users = ['john.doe', 'jane.smith', 'bob.johnson']
    roles = ['ANALYST', 'RISK_ANALYST', 'RISK_MANAGER']
    
    for i in range(20):
        data.append({
            'AUDIT_ID': f'A{i+1:04d}',
            'USER_NAME': np.random.choice(users),
            'ROLE_NAME': np.random.choice(roles),
            'QUERY_TYPE': 'SELECT',
            'QUERY_TEXT': 'SELECT * FROM analytics.risk_join_aggregated WHERE...',
            'ROW_COUNT': np.random.randint(10, 500),
            'EXECUTED_AT': pd.Timestamp.now() - pd.Timedelta(hours=np.random.randint(1, 72))
        })
    
    df = pd.DataFrame(data)
    _sample_data_cache['access_audit'] = df
    return df.copy()

def get_sample_user_access_summary() -> pd.DataFrame:
    """Generate sample user access summary"""
    if 'user_access' in _sample_data_cache:
        return _sample_data_cache['user_access'].copy()
    
    data = [
        {
            'USER_NAME': 'john.doe',
            'ROLE_NAME': 'ANALYST',
            'QUERY_COUNT': 45,
            'ROWS_ACCESSED': 12500,
            'FIRST_ACCESS': pd.Timestamp.now() - pd.Timedelta(days=30),
            'LAST_ACCESS': pd.Timestamp.now() - pd.Timedelta(hours=2)
        },
        {
            'USER_NAME': 'jane.smith',
            'ROLE_NAME': 'RISK_ANALYST',
            'QUERY_COUNT': 67,
            'ROWS_ACCESSED': 23400,
            'FIRST_ACCESS': pd.Timestamp.now() - pd.Timedelta(days=25),
            'LAST_ACCESS': pd.Timestamp.now() - pd.Timedelta(hours=1)
        },
        {
            'USER_NAME': 'bob.johnson',
            'ROLE_NAME': 'RISK_MANAGER',
            'QUERY_COUNT': 28,
            'ROWS_ACCESSED': 8900,
            'FIRST_ACCESS': pd.Timestamp.now() - pd.Timedelta(days=20),
            'LAST_ACCESS': pd.Timestamp.now() - pd.Timedelta(hours=5)
        }
    ]
    
    df = pd.DataFrame(data)
    _sample_data_cache['user_access'] = df
    return df.copy()

def get_sample_timeline_data() -> pd.DataFrame:
    """Generate sample access timeline data"""
    if 'timeline' in _sample_data_cache:
        return _sample_data_cache['timeline'].copy()
    
    data = []
    for i in range(30):
        data.append({
            'ACCESS_DATE': (pd.Timestamp.now() - pd.Timedelta(days=30-i)).date(),
            'QUERY_COUNT': np.random.randint(50, 200),
            'UNIQUE_USERS': np.random.randint(3, 8),
            'ROWS_ACCESSED': np.random.randint(5000, 25000)
        })
    
    df = pd.DataFrame(data)
    _sample_data_cache['timeline'] = df
    return df.copy()

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
            # SPECIAL CASE: Age group queries with risk category counts (Pre-Approved Questions)
            if 'group by age_group' in sql_lower and 'critical_count' in sql_lower and 'risk_join_aggregated' in sql_lower:
                df = get_sample_risk_data()
                result = df.groupby('AGE_GROUP').agg({
                    'RECORD_COUNT': 'sum',
                    'COMPOSITE_RISK_SCORE': 'mean'
                }).reset_index()
                result.columns = ['AGE_GROUP', 'TOTAL_CUSTOMERS', 'AVG_RISK']
                result['AVG_RISK'] = result['AVG_RISK'].round(2)
                
                # Add risk category counts
                result['CRITICAL_COUNT'] = 0
                result['HIGH_COUNT'] = 0
                result['MEDIUM_COUNT'] = 0
                result['LOW_COUNT'] = 0
                
                for age_group in result['AGE_GROUP'].unique():
                    age_mask = df['AGE_GROUP'] == age_group
                    result.loc[result['AGE_GROUP'] == age_group, 'CRITICAL_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'CRITICAL')]['RECORD_COUNT'].sum())
                    result.loc[result['AGE_GROUP'] == age_group, 'HIGH_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'HIGH')]['RECORD_COUNT'].sum())
                    result.loc[result['AGE_GROUP'] == age_group, 'MEDIUM_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'MEDIUM')]['RECORD_COUNT'].sum())
                    result.loc[result['AGE_GROUP'] == age_group, 'LOW_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'LOW')]['RECORD_COUNT'].sum())
                
                return result
            
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
                    result = df.groupby('RISK_CATEGORY').agg({
                        'ANALYSIS_ID': 'count',
                        'RECORD_COUNT': 'sum',
                        'COMPOSITE_RISK_SCORE': 'mean'
                    }).reset_index()
                    result.columns = ['RISK_CATEGORY', 'SEGMENT_COUNT', 'CUSTOMER_COUNT', 'AVG_RISK_SCORE']
                    result['AVG_RISK_SCORE'] = result['AVG_RISK_SCORE'].round(2)
                    return result
                
                if 'group by age_group' in sql_lower:
                    # Base aggregation
                    result = df.groupby('AGE_GROUP').agg({
                        'RECORD_COUNT': 'sum',
                        'COMPOSITE_RISK_SCORE': 'mean'
                    }).reset_index()
                    
                    # Check what columns the query expects based on the SELECT statement
                    if 'avg_risk_score' in sql_lower and 'customer_count' in sql_lower:
                        # Home page query: expects AVG_RISK_SCORE and CUSTOMER_COUNT
                        result.columns = ['AGE_GROUP', 'CUSTOMER_COUNT', 'AVG_RISK_SCORE']
                        result['AVG_RISK_SCORE'] = result['AVG_RISK_SCORE'].round(2)
                    else:
                        # Pre-Approved Questions query: expects TOTAL_CUSTOMERS and AVG_RISK
                        result.columns = ['AGE_GROUP', 'TOTAL_CUSTOMERS', 'AVG_RISK']
                        result['AVG_RISK'] = result['AVG_RISK'].round(2)
                        
                        # Add risk category counts for Pre-Approved Questions
                        result['CRITICAL_COUNT'] = 0
                        result['HIGH_COUNT'] = 0
                        result['MEDIUM_COUNT'] = 0
                        result['LOW_COUNT'] = 0
                        
                        for age_group in result['AGE_GROUP'].unique():
                            age_mask = df['AGE_GROUP'] == age_group
                            result.loc[result['AGE_GROUP'] == age_group, 'CRITICAL_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'CRITICAL')]['RECORD_COUNT'].sum())
                            result.loc[result['AGE_GROUP'] == age_group, 'HIGH_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'HIGH')]['RECORD_COUNT'].sum())
                            result.loc[result['AGE_GROUP'] == age_group, 'MEDIUM_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'MEDIUM')]['RECORD_COUNT'].sum())
                            result.loc[result['AGE_GROUP'] == age_group, 'LOW_COUNT'] = int(df[age_mask & (df['RISK_CATEGORY'] == 'LOW')]['RECORD_COUNT'].sum())
                    
                    return result
                
                if 'group by region' in sql_lower:
                    agg_dict = {
                        'RECORD_COUNT': 'sum',
                        'COMPOSITE_RISK_SCORE': 'mean'
                    }
                    result = df.groupby('REGION').agg(agg_dict).reset_index()
                    # Check what columns the query expects
                    if 'count(*)' in sql_lower:
                        result['SEGMENT_COUNT'] = df.groupby('REGION').size().values
                        result.columns = ['REGION', 'CUSTOMER_COUNT', 'AVG_RISK', 'SEGMENT_COUNT']
                        result['AVG_RISK'] = result['AVG_RISK'].round(2)
                    else:
                        result.columns = ['REGION', 'CUSTOMER_COUNT', 'AVG_RISK']
                        result['AVG_RISK'] = result['AVG_RISK'].round(2)
                    return result
                
                # Composite risk query with CASE statements and GROUP BY
                if 'case' in sql_lower and 'composite_risk_score >=' in sql_lower and 'group by composite_risk_category' in sql_lower:
                    # Return composite risk data
                    return get_sample_composite_risk_data()
                
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
                df = get_sample_compliance_log()
                # Check if grouping is needed
                if 'group by' in sql_lower and 'check_type' in sql_lower:
                    result = df.groupby(['CHECK_TYPE', 'CHECK_RESULT']).size().reset_index(name='CHECK_COUNT')
                    result['LAST_CHECK'] = df['CHECKED_AT'].max()
                    return result
                return df
            
            # Regional comparison queries (check FIRST - most specific)
            elif 'b.region = i.region' in sql_lower and 'group by region' in sql_lower:
                # This is a join query for regional comparison
                regions = ['Northeast', 'Southeast', 'Midwest', 'West']
                data = []
                for region in regions:
                    bank_risk = round(np.random.uniform(45, 75), 2)
                    insurance_risk = round(np.random.uniform(45, 75), 2)
                    data.append({
                        'REGION': region,
                        'BANK_AVG_RISK': bank_risk,
                        'INSURANCE_AVG_RISK': insurance_risk,
                        'CUSTOMER_COUNT': np.random.randint(50, 200),
                        'RISK_DIFFERENCE': round(bank_risk - insurance_risk, 2)
                    })
                return pd.DataFrame(data)
            
            # Age group comparison queries (check SECOND - specific)
            elif 'b.age_group = i.age_group' in sql_lower and 'group by age_group' in sql_lower:
                age_groups = ['18-24', '25-34', '35-44', '45-54', '55-64', '65+']
                data = []
                for age in age_groups:
                    bank_risk = round(np.random.uniform(40, 80), 2)
                    insurance_risk = round(np.random.uniform(40, 80), 2)
                    data.append({
                        'AGE_GROUP': age,
                        'BANK_AVG_RISK': bank_risk,
                        'INSURANCE_AVG_RISK': insurance_risk,
                        'CUSTOMER_COUNT': np.random.randint(30, 150),
                        'RISK_GAP': round(abs(bank_risk - insurance_risk), 2)
                    })
                return pd.DataFrame(data)
            
            # Correlation queries (check THIRD - after more specific JOIN patterns)
            elif 'b.customer_id = i.customer_id' in sql_lower or ('bank_risk' in sql_lower and 'insurance_risk' in sql_lower):
                return get_sample_correlation_data()
            
            # Bank and Insurance UNION queries (overview comparison)
            elif 'union all' in sql_lower and 'bank_customer_risk_summary' in sql_lower and 'insurance_claim_risk_summary' in sql_lower:
                bank_df = get_sample_bank_data()
                insurance_df = get_sample_insurance_data()
                
                bank_stats = {
                    'ORGANIZATION': 'Bank',
                    'RECORD_COUNT': len(bank_df),
                    'AVG_RISK_SCORE': round(bank_df['RISK_SCORE'].mean(), 2),
                    'MIN_RISK': round(bank_df['RISK_SCORE'].min(), 2),
                    'MAX_RISK': round(bank_df['RISK_SCORE'].max(), 2),
                    'RISK_STDDEV': round(bank_df['RISK_SCORE'].std(), 2)
                }
                
                insurance_stats = {
                    'ORGANIZATION': 'Insurance',
                    'RECORD_COUNT': len(insurance_df),
                    'AVG_RISK_SCORE': round(insurance_df['RISK_SCORE'].mean(), 2),
                    'MIN_RISK': round(insurance_df['RISK_SCORE'].min(), 2),
                    'MAX_RISK': round(insurance_df['RISK_SCORE'].max(), 2),
                    'RISK_STDDEV': round(insurance_df['RISK_SCORE'].std(), 2)
                }
                
                return pd.DataFrame([bank_stats, insurance_stats])
            
            # Bank raw data queries
            elif 'bank_customer_risk_summary' in sql_lower:
                return get_sample_bank_data()
            
            # Insurance raw data queries
            elif 'insurance_claim_risk_summary' in sql_lower:
                return get_sample_insurance_data()
            
            # Composite risk queries
            elif 'composite_risk_category' in sql_lower or 'risk_driver' in sql_lower:
                return get_sample_composite_risk_data()
            
            # Access audit log queries
            elif 'access_audit_log' in sql_lower:
                df = get_sample_access_audit_data()
                # Handle timeline grouping FIRST (most specific with DATE and GROUP BY)
                if 'date(executed_at)' in sql_lower and 'group by' in sql_lower:
                    return get_sample_timeline_data()
                # Handle user grouping
                elif 'group by user_name' in sql_lower:
                    return get_sample_user_access_summary()
                # Handle summary queries (no GROUP BY)
                elif 'count(*)' in sql_lower and 'count(distinct user_name)' in sql_lower and 'group by' not in sql_lower:
                    return pd.DataFrame([{
                        'TOTAL_QUERIES': len(df),
                        'UNIQUE_USERS': df['USER_NAME'].nunique(),
                        'ACTIVE_DAYS': 7,
                        'TOTAL_ROWS_ACCESSED': df['ROW_COUNT'].sum()
                    }])
                return df
            
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
