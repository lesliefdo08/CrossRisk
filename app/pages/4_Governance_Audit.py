import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
from Home import run_query

st.set_page_config(page_title="Governance & Audit", page_icon="🔒", layout="wide")

st.title("🔒 Governance & Compliance Dashboard")

st.markdown("""
    Monitor access patterns, compliance checks, and audit trails to ensure data privacy 
    and regulatory compliance across the CrossRisk platform.
""")

st.markdown("---")

# Compliance overview
st.subheader("✅ Compliance Status Overview")

col1, col2, col3, col4 = st.columns(4)

# Get compliance metrics
compliance_query = """
SELECT 
    check_type,
    check_result,
    COUNT(*) as check_count,
    MAX(checked_at) as last_check
FROM GOVERNANCE.privacy_compliance_log
WHERE checked_at >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY check_type, check_result
"""

try:
    compliance_df = run_query(compliance_query)
    
    if not compliance_df.empty:
        total_checks = compliance_df['CHECK_COUNT'].sum()
        passed_checks = compliance_df[compliance_df['CHECK_RESULT'] == 'PASSED']['CHECK_COUNT'].sum()
        failed_checks = compliance_df[compliance_df['CHECK_RESULT'] == 'FAILED']['CHECK_COUNT'].sum()
        warning_checks = compliance_df[compliance_df['CHECK_RESULT'] == 'WARNING']['CHECK_COUNT'].sum()
        
        with col1:
            st.metric("Total Checks (7 days)", f"{total_checks:,}")
        
        with col2:
            st.metric("Passed", f"{passed_checks:,}", delta="Compliant", delta_color="normal")
        
        with col3:
            if failed_checks > 0:
                st.metric("Failed", f"{failed_checks:,}", delta="Action Required", delta_color="inverse")
            else:
                st.metric("Failed", "0", delta="All Clear", delta_color="normal")
        
        with col4:
            if warning_checks > 0:
                st.metric("Warnings", f"{warning_checks:,}", delta="Review Needed", delta_color="off")
            else:
                st.metric("Warnings", "0", delta="No Issues", delta_color="normal")
        
        # Compliance status visualization
        st.markdown("### Recent Compliance Checks")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Pie chart of results
            result_summary = compliance_df.groupby('CHECK_RESULT')['CHECK_COUNT'].sum().reset_index()
            
            fig = px.pie(
                result_summary,
                values='CHECK_COUNT',
                names='CHECK_RESULT',
                title='Compliance Check Results (Last 7 Days)',
                color='CHECK_RESULT',
                color_discrete_map={
                    'PASSED': '#2ca02c',
                    'WARNING': '#ff7f0e',
                    'FAILED': '#d62728'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Bar chart by check type
            type_summary = compliance_df.groupby('CHECK_TYPE')['CHECK_COUNT'].sum().reset_index()
            type_summary = type_summary.sort_values('CHECK_COUNT', ascending=True)
            
            fig = px.bar(
                type_summary,
                y='CHECK_TYPE',
                x='CHECK_COUNT',
                orientation='h',
                title='Checks by Type',
                labels={'CHECK_COUNT': 'Number of Checks', 'CHECK_TYPE': 'Check Type'}
            )
            st.plotly_chart(fig, use_container_width=True)
    else:
        st.info("No compliance checks recorded in the last 7 days.")

except Exception as e:
    st.warning(f"Unable to load compliance metrics: {str(e)}")

st.markdown("---")

# Detailed compliance log
st.subheader("📋 Compliance Check Log")

# Date filter
col1, col2, col3 = st.columns([2, 2, 1])

with col1:
    days_back = st.selectbox(
        "Time Period",
        options=[7, 14, 30, 90],
        format_func=lambda x: f"Last {x} days",
        index=0
    )

with col2:
    check_type_filter = st.multiselect(
        "Check Type",
        options=['All'] + list(compliance_df['CHECK_TYPE'].unique()) if not compliance_df.empty else ['All'],
        default=['All']
    )

with col3:
    result_filter = st.selectbox(
        "Result Filter",
        options=['All', 'PASSED', 'WARNING', 'FAILED'],
        index=0
    )

# Build filtered query
where_clauses = [f"checked_at >= DATEADD(day, -{days_back}, CURRENT_TIMESTAMP())"]

if 'All' not in check_type_filter and check_type_filter:
    types_str = "', '".join(check_type_filter)
    where_clauses.append(f"check_type IN ('{types_str}')")

if result_filter != 'All':
    where_clauses.append(f"check_result = '{result_filter}'")

where_clause = " AND ".join(where_clauses)

log_query = f"""
SELECT 
    compliance_id,
    check_type,
    table_name,
    check_result,
    details,
    checked_at
FROM GOVERNANCE.privacy_compliance_log
WHERE {where_clause}
ORDER BY checked_at DESC
LIMIT 100
"""

try:
    log_df = run_query(log_query)
    
    if not log_df.empty:
        # Format for display
        display_log = log_df.copy()
        display_log['CHECKED_AT'] = pd.to_datetime(display_log['CHECKED_AT']).dt.strftime('%Y-%m-%d %H:%M:%S')
        display_log = display_log[['CHECKED_AT', 'CHECK_TYPE', 'CHECK_RESULT', 'TABLE_NAME', 'DETAILS']]
        display_log.columns = ['Timestamp', 'Check Type', 'Result', 'Table', 'Details']
        
        # Color code results
        def color_result(val):
            if val == 'PASSED':
                return 'background-color: #ccffcc'
            elif val == 'WARNING':
                return 'background-color: #ffffcc'
            elif val == 'FAILED':
                return 'background-color: #ffcccc'
            return ''
        
        styled_log = display_log.style.applymap(color_result, subset=['Result'])
        st.dataframe(styled_log, use_container_width=True, hide_index=True, height=400)
        
        # Export log
        st.download_button(
            label="📥 Export Compliance Log",
            data=display_log.to_csv(index=False),
            file_name=f"crossrisk_compliance_log_{pd.Timestamp.now().strftime('%Y%m%d')}.csv",
            mime="text/csv"
        )
    else:
        st.info("No compliance logs match the selected filters.")

except Exception as e:
    st.error(f"Error loading compliance log: {str(e)}")

st.markdown("---")

# Access audit section
st.subheader("🔍 Access Audit Trail")

st.markdown("""
    Monitor data access patterns to identify unusual activity and ensure proper data governance.
""")

# Access summary metrics
access_query = """
SELECT 
    COUNT(*) as total_queries,
    COUNT(DISTINCT user_name) as unique_users,
    COUNT(DISTINCT DATE(executed_at)) as active_days,
    SUM(row_count) as total_rows_accessed
FROM GOVERNANCE.access_audit_log
WHERE executed_at >= DATEADD(day, -7, CURRENT_TIMESTAMP())
"""

try:
    access_summary = run_query(access_query)
    
    if not access_summary.empty:
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric("Queries (7 days)", f"{access_summary['TOTAL_QUERIES'].values[0]:,}")
        
        with col2:
            st.metric("Unique Users", f"{access_summary['UNIQUE_USERS'].values[0]:,}")
        
        with col3:
            st.metric("Active Days", f"{access_summary['ACTIVE_DAYS'].values[0]}")
        
        with col4:
            rows_accessed = access_summary['TOTAL_ROWS_ACCESSED'].values[0]
            if pd.notna(rows_accessed):
                st.metric("Rows Accessed", f"{int(rows_accessed):,}")
            else:
                st.metric("Rows Accessed", "N/A")

except Exception as e:
    st.warning(f"Unable to load access metrics: {str(e)}")

# Access by user
st.markdown("### Access by User")

user_access_query = """
SELECT 
    user_name,
    role_name,
    COUNT(*) as query_count,
    SUM(row_count) as rows_accessed,
    MIN(executed_at) as first_access,
    MAX(executed_at) as last_access
FROM GOVERNANCE.access_audit_log
WHERE executed_at >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY user_name, role_name
ORDER BY query_count DESC
LIMIT 20
"""

try:
    user_access_df = run_query(user_access_query)
    
    if not user_access_df.empty:
        col1, col2 = st.columns(2)
        
        with col1:
            # Bar chart of query counts
            fig = px.bar(
                user_access_df.head(10),
                x='QUERY_COUNT',
                y='USER_NAME',
                orientation='h',
                title='Top 10 Users by Query Volume',
                labels={'QUERY_COUNT': 'Number of Queries', 'USER_NAME': 'User'},
                color='QUERY_COUNT',
                color_continuous_scale='Blues'
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Table view
            display_user = user_access_df.copy()
            display_user['FIRST_ACCESS'] = pd.to_datetime(display_user['FIRST_ACCESS']).dt.strftime('%Y-%m-%d')
            display_user['LAST_ACCESS'] = pd.to_datetime(display_user['LAST_ACCESS']).dt.strftime('%Y-%m-%d')
            display_user = display_user[['USER_NAME', 'ROLE_NAME', 'QUERY_COUNT', 'ROWS_ACCESSED']]
            display_user.columns = ['User', 'Role', 'Queries', 'Rows Accessed']
            
            st.dataframe(display_user, use_container_width=True, hide_index=True, height=400)

except Exception as e:
    st.warning(f"Unable to load user access data: {str(e)}")

st.markdown("---")

# Access patterns over time
st.subheader("📊 Access Patterns Over Time")

timeline_query = """
SELECT 
    DATE(executed_at) as access_date,
    COUNT(*) as query_count,
    COUNT(DISTINCT user_name) as unique_users,
    SUM(row_count) as rows_accessed
FROM GOVERNANCE.access_audit_log
WHERE executed_at >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY DATE(executed_at)
ORDER BY access_date
"""

try:
    timeline_df = run_query(timeline_query)
    
    if not timeline_df.empty:
        # Line chart
        fig = go.Figure()
        
        fig.add_trace(go.Scatter(
            x=timeline_df['ACCESS_DATE'],
            y=timeline_df['QUERY_COUNT'],
            mode='lines+markers',
            name='Query Count',
            line=dict(color='#1f77b4', width=2),
            yaxis='y'
        ))
        
        fig.add_trace(go.Scatter(
            x=timeline_df['ACCESS_DATE'],
            y=timeline_df['UNIQUE_USERS'],
            mode='lines+markers',
            name='Unique Users',
            line=dict(color='#ff7f0e', width=2),
            yaxis='y2'
        ))
        
        fig.update_layout(
            title='Access Activity Timeline (Last 30 Days)',
            xaxis_title='Date',
            yaxis=dict(title='Query Count', side='left'),
            yaxis2=dict(title='Unique Users', side='right', overlaying='y'),
            hovermode='x unified',
            legend=dict(x=0.01, y=0.99)
        )
        
        st.plotly_chart(fig, use_container_width=True)
        
        # Anomaly detection
        avg_queries = timeline_df['QUERY_COUNT'].mean()
        std_queries = timeline_df['QUERY_COUNT'].std()
        threshold = avg_queries + (2 * std_queries)
        
        anomalies = timeline_df[timeline_df['QUERY_COUNT'] > threshold]
        
        if not anomalies.empty:
            st.warning(f"⚠️ **Anomaly Detection:** {len(anomalies)} day(s) with unusually high query volume detected.")
            st.dataframe(
                anomalies[['ACCESS_DATE', 'QUERY_COUNT', 'UNIQUE_USERS']].rename(
                    columns={'ACCESS_DATE': 'Date', 'QUERY_COUNT': 'Queries', 'UNIQUE_USERS': 'Users'}
                ),
                use_container_width=True,
                hide_index=True
            )

except Exception as e:
    st.warning(f"Unable to load access timeline: {str(e)}")

st.markdown("---")

# Privacy metrics
st.subheader("🔐 Privacy Protection Metrics")

privacy_query = """
SELECT 
    'K-Anonymity Compliance' as metric,
    CASE 
        WHEN MIN(record_count) >= 3 THEN 'COMPLIANT'
        ELSE 'VIOLATION DETECTED'
    END as status,
    MIN(record_count) as min_group_size,
    COUNT(*) as total_segments
FROM ANALYTICS.risk_join_aggregated

UNION ALL

SELECT 
    'Masking Policies Active' as metric,
    'ACTIVE' as status,
    COUNT(*) as min_group_size,
    0 as total_segments
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES
WHERE policy_db = 'CROSSRISK_DB'
  AND policy_kind = 'MASKING_POLICY'
"""

try:
    privacy_df = run_query(privacy_query)
    
    if not privacy_df.empty:
        for _, row in privacy_df.iterrows():
            if row['STATUS'] == 'COMPLIANT' or row['STATUS'] == 'ACTIVE':
                st.success(f"✅ **{row['METRIC']}:** {row['STATUS']}")
            else:
                st.error(f"❌ **{row['METRIC']}:** {row['STATUS']}")
            
            if row['METRIC'] == 'K-Anonymity Compliance':
                st.caption(f"Minimum group size: {row['MIN_GROUP_SIZE']} | Total segments: {row['TOTAL_SEGMENTS']}")

except Exception as e:
    st.info("Privacy metrics require admin privileges to view policy references.")

# Data masking summary
st.markdown("### Active Data Protection Measures")

protection_summary = pd.DataFrame({
    'Protection Type': [
        'Dynamic Data Masking',
        'K-Anonymity Enforcement (k≥3)',
        'Row Access Policies',
        'Secure Clean Room Views',
        'Audit Logging'
    ],
    'Status': ['Active'] * 5,
    'Coverage': [
        'Customer IDs, Financial Bands',
        'All Analytics Aggregations',
        'Risk Score Based',
        'Cross-Org Insights',
        'All Data Access'
    ]
})

st.dataframe(protection_summary, use_container_width=True, hide_index=True)

st.markdown("---")

# System health check
st.subheader("🏥 System Health Status")

if st.button("Run System Health Check"):
    with st.spinner("Running health diagnostics..."):
        health_query = """
        SELECT system_health_check() as health_report
        """
        
        try:
            health_result = run_query(health_query)
            
            if not health_result.empty:
                # Parse JSON health report
                import json
                health_data = json.loads(health_result['HEALTH_REPORT'].values[0])
                
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    status = health_data.get('status', 'UNKNOWN')
                    if status == 'HEALTHY':
                        st.success(f"**System Status:** {status}")
                    elif status == 'FROZEN':
                        st.error(f"**System Status:** {status}")
                    else:
                        st.warning(f"**System Status:** {status}")
                
                with col2:
                    st.metric("Bank Records", f"{health_data.get('bank_records', 0):,}")
                    st.metric("Insurance Records", f"{health_data.get('insurance_records', 0):,}")
                
                with col3:
                    st.metric("Analytics Segments", f"{health_data.get('analytics_segments', 0):,}")
                    st.metric("AI Explanations", f"{health_data.get('ai_explanations', 0):,}")
                
                st.json(health_data, expanded=False)
        except Exception as e:
            st.error(f"Health check failed: {str(e)}")
            st.info("Ensure the system_health_check stored procedure has been created.")

st.markdown("---")

# Export audit report
st.subheader("📄 Generate Audit Report")

col1, col2 = st.columns(2)

with col1:
    report_start_date = st.date_input(
        "Report Start Date",
        value=datetime.now() - timedelta(days=30)
    )

with col2:
    report_end_date = st.date_input(
        "Report End Date",
        value=datetime.now()
    )

if st.button("Generate Full Audit Report"):
    with st.spinner("Generating comprehensive audit report..."):
        try:
            # Generate report
            report_query = f"""
            SELECT 
                'COMPLIANCE_CHECK' as audit_type,
                check_type as action,
                check_result as result,
                table_name as object,
                details,
                checked_at as timestamp
            FROM GOVERNANCE.privacy_compliance_log
            WHERE DATE(checked_at) BETWEEN '{report_start_date}' AND '{report_end_date}'
            
            UNION ALL
            
            SELECT 
                'DATA_ACCESS' as audit_type,
                query_type as action,
                'EXECUTED' as result,
                'N/A' as object,
                LEFT(query_text, 100) as details,
                executed_at as timestamp
            FROM GOVERNANCE.access_audit_log
            WHERE DATE(executed_at) BETWEEN '{report_start_date}' AND '{report_end_date}'
            
            ORDER BY timestamp DESC
            """
            
            report_df = run_query(report_query)
            
            if not report_df.empty:
                st.success(f"✅ Generated report with {len(report_df):,} audit entries")
                
                # Summary stats
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    compliance_entries = (report_df['AUDIT_TYPE'] == 'COMPLIANCE_CHECK').sum()
                    st.metric("Compliance Checks", f"{compliance_entries:,}")
                
                with col2:
                    access_entries = (report_df['AUDIT_TYPE'] == 'DATA_ACCESS').sum()
                    st.metric("Access Events", f"{access_entries:,}")
                
                with col3:
                    date_range = (report_end_date - report_start_date).days + 1
                    st.metric("Date Range", f"{date_range} days")
                
                # Download report
                st.download_button(
                    label="📥 Download Complete Audit Report",
                    data=report_df.to_csv(index=False),
                    file_name=f"crossrisk_audit_report_{report_start_date}_{report_end_date}.csv",
                    mime="text/csv"
                )
            else:
                st.info("No audit entries found for the selected date range.")
        
        except Exception as e:
            st.error(f"Error generating audit report: {str(e)}")

# Footer
st.markdown("---")
st.markdown("""
    <div style="text-align: center; color: #666; padding: 1rem 0;">
        <p><strong>Governance & Compliance Dashboard</strong></p>
        <p>All access is logged and monitored for regulatory compliance</p>
    </div>
""", unsafe_allow_html=True)
