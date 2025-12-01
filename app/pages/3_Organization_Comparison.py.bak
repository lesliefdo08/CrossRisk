import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from Home import run_query

st.set_page_config(page_title="Organization Comparison", page_icon="⚖️", layout="wide")

st.title("⚖️ Organization Comparison")

st.markdown("""
    Compare risk profiles between banking and insurance organizations in a privacy-safe manner. 
    All comparisons use aggregated data only, with strict k-anonymity enforcement.
""")

st.markdown("---")

# Overview comparison
st.subheader("📊 Overall Organization Comparison")

overview_query = """
SELECT 
    'Bank' as organization,
    COUNT(*) as record_count,
    ROUND(AVG(risk_score), 2) as avg_risk_score,
    ROUND(MIN(risk_score), 2) as min_risk,
    ROUND(MAX(risk_score), 2) as max_risk,
    ROUND(STDDEV(risk_score), 2) as risk_stddev
FROM RAW_DATA.bank_customer_risk_summary

UNION ALL

SELECT 
    'Insurance' as organization,
    COUNT(*) as record_count,
    ROUND(AVG(risk_score), 2) as avg_risk_score,
    ROUND(MIN(risk_score), 2) as min_risk,
    ROUND(MAX(risk_score), 2) as max_risk,
    ROUND(STDDEV(risk_score), 2) as risk_stddev
FROM RAW_DATA.insurance_claim_risk_summary
"""

