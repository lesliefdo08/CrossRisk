"""
Utility functions for the CrossRisk Streamlit application.
Provides database connection helpers, data formatting, and visualization utilities.
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from typing import Optional, List, Dict, Any
import json

def format_risk_score(score: float) -> str:
    """
    Format risk score with color coding.
    
    Args:
        score: Risk score value (0-100)
    
    Returns:
        HTML formatted string with color
    """
    if score >= 75:
        color = "#d62728"  # Red
        category = "CRITICAL"
    elif score >= 50:
        color = "#ff7f0e"  # Orange
        category = "HIGH"
    elif score >= 25:
        color = "#ffbb78"  # Light orange
        category = "MEDIUM"
    else:
        color = "#2ca02c"  # Green
        category = "LOW"
    
    return f'<span style="color: {color}; font-weight: bold;">{score:.2f} ({category})</span>'

def create_risk_gauge(score: float, title: str = "Risk Score") -> go.Figure:
    """
    Create a gauge chart for risk score visualization.
    
    Args:
        score: Risk score value (0-100)
        title: Chart title
    
    Returns:
        Plotly figure object
    """
    fig = go.Figure(go.Indicator(
        mode="gauge+number+delta",
        value=score,
        domain={'x': [0, 1], 'y': [0, 1]},
        title={'text': title},
        delta={'reference': 50},
        gauge={
            'axis': {'range': [None, 100]},
            'bar': {'color': "darkblue"},
            'steps': [
                {'range': [0, 25], 'color': "#ccffcc"},
                {'range': [25, 50], 'color': "#ffffcc"},
                {'range': [50, 75], 'color': "#ffcccc"},
                {'range': [75, 100], 'color': "#ff9999"}
            ],
            'threshold': {
                'line': {'color': "red", 'width': 4},
                'thickness': 0.75,
                'value': 75
            }
        }
    ))
    
    fig.update_layout(height=300)
    return fig

def create_trend_indicator(current: float, previous: float, 
                          label: str = "Change") -> str:
    """
    Create a trend indicator with arrow and percentage change.
    
    Args:
        current: Current value
        previous: Previous value
        label: Label for the metric
    
    Returns:
        HTML formatted trend indicator
    """
    if previous == 0:
        return label
    
    change = ((current - previous) / previous) * 100
    
    if change > 0:
        arrow = "↑"
        color = "#d62728"  # Red for increase (bad for risk)
    elif change < 0:
        arrow = "↓"
        color = "#2ca02c"  # Green for decrease (good for risk)
    else:
        arrow = "→"
        color = "#666"
    
    return f'{label} <span style="color: {color}; font-weight: bold;">{arrow} {abs(change):.1f}%</span>'

def format_large_number(num: int) -> str:
    """
    Format large numbers with K, M, B suffixes.
    
    Args:
        num: Number to format
    
    Returns:
        Formatted string
    """
    if num >= 1_000_000_000:
        return f"{num / 1_000_000_000:.1f}B"
    elif num >= 1_000_000:
        return f"{num / 1_000_000:.1f}M"
    elif num >= 1_000:
        return f"{num / 1_000:.1f}K"
    else:
        return str(num)

def create_privacy_badge(segment_size: int, min_k: int = 3) -> str:
    """
    Create a privacy compliance badge for segment size.
    
    Args:
        segment_size: Number of customers in segment
        min_k: Minimum k for k-anonymity
    
    Returns:
        HTML formatted badge
    """
    if segment_size >= min_k:
        return f'<span style="background-color: #2ca02c; color: white; padding: 3px 8px; border-radius: 3px;">COMPLIANT - Privacy Protected (k={segment_size})</span>'
    else:
        return f'<span style="background-color: #d62728; color: white; padding: 3px 8px; border-radius: 3px;">WARNING - Below k-anonymity threshold</span>'

def calculate_risk_distribution(df: pd.DataFrame, 
                                risk_column: str = 'COMPOSITE_RISK_SCORE') -> Dict[str, int]:
    """
    Calculate risk category distribution from DataFrame.
    
    Args:
        df: DataFrame with risk scores
        risk_column: Name of risk score column
    
    Returns:
        Dictionary with risk category counts
    """
    distribution = {
        'LOW': 0,
        'MEDIUM': 0,
        'HIGH': 0,
        'CRITICAL': 0
    }
    
    for score in df[risk_column]:
        if score >= 75:
            distribution['CRITICAL'] += 1
        elif score >= 50:
            distribution['HIGH'] += 1
        elif score >= 25:
            distribution['MEDIUM'] += 1
        else:
            distribution['LOW'] += 1
    
    return distribution

def create_comparison_table(org1_data: Dict, org2_data: Dict, 
                           org1_name: str = "Organization 1",
                           org2_name: str = "Organization 2") -> pd.DataFrame:
    """
    Create a comparison table for two organizations.
    
    Args:
        org1_data: Dictionary with org1 metrics
        org2_data: Dictionary with org2 metrics
        org1_name: Name of first organization
        org2_name: Name of second organization
    
    Returns:
        Comparison DataFrame
    """
    comparison = pd.DataFrame({
        'Metric': list(org1_data.keys()),
        org1_name: list(org1_data.values()),
        org2_name: list(org2_data.values())
    })
    
    return comparison

def apply_k_anonymity_filter(df: pd.DataFrame, 
                             group_columns: List[str],
                             count_column: str = 'record_count',
                             min_k: int = 3) -> pd.DataFrame:
    """
    Apply k-anonymity filter to DataFrame.
    
    Args:
        df: Input DataFrame
        group_columns: Columns to group by
        count_column: Column containing record counts
        min_k: Minimum k for k-anonymity
    
    Returns:
        Filtered DataFrame meeting k-anonymity requirement
    """
    return df[df[count_column] >= min_k].copy()

def generate_risk_summary(df: pd.DataFrame) -> str:
    """
    Generate a text summary of risk metrics from DataFrame.
    
    Args:
        df: DataFrame with risk data
    
    Returns:
        Summary string
    """
    total_segments = len(df)
    total_customers = df['RECORD_COUNT'].sum() if 'RECORD_COUNT' in df.columns else 0
    avg_risk = df['COMPOSITE_RISK_SCORE'].mean() if 'COMPOSITE_RISK_SCORE' in df.columns else 0
    
    distribution = calculate_risk_distribution(df)
    
    summary = f"""
    **Risk Analytics Summary**
    
    - Total Segments Analyzed: {total_segments:,}
    - Total Customers: {total_customers:,}
    - Average Risk Score: {avg_risk:.2f}
    - Risk Distribution:
        - Critical: {distribution['CRITICAL']} segments
        - High: {distribution['HIGH']} segments
        - Medium: {distribution['MEDIUM']} segments
        - Low: {distribution['LOW']} segments
    """
    
    return summary

def export_to_json(df: pd.DataFrame, filename: str = "export.json") -> str:
    """
    Convert DataFrame to JSON format for export.
    
    Args:
        df: DataFrame to export
        filename: Output filename
    
    Returns:
        JSON string
    """
    return df.to_json(orient='records', indent=2)

def create_heatmap(df: pd.DataFrame, 
                   x_column: str,
                   y_column: str,
                   value_column: str,
                   title: str = "Risk Heatmap") -> go.Figure:
    """
    Create a heatmap visualization.
    
    Args:
        df: DataFrame with data
        x_column: Column for x-axis
        y_column: Column for y-axis
        value_column: Column for heatmap values
        title: Chart title
    
    Returns:
        Plotly figure object
    """
    pivot_df = df.pivot_table(
        values=value_column,
        index=y_column,
        columns=x_column,
        aggfunc='mean'
    )
    
    fig = px.imshow(
        pivot_df,
        labels=dict(x=x_column, y=y_column, color=value_column),
        title=title,
        color_continuous_scale='RdYlGn_r'
    )
    
    return fig

def validate_data_quality(df: pd.DataFrame) -> Dict[str, Any]:
    """
    Validate data quality and return quality metrics.
    
    Args:
        df: DataFrame to validate
    
    Returns:
        Dictionary with quality metrics
    """
    metrics = {
        'total_rows': len(df),
        'total_columns': len(df.columns),
        'missing_values': df.isnull().sum().sum(),
        'duplicate_rows': df.duplicated().sum(),
        'completeness_pct': ((df.size - df.isnull().sum().sum()) / df.size * 100),
        'columns_with_missing': df.columns[df.isnull().any()].tolist()
    }
    
    return metrics

def format_timestamp(timestamp: pd.Timestamp, format: str = '%Y-%m-%d %H:%M:%S') -> str:
    """
    Format timestamp for display.
    
    Args:
        timestamp: Pandas timestamp
        format: Desired format string
    
    Returns:
        Formatted string
    """
    return timestamp.strftime(format)

def create_metric_card(title: str, value: str, delta: Optional[str] = None,
                      delta_color: str = "normal") -> None:
    """
    Create a metric card using Streamlit.
    
    Args:
        title: Metric title
        value: Metric value
        delta: Optional delta indicator
        delta_color: Color for delta (normal, inverse, off)
    """
    st.metric(label=title, value=value, delta=delta, delta_color=delta_color)

# Risk category color mapping
RISK_COLORS = {
    'CRITICAL': '#d62728',
    'HIGH': '#ff7f0e',
    'MEDIUM': '#ffbb78',
    'LOW': '#2ca02c'
}

# Status colors
STATUS_COLORS = {
    'PASSED': '#2ca02c',
    'WARNING': '#ff7f0e',
    'FAILED': '#d62728',
    'ACTIVE': '#1f77b4',
    'INACTIVE': '#7f7f7f'
}

def get_risk_color(category: str) -> str:
    """Get color code for risk category."""
    return RISK_COLORS.get(category.upper(), '#666666')

def get_status_color(status: str) -> str:
    """Get color code for status."""
    return STATUS_COLORS.get(status.upper(), '#666666')
