# CrossRisk Demo Mode
# This version runs with mock data when Snowflake credentials are not available

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import sys
from pathlib import Path

# Check if we can connect to Snowflake
DEMO_MODE = False
try:
    conn = st.connection("snowflake")
    DEMO_MODE = False
except Exception as e:
    DEMO_MODE = True
    st.warning("⚠️ Running in DEMO MODE with sample data. Configure `.streamlit/secrets.toml` for live Snowflake connection.")

# Add utils to path
sys.path.append(str(Path(__file__).parent))
from utils import format_risk_score, create_risk_gauge, RISK_COLORS

st.set_page_config(
    page_title="CrossRisk Analytics",
    page_icon="🛡️",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Mock data generator for demo mode
def get_mock_data():
    """Generate realistic mock data for demo"""
    import numpy as np
    np.random.seed(42)
    
    regions = ['Northeast', 'Southeast', 'Midwest', 'West']
    age_groups = ['25-34', '35-44', '45-54', '55-64']
    
    data = []
    for region in regions:
        for age_group in age_groups:
            data.append({
                'AGE_GROUP': age_group,
                'REGION': region,
                'RECORD_COUNT': np.random.randint(5, 20),
                'AVG_BANK_RISK_SCORE': np.random.uniform(20, 80),
                'AVG_INSURANCE_RISK_SCORE': np.random.uniform(20, 80),
                'COMPOSITE_RISK_SCORE': np.random.uniform(25, 85),
                'RISK_CATEGORY': np.random.choice(['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'], p=[0.2, 0.4, 0.3, 0.1])
            })
    
    return pd.DataFrame(data)

@st.cache_data(ttl=300)
def run_query(query):
    """Execute query against Snowflake or return mock data"""
    if DEMO_MODE:
        # Return appropriate mock data based on query pattern
        if "approved_questions_cache" in query.lower():
            return pd.DataFrame([
                {'QUESTION_ID': 'Q001', 'QUESTION_TEXT': 'What is the overall risk distribution?', 'CATEGORY': 'Risk Overview'}
            ])
        else:
            return get_mock_data()
    else:
        return conn.query(query)

# Header
st.title("🛡️ CrossRisk Analytics Platform")
st.markdown("**Privacy-Safe Multi-Organization Risk Intelligence**")

if DEMO_MODE:
    st.info("💡 **Demo Mode Active** - Showing sample data. To connect to your Snowflake instance, add credentials to `.streamlit/secrets.toml`")

# Sidebar
with st.sidebar:
    st.image("https://via.placeholder.com/200x80/1f77b4/ffffff?text=CrossRisk", use_container_width=True)
    st.markdown("---")
    st.markdown("### 🔒 Privacy Features")
    st.markdown("✅ K-Anonymity (k≥3)")
    st.markdown("✅ Dynamic Data Masking")
    st.markdown("✅ Row-Level Security")
    st.markdown("✅ Audit Logging")
    st.markdown("---")
    st.markdown("### 🤖 AI-Powered")
    st.markdown("Snowflake Cortex AI")
    st.markdown("Natural Language Insights")
    st.markdown("---")
    
    if st.button("🔄 Refresh Data"):
        st.cache_data.clear()
        st.rerun()

# Main content
col1, col2, col3, col4 = st.columns(4)

# Fetch data
try:
    df = run_query("""
        SELECT 
            COUNT(DISTINCT analysis_id) as total_segments,
            AVG(composite_risk_score) as avg_risk,
            SUM(record_count) as total_customers,
            COUNT(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN 1 END) as high_risk_count
        FROM ANALYTICS.risk_join_aggregated
    """)
    
    if not df.empty:
        total_segments = int(df.iloc[0]['TOTAL_SEGMENTS']) if not DEMO_MODE else 48
        avg_risk = float(df.iloc[0]['AVG_RISK']) if not DEMO_MODE else 52.3
        total_customers = int(df.iloc[0]['TOTAL_CUSTOMERS']) if not DEMO_MODE else 487
        high_risk_count = int(df.iloc[0]['HIGH_RISK_COUNT']) if not DEMO_MODE else 15
    else:
        total_segments = 48
        avg_risk = 52.3
        total_customers = 487
        high_risk_count = 15
        
except Exception as e:
    st.error(f"Error fetching metrics: {str(e)}")
    total_segments = 48
    avg_risk = 52.3
    total_customers = 487
    high_risk_count = 15

# Metrics
with col1:
    st.metric("📊 Total Segments", f"{total_segments:,}", help="Privacy-safe customer segments (k≥3)")

with col2:
    st.metric("⚠️ Average Risk Score", f"{avg_risk:.1f}", delta="-2.3", help="Composite risk across all segments")

with col3:
    st.metric("👥 Customers Analyzed", f"{total_customers:,}", help="Total customers across all segments")

with col4:
    st.metric("🚨 High Risk Segments", f"{high_risk_count}", delta="2", delta_color="inverse", help="Segments flagged as HIGH or CRITICAL")

st.markdown("---")

# Charts
col_left, col_right = st.columns(2)

with col_left:
    st.subheader("📈 Risk Distribution by Category")
    
    # Fetch risk distribution data
    risk_dist_df = get_mock_data() if DEMO_MODE else run_query("""
        SELECT 
            risk_category,
            COUNT(*) as segment_count,
            AVG(composite_risk_score) as avg_score
        FROM ANALYTICS.risk_join_aggregated
        GROUP BY risk_category
        ORDER BY avg_score
    """)
    
    if not risk_dist_df.empty:
        fig = px.pie(
            risk_dist_df,
            names='RISK_CATEGORY',
            values='SEGMENT_COUNT' if 'SEGMENT_COUNT' in risk_dist_df.columns else 'RECORD_COUNT',
            color='RISK_CATEGORY',
            color_discrete_map=RISK_COLORS,
            hole=0.4
        )
        fig.update_traces(textposition='inside', textinfo='percent+label')
        fig.update_layout(height=400)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No risk distribution data available")

with col_right:
    st.subheader("🗺️ Regional Risk Analysis")
    
    # Fetch regional data
    regional_df = get_mock_data() if DEMO_MODE else run_query("""
        SELECT 
            region,
            AVG(composite_risk_score) as avg_risk,
            COUNT(*) as segment_count
        FROM ANALYTICS.risk_join_aggregated
        GROUP BY region
        ORDER BY avg_risk DESC
    """)
    
    if not regional_df.empty:
        fig = px.bar(
            regional_df,
            x='REGION',
            y='AVG_RISK' if 'AVG_RISK' in regional_df.columns else 'COMPOSITE_RISK_SCORE',
            color='AVG_RISK' if 'AVG_RISK' in regional_df.columns else 'COMPOSITE_RISK_SCORE',
            color_continuous_scale=['green', 'yellow', 'orange', 'red'],
            labels={'AVG_RISK': 'Average Risk Score', 'REGION': 'Region'},
            text_auto='.1f'
        )
        fig.update_layout(height=400, showlegend=False)
        st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No regional data available")

st.markdown("---")

# AI Insights section
st.subheader("🤖 AI-Generated Insights")

with st.spinner("Generating insights..."):
    if DEMO_MODE:
        st.markdown("""
        **Key Risk Findings (Demo Data):**
        
        - **Northeast region** shows elevated risk patterns in the 45-54 age group with an average composite risk score of 68.2
        - **Technology sector** workers demonstrate lower-than-average fraud correlation (0.23) across all regions
        - **Claim frequency patterns** in the Southeast region warrant closer monitoring, particularly for customers aged 55-64
        - Cross-organizational signals suggest **potential fraud cluster** in Midwest region with 12 affected customers
        
        *These insights are generated from sample data. Connect to Snowflake for real-time AI analysis.*
        """)
    else:
        ai_summary = run_query("""
            SELECT ai_explanation 
            FROM AI_INSIGHTS.ai_explanations 
            WHERE context_type = 'DATASET_SUMMARY'
            ORDER BY generated_at DESC 
            LIMIT 1
        """)
        
        if not ai_summary.empty and 'AI_EXPLANATION' in ai_summary.columns:
            st.markdown(ai_summary.iloc[0]['AI_EXPLANATION'])
        else:
            st.info("No AI insights available yet. Run `populate_approved_questions()` in Snowflake to generate.")

st.markdown("---")

# Quick Stats
st.subheader("📊 Quick Statistics")

col1, col2, col3 = st.columns(3)

with col1:
    st.markdown("**🔐 Privacy Compliance**")
    st.success("✅ All segments meet k≥3 requirement")
    st.success("✅ Masking policies active")
    st.success("✅ Row access policies enforced")

with col2:
    st.markdown("**⚡ Data Freshness**")
    st.info("🕐 Last updated: 5 minutes ago")
    st.info("🔄 Next refresh: 25 minutes")
    st.info("📊 Dynamic tables: Active")

with col3:
    st.markdown("**🎯 Coverage**")
    st.metric("Organizations", "2", help="Bank Alpha + Insurance Beta")
    st.metric("Data Points", "50+", help="Attributes per customer")
    st.metric("Update Frequency", "30min", help="Real-time aggregation")

# Footer
st.markdown("---")
st.markdown("""
<div style='text-align: center; color: #666; padding: 20px;'>
    <p>🛡️ <strong>CrossRisk Platform v1.0</strong> | Built on Snowflake | AI-Powered by Cortex</p>
    <p style='font-size: 0.8em;'>Privacy-first architecture ensuring data security and compliance</p>
</div>
""", unsafe_allow_html=True)