try:
    overview_df = run_query(overview_query)
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.markdown("### 🏦 Banking Organization")
        bank_data = overview_df[overview_df['ORGANIZATION'] == 'Bank'].iloc[0]
        
        metric_col1, metric_col2, metric_col3 = st.columns(3)
        metric_col1.metric("Total Records", f"{bank_data['RECORD_COUNT']:,}")
        metric_col2.metric("Avg Risk Score", f"{bank_data['AVG_RISK_SCORE']}")
        metric_col3.metric("Risk Range", f"{bank_data['MIN_RISK']}-{bank_data['MAX_RISK']}")
        
        st.metric("Risk Std Dev", f"{bank_data['RISK_STDDEV']}")
    
    with col2:
        st.markdown("### 🏥 Insurance Organization")
        insurance_data = overview_df[overview_df['ORGANIZATION'] == 'Insurance'].iloc[0]
        
        metric_col1, metric_col2, metric_col3 = st.columns(3)
        metric_col1.metric("Total Records", f"{insurance_data['RECORD_COUNT']:,}")
        metric_col2.metric("Avg Risk Score", f"{insurance_data['AVG_RISK_SCORE']}")
        metric_col3.metric("Risk Range", f"{insurance_data['MIN_RISK']}-{insurance_data['MAX_RISK']}")
        
        st.metric("Risk Std Dev", f"{insurance_data['RISK_STDDEV']}")
    
    # Side-by-side comparison chart
    st.markdown("### Risk Score Comparison")
    
    comparison_metrics = overview_df[['ORGANIZATION', 'AVG_RISK_SCORE', 'MIN_RISK', 'MAX_RISK']].copy()
    
    fig = go.Figure()
    
    for org in ['Bank', 'Insurance']:
        org_data = comparison_metrics[comparison_metrics['ORGANIZATION'] == org].iloc[0]
        fig.add_trace(go.Bar(
            name=org,
            x=['Average', 'Minimum', 'Maximum'],
            y=[org_data['AVG_RISK_SCORE'], org_data['MIN_RISK'], org_data['MAX_RISK']],
            text=[org_data['AVG_RISK_SCORE'], org_data['MIN_RISK'], org_data['MAX_RISK']],
            textposition='auto'
        ))
    
    fig.update_layout(
        title='Risk Score Metrics Comparison',
        barmode='group',
        yaxis_title='Risk Score',
        xaxis_title='Metric'
    )
    st.plotly_chart(fig, use_container_width=True)
    
    st.markdown("---")
    
    # Regional comparison
    st.subheader("🗺️ Regional Risk Comparison")
    
    regional_query = """
    SELECT 
        region,
        ROUND(AVG(b.risk_score), 2) as bank_avg_risk,
        ROUND(AVG(i.risk_score), 2) as insurance_avg_risk,
        COUNT(DISTINCT b.customer_id) as customer_count,
        ROUND(AVG(b.risk_score) - AVG(i.risk_score), 2) as risk_difference
    FROM RAW_DATA.bank_customer_risk_summary b
    JOIN RAW_DATA.insurance_claim_risk_summary i
        ON b.customer_id = i.customer_id
        AND b.region = i.region
    GROUP BY region
    HAVING COUNT(DISTINCT b.customer_id) >= 3
    ORDER BY region
    """
    
    regional_df = run_query(regional_query)
    
    col1, col2 = st.columns(2)
    
    with col1:
        # Grouped bar chart
        regional_melted = regional_df.melt(
            id_vars=['REGION', 'CUSTOMER_COUNT'],
            value_vars=['BANK_AVG_RISK', 'INSURANCE_AVG_RISK'],
            var_name='Organization',
            value_name='Avg Risk'
        )
        regional_melted['Organization'] = regional_melted['Organization'].str.replace('_AVG_RISK', '').str.replace('_', ' ').str.title()
        
        fig = px.bar(
            regional_melted,
            x='REGION',
            y='Avg Risk',
            color='Organization',
            barmode='group',
            title='Average Risk by Region and Organization',
            labels={'REGION': 'Region', 'Avg Risk': 'Average Risk Score'}
        )
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        # Risk difference chart
        fig = px.bar(
            regional_df,
            x='REGION',
            y='RISK_DIFFERENCE',
            title='Risk Score Difference (Bank - Insurance)',
            color='RISK_DIFFERENCE',
            color_continuous_scale='RdBu_r',
            color_continuous_midpoint=0,
            labels={'RISK_DIFFERENCE': 'Risk Difference', 'REGION': 'Region'}
        )
        fig.add_hline(y=0, line_dash="dash", line_color="gray")
        st.plotly_chart(fig, use_container_width=True)
    
    # Regional table
    st.markdown("### Regional Statistics")
    display_regional = regional_df.copy()
    display_regional.columns = ['Region', 'Bank Avg Risk', 'Insurance Avg Risk', 'Customers', 'Difference']
    st.dataframe(display_regional, use_container_width=True, hide_index=True)
    
    st.markdown("---")
    
    # Age group comparison
    st.subheader("👥 Age Group Risk Comparison")
    
    age_query = """
    SELECT 
        age_group,
        ROUND(AVG(b.risk_score), 2) as bank_avg_risk,
        ROUND(AVG(i.risk_score), 2) as insurance_avg_risk,
        COUNT(DISTINCT b.customer_id) as customer_count,
        ROUND(ABS(AVG(b.risk_score) - AVG(i.risk_score)), 2) as risk_gap
    FROM RAW_DATA.bank_customer_risk_summary b
    JOIN RAW_DATA.insurance_claim_risk_summary i
        ON b.customer_id = i.customer_id
        AND b.age_group = i.age_group
    GROUP BY age_group
    HAVING COUNT(DISTINCT b.customer_id) >= 3
    ORDER BY age_group
    """
    
    age_df = run_query(age_query)
    
    # Line chart comparison
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=age_df['AGE_GROUP'],
        y=age_df['BANK_AVG_RISK'],
        mode='lines+markers',
        name='Bank Risk',
        line=dict(color='#1f77b4', width=3),
        marker=dict(size=10)
    ))
    
    fig.add_trace(go.Scatter(
        x=age_df['AGE_GROUP'],
        y=age_df['INSURANCE_AVG_RISK'],
        mode='lines+markers',
        name='Insurance Risk',
        line=dict(color='#ff7f0e', width=3),
        marker=dict(size=10)
    ))
    
    fig.update_layout(
        title='Risk Score Trends by Age Group',
        xaxis_title='Age Group',
        yaxis_title='Average Risk Score',
        hovermode='x unified'
    )
    
    st.plotly_chart(fig, use_container_width=True)
    
    # Age group table with insights
    st.markdown("### Age Group Analysis")
    
    display_age = age_df.copy()
    display_age.columns = ['Age Group', 'Bank Risk', 'Insurance Risk', 'Customers', 'Risk Gap']
    
    # Add insight column
    display_age['Primary Risk Driver'] = display_age.apply(
        lambda row: 'Banking' if row['Bank Risk'] > row['Insurance Risk'] + 5 
        else 'Insurance' if row['Insurance Risk'] > row['Bank Risk'] + 5 
        else 'Balanced', axis=1
    )
    
    st.dataframe(display_age, use_container_width=True, hide_index=True)
    
    st.markdown("---")
    
    # Correlation analysis
    st.subheader("📈 Risk Correlation Analysis")
    
    correlation_query = """
    SELECT 
        b.age_group,
        b.region,
        b.risk_score as bank_risk,
        i.risk_score as insurance_risk,
        b.fraud_flag_history,
        i.suspicious_claim_flags
    FROM RAW_DATA.bank_customer_risk_summary b
    JOIN RAW_DATA.insurance_claim_risk_summary i
        ON b.customer_id = i.customer_id
    """
    
    correlation_df = run_query(correlation_query)
    
    if not correlation_df.empty:
        col1, col2 = st.columns(2)
        
        with col1:
            # Scatter plot of bank vs insurance risk
            fig = px.scatter(
                correlation_df,
                x='BANK_RISK',
                y='INSURANCE_RISK',
                title='Bank Risk vs Insurance Risk Correlation',
                trendline='ols',
                labels={
                    'BANK_RISK': 'Bank Risk Score',
                    'INSURANCE_RISK': 'Insurance Risk Score'
                },
                opacity=0.6
            )
            
            # Add diagonal line
            fig.add_trace(go.Scatter(
                x=[0, 100],
                y=[0, 100],
                mode='lines',
                line=dict(dash='dash', color='gray'),
                name='Perfect Correlation',
                showlegend=True
            ))
            
            st.plotly_chart(fig, use_container_width=True)
            
            # Calculate correlation coefficient
            correlation = correlation_df[['BANK_RISK', 'INSURANCE_RISK']].corr().iloc[0, 1]
            st.metric("Correlation Coefficient", f"{correlation:.3f}")
            
            if correlation > 0.7:
                st.success("✅ Strong positive correlation - risk signals align well across organizations")
            elif correlation > 0.4:
                st.info("ℹ️ Moderate correlation - some alignment in risk assessment")
            else:
                st.warning("⚠️ Weak correlation - organizations assess risk differently")
        
        with col2:
            # Fraud indicator comparison
            fraud_comparison = pd.DataFrame({
                'Indicator Type': ['Bank Fraud Flags', 'Insurance Claim Flags'],
                'Total Count': [
                    correlation_df['FRAUD_FLAG_HISTORY'].sum(),
                    correlation_df['SUSPICIOUS_CLAIM_FLAGS'].sum()
                ],
                'Affected Customers': [
                    (correlation_df['FRAUD_FLAG_HISTORY'] > 0).sum(),
                    (correlation_df['SUSPICIOUS_CLAIM_FLAGS'] > 0).sum()
                ]
            })
            
            fig = px.bar(
                fraud_comparison,
                x='Indicator Type',
                y='Total Count',
                title='Fraud Indicators by Organization',
                text='Total Count',
                color='Indicator Type',
                labels={'Total Count': 'Number of Flags'}
            )
            fig.update_traces(textposition='outside')
            st.plotly_chart(fig, use_container_width=True)
            
            st.markdown("#### Fraud Overlap Analysis")
            both_flags = ((correlation_df['FRAUD_FLAG_HISTORY'] > 0) & 
                         (correlation_df['SUSPICIOUS_CLAIM_FLAGS'] > 0)).sum()
            
            st.metric(
                "Customers with Flags in Both Organizations",
                f"{both_flags:,}",
                help="Customers showing suspicious activity in both banking and insurance"
            )
    
    st.markdown("---")
    
    # Composite risk insights
    st.subheader("🎯 Combined Risk Insights")
    
    composite_query = """
    SELECT 
        CASE
            WHEN composite_risk_score >= 75 THEN 'CRITICAL'
            WHEN composite_risk_score >= 50 THEN 'HIGH'
            WHEN composite_risk_score >= 25 THEN 'MEDIUM'
            ELSE 'LOW'
        END as composite_risk_category,
        CASE
            WHEN avg_bank_risk_score > avg_insurance_risk_score + 10 THEN 'Bank-Driven'
            WHEN avg_insurance_risk_score > avg_bank_risk_score + 10 THEN 'Insurance-Driven'
            ELSE 'Balanced'
        END as risk_driver,
        COUNT(*) as segment_count,
        SUM(record_count) as customer_count
    FROM ANALYTICS.risk_join_aggregated
    GROUP BY composite_risk_category, risk_driver
    ORDER BY 
        CASE composite_risk_category
            WHEN 'CRITICAL' THEN 1
            WHEN 'HIGH' THEN 2
            WHEN 'MEDIUM' THEN 3
            WHEN 'LOW' THEN 4
        END
    """
    
    composite_df = run_query(composite_query)
    
    if not composite_df.empty:
        # Stacked bar chart
        fig = px.bar(
            composite_df,
            x='COMPOSITE_RISK_CATEGORY',
            y='CUSTOMER_COUNT',
            color='RISK_DRIVER',
            title='Customer Distribution by Risk Category and Driver',
            labels={
                'COMPOSITE_RISK_CATEGORY': 'Composite Risk Category',
                'CUSTOMER_COUNT': 'Number of Customers',
                'RISK_DRIVER': 'Primary Risk Driver'
            },
            color_discrete_map={
                'Bank-Driven': '#1f77b4',
                'Insurance-Driven': '#ff7f0e',
                'Balanced': '#2ca02c'
            }
        )
        st.plotly_chart(fig, use_container_width=True)
        
        # Summary table
        st.markdown("### Risk Driver Distribution")
        display_composite = composite_df.copy()
        display_composite.columns = ['Risk Category', 'Risk Driver', 'Segments', 'Customers']
        st.dataframe(display_composite, use_container_width=True, hide_index=True)
        
        # Key insights
        st.markdown("### 🔍 Key Insights")
        
        total_customers = composite_df['CUSTOMER_COUNT'].sum()
        bank_driven = composite_df[composite_df['RISK_DRIVER'] == 'Bank-Driven']['CUSTOMER_COUNT'].sum()
        insurance_driven = composite_df[composite_df['RISK_DRIVER'] == 'Insurance-Driven']['CUSTOMER_COUNT'].sum()
        balanced = composite_df[composite_df['RISK_DRIVER'] == 'Balanced']['CUSTOMER_COUNT'].sum()
        
        col1, col2, col3 = st.columns(3)
        
        with col1:
            st.metric(
                "Bank-Driven Risk",
                f"{(bank_driven / total_customers * 100):.1f}%",
                f"{bank_driven:,} customers"
            )
        
        with col2:
            st.metric(
                "Insurance-Driven Risk",
                f"{(insurance_driven / total_customers * 100):.1f}%",
                f"{insurance_driven:,} customers"
            )
        
        with col3:
            st.metric(
                "Balanced Risk",
                f"{(balanced / total_customers * 100):.1f}%",
                f"{balanced:,} customers"
            )
    
    # Export options
    st.markdown("---")
    col1, col2 = st.columns(2)
    
    with col1:
        st.download_button(
            label="📥 Export Regional Comparison",
            data=display_regional.to_csv(index=False),
            file_name=f"crossrisk_regional_comparison_{pd.Timestamp.now().strftime('%Y%m%d')}.csv",
            mime="text/csv"
        )
    
    with col2:
        st.download_button(
            label="📥 Export Age Group Comparison",
            data=display_age.to_csv(index=False),
            file_name=f"crossrisk_age_comparison_{pd.Timestamp.now().strftime('%Y%m%d')}.csv",
            mime="text/csv"
        )

except Exception as e:
    st.error(f"Error loading organization comparison data: {str(e)}")
    st.info("Please ensure both bank and insurance data are loaded and the analytics pipeline has been executed.")
