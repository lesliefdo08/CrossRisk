import streamlit as st
import snowflake.connector
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import os

# Page configuration
st.set_page_config(
    page_title="CrossRisk Platform",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for better styling
st.markdown("""
    <style>
    .main-header {
        font-size: 2.5rem;
        font-weight: bold;
        color: #1f77b4;
        text-align: center;
        margin-bottom: 2rem;
    }
    .metric-card {
        background-color: #f0f2f6;
        padding: 1rem;
        border-radius: 0.5rem;
        border-left: 4px solid #1f77b4;
    }
    .risk-critical { color: #d62728; font-weight: bold; }
    .risk-high { color: #ff7f0e; font-weight: bold; }
    .risk-medium { color: #ffbb78; font-weight: bold; }
    .risk-low { color: #2ca02c; font-weight: bold; }
    </style>
""", unsafe_allow_html=True)

# Snowflake connection helper
@st.cache_resource
def get_snowflake_connection():
    """
    Initialize Snowflake connection.
    In production, use Snowflake connector or streamlit-snowflake connector.
    """
    try:
        # For Streamlit in Snowflake, use:
        return st.connection("snowflake")
        
        # For local development with credentials:
        # conn = snowflake.connector.connect(
        #     user=os.getenv('SNOWFLAKE_USER'),
        #     password=os.getenv('SNOWFLAKE_PASSWORD'),
        #     account=os.getenv('SNOWFLAKE_ACCOUNT'),
        #     warehouse='CROSSRISK_ANALYTICS_WH',
        #     database='CROSSRISK_DB',
        #     schema='ANALYTICS'
        # )
        # return conn
    except Exception as e:
        st.error(f"Connection error: {str(e)}")
        return None

@st.cache_data(ttl=300)
def run_query(query):
    """Execute SQL query and return results as DataFrame"""
    try:
        conn = get_snowflake_connection()
        return conn.query(query, ttl=300)
    except Exception as e:
        st.error(f"Query error: {str(e)}")
        return pd.DataFrame()

# Sidebar navigation
st.sidebar.title("🛡️ CrossRisk Platform")
st.sidebar.markdown("---")
st.sidebar.markdown("### Navigation")
st.sidebar.info(
    "**Privacy-Safe Cross-Organization Risk Analytics**\n\n"
    "Combining banking and insurance data to detect risk patterns "
    "while preserving customer privacy."
)

# Main page header
st.markdown('<h1 class="main-header">🛡️ CrossRisk Analytics Dashboard</h1>', unsafe_allow_html=True)

st.markdown("""
    <div style="background-color: #e3f2fd; padding: 1rem; border-radius: 0.5rem; margin-bottom: 2rem;">
        <h3 style="margin-top: 0;">Welcome to CrossRisk</h3>
        <p>A privacy-first platform that enables secure cross-organizational risk insights by combining 
        banking and insurance data through advanced data masking and k-anonymity protection.</p>
    </div>
""", unsafe_allow_html=True)

# Key metrics section
st.subheader("📊 Platform Overview")

col1, col2, col3, col4 = st.columns(4)

# Fetch summary statistics
summary_query = """
SELECT 
    COUNT(*) as total_segments,
    SUM(record_count) as total_customers,
    ROUND(AVG(composite_risk_score), 2) as avg_risk,
    SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) as high_risk_count
FROM ANALYTICS.risk_join_aggregated
"""

try:
    summary_df = run_query(summary_query)
    
    if not summary_df.empty:
        with col1:
            st.metric(
                "Customer Segments",
                f"{summary_df['TOTAL_SEGMENTS'].values[0]:,}",
                help="Number of privacy-safe customer segments analyzed"
            )
        
        with col2:
            st.metric(
                "Total Customers",
                f"{summary_df['TOTAL_CUSTOMERS'].values[0]:,}",
                help="Total customers across both organizations"
            )
        
        with col3:
            st.metric(
                "Avg Risk Score",
                f"{summary_df['AVG_RISK'].values[0]}",
                help="Average composite risk score (0-100)"
            )
        
        with col4:
            st.metric(
                "High Risk Customers",
                f"{summary_df['HIGH_RISK_COUNT'].values[0]:,}",
                help="Customers in HIGH or CRITICAL risk categories"
            )
except Exception as e:
    st.warning("Unable to load summary metrics. Please check database connection.")

st.markdown("---")

# Risk distribution visualization
st.subheader("🎯 Risk Category Distribution")

col1, col2 = st.columns(2)

with col1:
    # Risk category breakdown
    risk_dist_query = """
    SELECT 
        risk_category,
        COUNT(*) as segment_count,
        SUM(record_count) as customer_count
    FROM ANALYTICS.risk_join_aggregated
    GROUP BY risk_category
    ORDER BY 
        CASE risk_category
            WHEN 'CRITICAL' THEN 1
            WHEN 'HIGH' THEN 2
            WHEN 'MEDIUM' THEN 3
            WHEN 'LOW' THEN 4
        END
    """
    
    try:
        risk_dist_df = run_query(risk_dist_query)
        
        if not risk_dist_df.empty:
            # Create pie chart
            fig = px.pie(
                risk_dist_df,
                values='CUSTOMER_COUNT',
                names='RISK_CATEGORY',
                title='Customer Distribution by Risk Category',
                color='RISK_CATEGORY',
                color_discrete_map={
                    'CRITICAL': '#d62728',
                    'HIGH': '#ff7f0e',
                    'MEDIUM': '#ffbb78',
                    'LOW': '#2ca02c'
                }
            )
            fig.update_traces(textposition='inside', textinfo='percent+label')
            st.plotly_chart(fig, use_container_width=True)
    except Exception as e:
        st.error(f"Error loading risk distribution: {str(e)}")

with col2:
    # Risk by age group
    age_risk_query = """
    SELECT 
        age_group,
        ROUND(AVG(composite_risk_score), 2) as avg_risk_score,
        SUM(record_count) as customer_count
    FROM ANALYTICS.risk_join_aggregated
    GROUP BY age_group
    ORDER BY avg_risk_score DESC
    """
    
    try:
        age_risk_df = run_query(age_risk_query)
        
        if not age_risk_df.empty:
            fig = px.bar(
                age_risk_df,
                x='AGE_GROUP',
                y='AVG_RISK_SCORE',
                title='Average Risk Score by Age Group',
                color='AVG_RISK_SCORE',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK_SCORE': 'Risk Score', 'AGE_GROUP': 'Age Group'}
            )
            fig.update_layout(showlegend=False)
            st.plotly_chart(fig, use_container_width=True)
    except Exception as e:
        st.error(f"Error loading age group analysis: {str(e)}")

st.markdown("---")

# Regional risk heatmap
st.subheader("🗺️ Regional Risk Analysis")

regional_query = """
SELECT 
    region,
    ROUND(AVG(composite_risk_score), 2) as avg_risk,
    SUM(record_count) as customer_count,
    COUNT(*) as segment_count,
    SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) as high_risk_customers
FROM ANALYTICS.risk_join_aggregated
GROUP BY region
ORDER BY avg_risk DESC
"""

try:
    regional_df = run_query(regional_query)
    
    if not regional_df.empty:
        col1, col2 = st.columns([2, 1])
        
        with col1:
            # Bar chart
            fig = px.bar(
                regional_df,
                x='REGION',
                y='AVG_RISK',
                color='AVG_RISK',
                title='Average Risk Score by Region',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Average Risk Score', 'REGION': 'Region'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Table view
            st.markdown("#### Regional Summary")
            display_df = regional_df.copy()
            display_df.columns = ['Region', 'Avg Risk', 'Customers', 'Segments', 'High Risk']
            st.dataframe(display_df, use_container_width=True, hide_index=True)
except Exception as e:
    st.error(f"Error loading regional analysis: {str(e)}")

st.markdown("---")

# AI Insights section
st.subheader("🤖 AI-Powered Insights")

ai_summary_query = """
SELECT ai_summary
FROM AI_INSIGHTS.approved_questions_cache
WHERE question_id = 'Q001'
ORDER BY last_refreshed DESC
LIMIT 1
"""

try:
    ai_summary_df = run_query(ai_summary_query)
    
    if not ai_summary_df.empty and len(ai_summary_df) > 0:
        ai_text = ai_summary_df['AI_SUMMARY'].values[0]
        st.info(f"**AI Analysis:** {ai_text}")
    else:
        st.info("**Dataset Overview:** This platform analyzes cross-organizational risk data "
                "combining banking and insurance signals. All data is privacy-protected through "
                "k-anonymity (minimum 3 customers per segment) and dynamic masking policies.")
except Exception as e:
    st.warning("AI insights temporarily unavailable.")

st.markdown("---")

# Recent activity
st.subheader("📋 Recent System Activity")

activity_query = """
SELECT 
    check_type,
    check_result,
    LEFT(details, 100) as summary,
    checked_at
FROM GOVERNANCE.privacy_compliance_log
ORDER BY checked_at DESC
LIMIT 5
"""

try:
    activity_df = run_query(activity_query)
    
    if not activity_df.empty:
        display_df = activity_df.copy()
        display_df.columns = ['Check Type', 'Result', 'Details', 'Timestamp']
        st.dataframe(display_df, use_container_width=True, hide_index=True)
    else:
        st.info("No recent activity to display.")
except Exception as e:
    st.warning("Unable to load recent activity.")

# Footer
st.markdown("---")
st.markdown("""
    <div style="text-align: center; color: #666; padding: 2rem 0;">
        <p><strong>CrossRisk Platform</strong> | Privacy-Safe Cross-Organization Analytics</p>
        <p>All data is protected by k-anonymity rules and dynamic masking policies</p>
    </div>
""", unsafe_allow_html=True)
