import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from Home import run_query, get_snowflake_connection

st.set_page_config(page_title="Pre-Approved Questions", page_icon="❓", layout="wide")

st.title("❓ Pre-Approved Analytics Questions")

st.markdown("""
    This page provides answers to curated analytics questions that have been pre-approved 
    by data governance teams. Each question is designed to provide actionable insights while 
    maintaining strict privacy standards.
""")

# Fetch all approved questions
questions_query = """
SELECT 
    question_id,
    question_text,
    category,
    result_data,
    ai_summary,
    last_refreshed
FROM AI_INSIGHTS.approved_questions_cache
ORDER BY question_id
"""

try:
    questions_df = run_query(questions_query)
    
    if questions_df.empty:
        st.warning("No pre-approved questions available. Please run the analytics refresh procedure.")
        st.stop()
    
    # Sidebar for question selection
    st.sidebar.title("Select Question")
    categories = questions_df['CATEGORY'].unique()
    
    selected_category = st.sidebar.selectbox(
        "Filter by Category",
        ['All'] + list(categories)
    )
    
    # Filter questions by category
    if selected_category != 'All':
        filtered_df = questions_df[questions_df['CATEGORY'] == selected_category]
    else:
        filtered_df = questions_df
    
    # Display questions as selectbox
    question_options = {row['QUESTION_TEXT']: row['QUESTION_ID'] 
                       for _, row in filtered_df.iterrows()}
    
    selected_question_text = st.selectbox(
        "Choose a question to explore:",
        list(question_options.keys())
    )
    
    selected_question_id = question_options[selected_question_text]
    
    # Get the selected question details
    question_row = questions_df[questions_df['QUESTION_ID'] == selected_question_id].iloc[0]
    
    st.markdown("---")
    
    # Display question details
    col1, col2 = st.columns([3, 1])
    
    with col1:
        st.subheader(f"📊 {question_row['QUESTION_TEXT']}")
    
    with col2:
        st.metric("Category", question_row['CATEGORY'])
        st.caption(f"Last updated: {question_row['LAST_REFRESHED']}")
    
    # Display AI summary
    if pd.notna(question_row['AI_SUMMARY']) and question_row['AI_SUMMARY']:
        st.info(f"**AI Analysis:** {question_row['AI_SUMMARY']}")
    
    st.markdown("---")
    
    # Parse and display results based on question ID
    if selected_question_id == 'Q001':
        # Overall risk distribution
        st.subheader("Risk Distribution Analysis")
        
        # Fetch fresh data for visualization
        risk_dist_query = """
        SELECT 
            risk_category,
            COUNT(*) as segment_count,
            SUM(record_count) as customer_count,
            ROUND(AVG(composite_risk_score), 2) as avg_risk_score
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
        
        risk_df = run_query(risk_dist_query)
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Pie chart
            fig = px.pie(
                risk_df,
                values='CUSTOMER_COUNT',
                names='RISK_CATEGORY',
                title='Customer Distribution',
                color='RISK_CATEGORY',
                color_discrete_map={
                    'CRITICAL': '#d62728',
                    'HIGH': '#ff7f0e',
                    'MEDIUM': '#ffbb78',
                    'LOW': '#2ca02c'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Bar chart
            fig = px.bar(
                risk_df,
                x='RISK_CATEGORY',
                y='CUSTOMER_COUNT',
                color='AVG_RISK_SCORE',
                title='Customers by Risk Category',
                color_continuous_scale='RdYlGn_r',
                labels={'CUSTOMER_COUNT': 'Number of Customers', 'RISK_CATEGORY': 'Risk Level'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        # Summary table
        st.markdown("### Detailed Breakdown")
        display_df = risk_df.copy()
        display_df.columns = ['Risk Category', 'Segments', 'Customers', 'Avg Risk Score']
        st.dataframe(display_df, use_container_width=True, hide_index=True)
    
    elif selected_question_id == 'Q002':
        # Age group risk analysis
        st.subheader("Age Group Risk Analysis")
        
        age_query = """
        SELECT 
            age_group,
            SUM(record_count) as total_customers,
            ROUND(AVG(composite_risk_score), 2) as avg_risk,
            SUM(CASE WHEN risk_category = 'CRITICAL' THEN record_count ELSE 0 END) as critical_count,
            SUM(CASE WHEN risk_category = 'HIGH' THEN record_count ELSE 0 END) as high_count,
            SUM(CASE WHEN risk_category = 'MEDIUM' THEN record_count ELSE 0 END) as medium_count,
            SUM(CASE WHEN risk_category = 'LOW' THEN record_count ELSE 0 END) as low_count
        FROM ANALYTICS.risk_join_aggregated
        GROUP BY age_group
        HAVING SUM(record_count) >= 3
        ORDER BY avg_risk DESC
        """
        
        age_df = run_query(age_query)
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Risk score by age
            fig = px.bar(
                age_df,
                x='AGE_GROUP',
                y='AVG_RISK',
                title='Average Risk Score by Age Group',
                color='AVG_RISK',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Risk Score', 'AGE_GROUP': 'Age Group'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Stacked bar for risk breakdown
            breakdown_df = age_df[['AGE_GROUP', 'CRITICAL_COUNT', 'HIGH_COUNT', 'MEDIUM_COUNT', 'LOW_COUNT']].copy()
            breakdown_df = breakdown_df.melt(id_vars='AGE_GROUP', var_name='Risk Level', value_name='Count')
            breakdown_df['Risk Level'] = breakdown_df['Risk Level'].str.replace('_COUNT', '').str.title()
            
            fig = px.bar(
                breakdown_df,
                x='AGE_GROUP',
                y='Count',
                color='Risk Level',
                title='Risk Category Distribution by Age',
                color_discrete_map={
                    'Critical': '#d62728',
                    'High': '#ff7f0e',
                    'Medium': '#ffbb78',
                    'Low': '#2ca02c'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        # Table
        st.markdown("### Age Group Statistics")
        display_df = age_df.copy()
        display_df.columns = ['Age Group', 'Customers', 'Avg Risk', 'Critical', 'High', 'Medium', 'Low']
        st.dataframe(display_df, use_container_width=True, hide_index=True)
    
    elif selected_question_id == 'Q003':
        # Regional risk hotspots
        st.subheader("Regional Risk Hotspots")
        
        regional_query = """
        SELECT 
            region,
            ROUND(AVG(composite_risk_score), 2) as avg_risk,
            SUM(record_count) as total_customers,
            COUNT(*) as segment_count,
            SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) as high_risk_count,
            ROUND((SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / SUM(record_count)), 1) as high_risk_pct
        FROM ANALYTICS.risk_join_aggregated
        GROUP BY region
        HAVING SUM(record_count) >= 3
        ORDER BY avg_risk DESC
        """
        
        regional_df = run_query(regional_query)
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            # Map-style bar chart
            fig = px.bar(
                regional_df,
                y='REGION',
                x='AVG_RISK',
                orientation='h',
                title='Average Risk Score by Region',
                color='AVG_RISK',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Risk Score', 'REGION': 'Region'}
            )
            fig.update_layout(height=400)
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.markdown("### Top Risk Regions")
            for _, row in regional_df.head(5).iterrows():
                st.metric(
                    row['REGION'],
                    f"{row['AVG_RISK']}",
                    f"{row['HIGH_RISK_PCT']}% high risk"
                )
        
        # Detailed table
        st.markdown("### Regional Statistics")
        display_df = regional_df.copy()
        display_df.columns = ['Region', 'Avg Risk', 'Customers', 'Segments', 'High Risk Count', 'High Risk %']
        st.dataframe(display_df, use_container_width=True, hide_index=True)
    
    elif selected_question_id == 'Q004':
        # Fraud patterns
        st.subheader("Fraud Pattern Detection")
        
        fraud_query = """
        SELECT 
            age_group,
            region,
            pattern_description,
            affected_customer_count,
            ROUND(confidence_score * 100, 1) as confidence_percentage,
            detected_at
        FROM ANALYTICS.fraud_cross_signals
        WHERE detected_at >= DATEADD(day, -30, CURRENT_TIMESTAMP())
        ORDER BY confidence_score DESC, affected_customer_count DESC
        """
        
        fraud_df = run_query(fraud_query)
        
        if not fraud_df.empty:
            # Scatter plot
            fig = px.scatter(
                fraud_df,
                x='AFFECTED_CUSTOMER_COUNT',
                y='CONFIDENCE_PERCENTAGE',
                color='PATTERN_DESCRIPTION',
                size='AFFECTED_CUSTOMER_COUNT',
                hover_data=['AGE_GROUP', 'REGION'],
                title='Fraud Patterns: Confidence vs Impact',
                labels={
                    'AFFECTED_CUSTOMER_COUNT': 'Affected Customers',
                    'CONFIDENCE_PERCENTAGE': 'Confidence %'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
            
            # Alert cards
            st.markdown("### Active Fraud Alerts")
            for _, row in fraud_df.head(5).iterrows():
                severity = "🔴" if row['CONFIDENCE_PERCENTAGE'] > 80 else "🟠" if row['CONFIDENCE_PERCENTAGE'] > 60 else "🟡"
                st.warning(
                    f"{severity} **{row['PATTERN_DESCRIPTION']}**\n\n"
                    f"Region: {row['REGION']} | Age Group: {row['AGE_GROUP']}\n\n"
                    f"Affected Customers: {row['AFFECTED_CUSTOMER_COUNT']} | "
                    f"Confidence: {row['CONFIDENCE_PERCENTAGE']}%"
                )
        else:
            st.success("✅ No significant fraud patterns detected in the last 30 days.")
    
    elif selected_question_id == 'Q005':
        # Occupation risk profiles
        st.subheader("Occupation Risk Analysis")
        
        occupation_query = """
        SELECT 
            occupation_category,
            SUM(record_count) as total_customers,
            ROUND(AVG(composite_risk_score), 2) as avg_risk,
            ROUND(AVG(avg_bank_risk_score), 2) as avg_bank_risk,
            ROUND(AVG(avg_insurance_risk_score), 2) as avg_insurance_risk,
            ROUND((SUM(CASE WHEN risk_category IN ('HIGH', 'CRITICAL') THEN record_count ELSE 0 END) * 100.0 / SUM(record_count)), 1) as high_risk_pct
        FROM ANALYTICS.risk_join_aggregated
        WHERE occupation_category IS NOT NULL
        GROUP BY occupation_category
        HAVING SUM(record_count) >= 3
        ORDER BY avg_risk DESC
        """
        
        occupation_df = run_query(occupation_query)
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Overall risk by occupation
            fig = px.bar(
                occupation_df,
                x='OCCUPATION_CATEGORY',
                y='AVG_RISK',
                title='Average Risk by Occupation',
                color='HIGH_RISK_PCT',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Risk Score', 'OCCUPATION_CATEGORY': 'Occupation'}
            )
            fig.update_xaxis(tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Bank vs Insurance risk
            comparison_df = occupation_df[['OCCUPATION_CATEGORY', 'AVG_BANK_RISK', 'AVG_INSURANCE_RISK']].copy()
            comparison_df = comparison_df.melt(id_vars='OCCUPATION_CATEGORY', var_name='Source', value_name='Risk')
            comparison_df['Source'] = comparison_df['Source'].str.replace('AVG_', '').str.replace('_RISK', '').str.title()
            
            fig = px.bar(
                comparison_df,
                x='OCCUPATION_CATEGORY',
                y='Risk',
                color='Source',
                barmode='group',
                title='Bank vs Insurance Risk by Occupation',
                labels={'Risk': 'Risk Score', 'OCCUPATION_CATEGORY': 'Occupation'}
            )
            fig.update_xaxis(tickangle=-45)
            st.plotly_chart(fig, use_container_width=True)
        
        # Table
        st.markdown("### Occupation Statistics")
        display_df = occupation_df.copy()
        display_df.columns = ['Occupation', 'Customers', 'Avg Risk', 'Bank Risk', 'Insurance Risk', 'High Risk %']
        st.dataframe(display_df, use_container_width=True, hide_index=True)
    
    # Export option
    st.markdown("---")
    st.download_button(
        label="📥 Export Results as CSV",
        data=questions_df.to_csv(index=False),
        file_name=f"crossrisk_question_{selected_question_id}_{pd.Timestamp.now().strftime('%Y%m%d')}.csv",
        mime="text/csv"
    )

except Exception as e:
    st.error(f"Error loading pre-approved questions: {str(e)}")
    st.info("Please ensure the analytics pipeline has been executed and AI insights have been generated.")
