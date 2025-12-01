import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from Home import run_query

st.set_page_config(page_title="Risk Explorer", page_icon="🔍", layout="wide")

st.title("🔍 Risk Explorer")

st.markdown("""
    Explore risk patterns across different customer segments with interactive filters. 
    All data is privacy-protected with k-anonymity guarantees (minimum 3 customers per segment).
""")

st.markdown("---")

# Sidebar filters
st.sidebar.title("🎯 Filter Options")

# Get available filter values
age_groups_query = "SELECT DISTINCT age_group FROM ANALYTICS.risk_join_aggregated ORDER BY age_group"
regions_query = "SELECT DISTINCT region FROM ANALYTICS.risk_join_aggregated ORDER BY region"
occupations_query = "SELECT DISTINCT occupation_category FROM ANALYTICS.risk_join_aggregated WHERE occupation_category IS NOT NULL ORDER BY occupation_category"
risk_categories_query = "SELECT DISTINCT risk_category FROM ANALYTICS.risk_join_aggregated ORDER BY CASE risk_category WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 END"

try:
    age_groups = run_query(age_groups_query)['AGE_GROUP'].tolist()
    regions = run_query(regions_query)['REGION'].tolist()
    occupations = run_query(occupations_query)['OCCUPATION_CATEGORY'].tolist()
    risk_categories = run_query(risk_categories_query)['RISK_CATEGORY'].tolist()
    
    # Filter controls
    selected_age_groups = st.sidebar.multiselect(
        "Age Group",
        options=age_groups,
        default=age_groups,
        help="Select one or more age groups"
    )
    
    selected_regions = st.sidebar.multiselect(
        "Region",
        options=regions,
        default=regions,
        help="Select one or more regions"
    )
    
    selected_occupations = st.sidebar.multiselect(
        "Occupation",
        options=occupations,
        default=occupations,
        help="Select one or more occupations"
    )
    
    selected_risk_categories = st.sidebar.multiselect(
        "Risk Category",
        options=risk_categories,
        default=risk_categories,
        help="Filter by risk level"
    )
    
    # Risk score range slider
    risk_score_range = st.sidebar.slider(
        "Risk Score Range",
        min_value=0,
        max_value=100,
        value=(0, 100),
        help="Filter by composite risk score"
    )
    
    st.sidebar.markdown("---")
    
    # Minimum customer count filter for privacy
    min_customers = st.sidebar.number_input(
        "Minimum Customers per Segment",
        min_value=3,
        max_value=50,
        value=3,
        help="Privacy filter: only show segments with at least this many customers"
    )
    
    # Build dynamic query with filters
    filters = []
    
    if selected_age_groups:
        age_filter = "', '".join(selected_age_groups)
        filters.append(f"age_group IN ('{age_filter}')")
    
    if selected_regions:
        region_filter = "', '".join(selected_regions)
        filters.append(f"region IN ('{region_filter}')")
    
    if selected_occupations:
        occupation_filter = "', '".join(selected_occupations)
        filters.append(f"occupation_category IN ('{occupation_filter}')")
    
    if selected_risk_categories:
        risk_cat_filter = "', '".join(selected_risk_categories)
        filters.append(f"risk_category IN ('{risk_cat_filter}')")
    
    filters.append(f"composite_risk_score BETWEEN {risk_score_range[0]} AND {risk_score_range[1]}")
    filters.append(f"record_count >= {min_customers}")
    
    where_clause = " AND ".join(filters)
    
    # Main query
    main_query = f"""
    SELECT 
        analysis_id,
        age_group,
        region,
        occupation_category,
        record_count,
        ROUND(composite_risk_score, 2) as composite_risk_score,
        risk_category,
        ROUND(avg_bank_risk_score, 2) as avg_bank_risk_score,
        ROUND(avg_insurance_risk_score, 2) as avg_insurance_risk_score,
        ROUND(fraud_correlation_score, 2) as fraud_correlation_score
    FROM ANALYTICS.risk_join_aggregated
    WHERE {where_clause}
    ORDER BY composite_risk_score DESC
    """
    
    results_df = run_query(main_query)
    
    if results_df.empty:
        st.warning("⚠️ No segments match the selected filters. Try adjusting your criteria.")
        st.stop()
    
    # Summary metrics
    st.subheader("📊 Filtered Results Summary")
    
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric("Matching Segments", f"{len(results_df):,}")
    
    with col2:
        st.metric("Total Customers", f"{results_df['RECORD_COUNT'].sum():,}")
    
    with col3:
        st.metric("Average Risk Score", f"{results_df['COMPOSITE_RISK_SCORE'].mean():.2f}")
    
    with col4:
        high_risk_count = results_df[results_df['RISK_CATEGORY'].isin(['HIGH', 'CRITICAL'])]['RECORD_COUNT'].sum()
        st.metric("High Risk Customers", f"{high_risk_count:,}")
    
    st.markdown("---")
    
    # Visualization tabs
    tab1, tab2, tab3, tab4 = st.tabs(["📈 Risk Distribution", "🗺️ Regional View", "👥 Age Analysis", "💼 Occupation View"])
    
    with tab1:
        st.subheader("Risk Score Distribution")
        
        col1, col2 = st.columns(2)
        
        with col1:
            # Histogram of risk scores
            fig = px.histogram(
                results_df,
                x='COMPOSITE_RISK_SCORE',
                nbins=20,
                title='Risk Score Distribution',
                color_discrete_sequence=['#1f77b4'],
                labels={'COMPOSITE_RISK_SCORE': 'Composite Risk Score', 'count': 'Number of Segments'}
            )
            fig.add_vline(x=results_df['COMPOSITE_RISK_SCORE'].mean(), 
                         line_dash="dash", line_color="red",
                         annotation_text=f"Mean: {results_df['COMPOSITE_RISK_SCORE'].mean():.2f}")
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            # Risk category pie chart
            risk_cat_counts = results_df['RISK_CATEGORY'].value_counts().reset_index()
            risk_cat_counts.columns = ['RISK_CATEGORY', 'COUNT']
            
            fig = px.pie(
                risk_cat_counts,
                values='COUNT',
                names='RISK_CATEGORY',
                title='Segments by Risk Category',
                color='RISK_CATEGORY',
                color_discrete_map={
                    'CRITICAL': '#d62728',
                    'HIGH': '#ff7f0e',
                    'MEDIUM': '#ffbb78',
                    'LOW': '#2ca02c'
                }
            )
            st.plotly_chart(fig, use_container_width=True)
        
        # Bank vs Insurance risk scatter
        st.markdown("### Bank vs Insurance Risk Comparison")
        fig = px.scatter(
            results_df,
            x='AVG_BANK_RISK_SCORE',
            y='AVG_INSURANCE_RISK_SCORE',
            color='RISK_CATEGORY',
            size='RECORD_COUNT',
            hover_data=['AGE_GROUP', 'REGION', 'OCCUPATION_CATEGORY'],
            title='Banking Risk vs Insurance Risk',
            color_discrete_map={
                'CRITICAL': '#d62728',
                'HIGH': '#ff7f0e',
                'MEDIUM': '#ffbb78',
                'LOW': '#2ca02c'
            },
            labels={
                'AVG_BANK_RISK_SCORE': 'Bank Risk Score',
                'AVG_INSURANCE_RISK_SCORE': 'Insurance Risk Score'
            }
        )
        # Add diagonal reference line
        fig.add_trace(go.Scatter(
            x=[0, 100],
            y=[0, 100],
            mode='lines',
            line=dict(dash='dash', color='gray'),
            name='Equal Risk Line',
            showlegend=True
        ))
        st.plotly_chart(fig, use_container_width=True)
    
    with tab2:
        st.subheader("Regional Risk Analysis")
        
        regional_summary = results_df.groupby('REGION').agg({
            'RECORD_COUNT': 'sum',
            'COMPOSITE_RISK_SCORE': 'mean',
            'FRAUD_CORRELATION_SCORE': 'mean'
        }).reset_index()
        regional_summary.columns = ['REGION', 'CUSTOMERS', 'AVG_RISK', 'AVG_FRAUD_CORRELATION']
        regional_summary = regional_summary.round(2)
        
        col1, col2 = st.columns(2)
        
        with col1:
            fig = px.bar(
                regional_summary,
                x='REGION',
                y='AVG_RISK',
                color='AVG_RISK',
                title='Average Risk by Region',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Average Risk Score', 'REGION': 'Region'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            fig = px.scatter(
                regional_summary,
                x='CUSTOMERS',
                y='AVG_RISK',
                size='CUSTOMERS',
                text='REGION',
                title='Risk vs Customer Volume by Region',
                labels={'CUSTOMERS': 'Number of Customers', 'AVG_RISK': 'Average Risk'}
            )
            fig.update_traces(textposition='top center')
            st.plotly_chart(fig, use_container_width=True)
        
        st.dataframe(regional_summary, use_container_width=True, hide_index=True)
    
    with tab3:
        st.subheader("Age Group Analysis")
        
        age_summary = results_df.groupby('AGE_GROUP').agg({
            'RECORD_COUNT': 'sum',
            'COMPOSITE_RISK_SCORE': 'mean',
            'AVG_BANK_RISK_SCORE': 'mean',
            'AVG_INSURANCE_RISK_SCORE': 'mean'
        }).reset_index()
        age_summary.columns = ['AGE_GROUP', 'CUSTOMERS', 'AVG_RISK', 'AVG_BANK_RISK', 'AVG_INSURANCE_RISK']
        age_summary = age_summary.round(2)
        
        # Grouped bar chart
        melted_age = age_summary.melt(
            id_vars=['AGE_GROUP', 'CUSTOMERS'],
            value_vars=['AVG_BANK_RISK', 'AVG_INSURANCE_RISK'],
            var_name='Risk Type',
            value_name='Risk Score'
        )
        melted_age['Risk Type'] = melted_age['Risk Type'].str.replace('AVG_', '').str.replace('_RISK', '').str.title()
        
        fig = px.bar(
            melted_age,
            x='AGE_GROUP',
            y='Risk Score',
            color='Risk Type',
            barmode='group',
            title='Bank vs Insurance Risk by Age Group',
            labels={'AGE_GROUP': 'Age Group', 'Risk Score': 'Average Risk Score'}
        )
        st.plotly_chart(fig, use_container_width=True)
        
        st.dataframe(age_summary, use_container_width=True, hide_index=True)
    
    with tab4:
        st.subheader("Occupation Analysis")
        
        occupation_summary = results_df.groupby('OCCUPATION_CATEGORY').agg({
            'RECORD_COUNT': 'sum',
            'COMPOSITE_RISK_SCORE': 'mean',
            'FRAUD_CORRELATION_SCORE': 'mean'
        }).reset_index()
        occupation_summary.columns = ['OCCUPATION', 'CUSTOMERS', 'AVG_RISK', 'FRAUD_CORRELATION']
        occupation_summary = occupation_summary.round(2).sort_values('AVG_RISK', ascending=False)
        
        col1, col2 = st.columns([2, 1])
        
        with col1:
            fig = px.bar(
                occupation_summary,
                y='OCCUPATION',
                x='AVG_RISK',
                orientation='h',
                color='AVG_RISK',
                title='Average Risk by Occupation',
                color_continuous_scale='RdYlGn_r',
                labels={'AVG_RISK': 'Average Risk Score', 'OCCUPATION': 'Occupation'}
            )
            st.plotly_chart(fig, use_container_width=True)
        
        with col2:
            st.markdown("### Top 5 Highest Risk")
            for _, row in occupation_summary.head(5).iterrows():
                st.metric(
                    row['OCCUPATION'],
                    f"{row['AVG_RISK']:.2f}",
                    f"{row['CUSTOMERS']} customers"
                )
        
        st.dataframe(occupation_summary, use_container_width=True, hide_index=True)
    
    st.markdown("---")
    
    # Detailed segment table
    st.subheader("📋 Detailed Segment Data")
    
    # Format for display
    display_df = results_df.copy()
    display_df = display_df.drop('ANALYSIS_ID', axis=1)
    display_df.columns = ['Age Group', 'Region', 'Occupation', 'Customers', 'Risk Score', 
                          'Risk Category', 'Bank Risk', 'Insurance Risk', 'Fraud Correlation']
    
    # Color code risk categories
    def color_risk(val):
        if val == 'CRITICAL':
            return 'background-color: #ffcccc'
        elif val == 'HIGH':
            return 'background-color: #ffe6cc'
        elif val == 'MEDIUM':
            return 'background-color: #ffffcc'
        else:
            return 'background-color: #ccffcc'
    
    styled_df = display_df.style.applymap(color_risk, subset=['Risk Category'])
    st.dataframe(styled_df, use_container_width=True, hide_index=True)
    
    # Export option
    st.download_button(
        label="📥 Export Filtered Data as CSV",
        data=display_df.to_csv(index=False),
        file_name=f"crossrisk_filtered_segments_{pd.Timestamp.now().strftime('%Y%m%d_%H%M')}.csv",
        mime="text/csv"
    )
    
    # AI Insight for selected segment
    st.markdown("---")
    st.subheader("🤖 AI Risk Analysis")
    
    if st.button("Generate AI Explanation for Top Risk Segment"):
        with st.spinner("Generating AI analysis..."):
            top_segment = results_df.iloc[0]
            
            ai_query = f"""
            SELECT explain_risk_anomaly(
                '{top_segment['AGE_GROUP']}',
                '{top_segment['REGION']}',
                {top_segment['COMPOSITE_RISK_SCORE']}
            ) as explanation
            """
            
            try:
                ai_result = run_query(ai_query)
                if not ai_result.empty:
                    st.info(f"**AI Analysis for {top_segment['AGE_GROUP']} in {top_segment['REGION']}:**\n\n{ai_result['EXPLANATION'].values[0]}")
                else:
                    st.info(f"**Top Risk Segment:** {top_segment['AGE_GROUP']} customers in {top_segment['REGION']} "
                           f"with a composite risk score of {top_segment['COMPOSITE_RISK_SCORE']:.2f}. "
                           f"This segment includes {top_segment['RECORD_COUNT']} customers and shows "
                           f"{'elevated' if top_segment['FRAUD_CORRELATION_SCORE'] > 0.5 else 'normal'} fraud correlation patterns.")
            except:
                st.info(f"**Top Risk Segment:** {top_segment['AGE_GROUP']} customers in {top_segment['REGION']} "
                       f"show elevated risk patterns with a score of {top_segment['COMPOSITE_RISK_SCORE']:.2f}. "
                       f"This segment requires enhanced monitoring and risk mitigation strategies.")

except Exception as e:
    st.error(f"Error loading risk explorer data: {str(e)}")
    st.info("Please ensure you have appropriate permissions and the analytics tables are populated.")
