import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
import sys
from pathlib import Path

sys.path.append(str(Path(__file__).parent))
from db_connection import run_query, is_offline_mode

st.set_page_config(
    page_title="CrossRisk Analytics",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Styling
st.markdown("""
    <style>
    .main-header {
        font-size: 2.2rem;
        font-weight: 600;
        color: #1f77b4;
        margin-bottom: 1.5rem;
    }
    .metric-card {
        background-color: #f8f9fa;
        padding: 1rem;
        border-radius: 0.4rem;
        border-left: 3px solid #1f77b4;
    }
    </style>
""", unsafe_allow_html=True)

# Sidebar
st.sidebar.title("CrossRisk Platform")
st.sidebar.markdown("---")
st.sidebar.markdown("### About")
st.sidebar.info(
    "Privacy-safe cross-organization risk analytics combining "
    "banking and insurance data with k-anonymity protection."
)

if is_offline_mode():
    st.sidebar.warning("Offline Mode: Using sample data")

# Header
st.markdown('<h1 class="main-header">CrossRisk Analytics Dashboard</h1>', unsafe_allow_html=True)

st.markdown("""
<div style="background-color: #e3f2fd; padding: 1rem; border-radius: 0.4rem; margin-bottom: 1.5rem;">
    <p style="margin: 0; color: #1565c0;">
    Secure cross-organizational risk platform enabling privacy-preserving analytics 
    through data masking and k-anonymity enforcement.
    </p>
</div>
""", unsafe_allow_html=True)

# Key metrics
st.subheader("Platform Overview")

col1, col2, col3, col4 = st.columns(4)

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
                help="Privacy-safe customer segments (k>=3)"
            )
        
        with col2:
            st.metric(
                "Total Customers",
                f"{summary_df['TOTAL_CUSTOMERS'].values[0]:,}",
                help="Combined bank and insurance customers"
            )
        
        with col3:
            st.metric(
                "Avg Risk Score",
                f"{summary_df['AVG_RISK'].values[0]:.1f}",
                help="Composite risk score (0-100 scale)"
            )
        
        with col4:
            st.metric(
                "High Risk Count",
                f"{summary_df['HIGH_RISK_COUNT'].values[0]:,}",
                help="Customers in HIGH or CRITICAL categories"
            )
    else:
        st.info("No data available. Please check database connection.")
        
except Exception as e:
    st.error(f"Unable to load metrics: {str(e)[:100]}")

st.markdown("---")

# Risk visualization
st.subheader("Risk Category Distribution")

col1, col2 = st.columns(2)

with col1:
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
            fig = px.pie(
                risk_dist_df,
                values='CUSTOMER_COUNT',
                names='RISK_CATEGORY',
                title='Customers by Risk Level',
                color='RISK_CATEGORY',
                color_discrete_map={
                    'CRITICAL': '#d62728',
                    'HIGH': '#ff7f0e',
                    'MEDIUM': '#ffbb78',
                    'LOW': '#2ca02c'
                }
            )
            fig.update_traces(textposition='inside', textinfo='percent+label')
            fig.update_layout(showlegend=True, height=400)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No risk distribution data available")
            
    except Exception as e:
        st.error(f"Error loading chart: {str(e)[:100]}")

with col2:
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
                title='Average Risk Score by Age',
                color='AVG_RISK_SCORE',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK_SCORE': 'Risk Score', 'AGE_GROUP': 'Age Group'}
            )
            fig.update_layout(showlegend=False, height=400)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No age group data available")
            
    except Exception as e:
        st.error(f"Error loading chart: {str(e)[:100]}")

st.markdown("---")

# Regional analysis
st.subheader("Regional Risk Analysis")

regional_query = """
SELECT 
    region,
    ROUND(AVG(composite_risk_score), 2) as avg_risk,
    SUM(record_count) as customer_count,
    COUNT(*) as segment_count
FROM ANALYTICS.risk_join_aggregated
GROUP BY region
ORDER BY avg_risk DESC
"""

try:
    regional_df = run_query(regional_query)
    
    if not regional_df.empty:
        col1, col2 = st.columns([2, 1])
        
        with col1:
            fig = px.bar(
                regional_df,
                x='REGION',
                y='AVG_RISK',
                color='AVG_RISK',
                title='Average Risk by Region',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Average Risk', 'REGION': 'Region'}
            )
            fig.update_layout(showlegend=False, height=400)
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.markdown("#### Regional Summary")
            display_df = regional_df.copy()
            # Ensure column names match what query returns
            if len(display_df.columns) == 4:
                display_df.columns = ['Region', 'Avg Risk', 'Customers', 'Segments']
            st.dataframe(display_df, use_container_width=True, hide_index=True)
    else:
        st.info("No regional data available")
        
except Exception as e:
    st.error(f"Error loading regional data: {str(e)[:100]}")

st.markdown("---")

# AI insights
st.subheader("Model-Generated Insights")

ai_summary_query = """
SELECT ai_summary
FROM AI_INSIGHTS.approved_questions_cache
WHERE question_id = 'Q001'
ORDER BY last_refreshed DESC
LIMIT 1
"""

try:
    ai_summary_df = run_query(ai_summary_query)
    
    if not ai_summary_df.empty and 'AI_SUMMARY' in ai_summary_df.columns:
        ai_text = ai_summary_df['AI_SUMMARY'].values[0]
        if pd.notna(ai_text) and ai_text:
            st.info(ai_text)
        else:
            st.info("Platform analyzes cross-organizational risk data combining banking and insurance signals. All data is privacy-protected through k-anonymity and dynamic masking.")
    else:
        st.info("Platform analyzes cross-organizational risk data combining banking and insurance signals. All data is privacy-protected through k-anonymity and dynamic masking.")
        
except Exception as e:
    st.info("Platform analyzes cross-organizational risk data combining banking and insurance signals. All data is privacy-protected through k-anonymity and dynamic masking.")

st.markdown("---")

# Recent activity
st.subheader("System Activity")

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
        st.info("No recent activity available")
        
except Exception as e:
    st.info("Activity log temporarily unavailable")

# Footer
st.markdown("---")
st.markdown("""
<div style="text-align: center; color: #666; padding: 1.5rem 0;">
    <p><strong>CrossRisk Platform</strong> | Privacy-Safe Cross-Organization Analytics</p>
    <p style="font-size: 0.9em;">K-anonymity enforcement and dynamic masking protect all customer data</p>
</div>
""", unsafe_allow_html=True)
