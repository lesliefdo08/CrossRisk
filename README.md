# CrossRisk

**Privacy-Safe Multi-Organization Risk Analytics Platform**

![Snowflake](https://img.shields.io/badge/Snowflake-Powered-29B5E8) ![AI Enabled](https://img.shields.io/badge/AI-Cortex-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## Overview

CrossRisk is a platform built on Snowflake that enables secure cross-organizational risk analytics between banks and insurance companies. It combines financial data from multiple organizations to detect fraud patterns and identify risk correlations while maintaining strict privacy standards through k-anonymity, data masking, and secure clean room architecture.

### The Problem

Banks and insurance companies assess customer risk independently, missing critical fraud signals that only become visible when data is combined. However, sharing raw customer data creates privacy and regulatory risks. CrossRisk solves this by enabling secure data collaboration without exposing individual records.

### The Solution

- Aggregated analytics with k-anonymity (minimum 3 customers per segment)
- Dynamic data masking for PII protection
- Row-level access policies based on risk scores
- Pre-approved query templates to prevent data leakage
- AI-generated explanations using Snowflake Cortex

---

## Key Features

**Privacy Protection**
- K-anonymity enforcement (k≥3)
- Dynamic data masking
- Role-based access control
- Complete audit logging

**Risk Analytics**
- Composite risk scoring across organizations
- Fraud pattern detection
- Regional and demographic risk analysis
- Pre-approved analytics questions

**AI Insights**
- Natural language summaries via Cortex AI
- Anomaly detection
- Risk pattern explanations

**Governance**
- Full audit trail
- Compliance monitoring dashboard
- Access pattern analysis
- Regulatory reporting

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Streamlit Interface                      │
│              (5 pages: Home, Questions, Explorer,           │
│                Comparison, Governance)                       │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│            ANALYTICS Schema (Secure Views)                  │
│  - risk_join_aggregated  - fraud_cross_signals             │
│  - approved_questions_cache                                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│         CLEAN_ROOM Schema (Dynamic Tables + UDFs)          │
│  - bank_insurance_join  - calculate_composite_risk()       │
│  - risk_scoring_engine  - detect_fraud_patterns()          │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│          MASKED_DATA Schema (Masking Policies)             │
│  - masked_bank_customers  - masked_insurance_claims        │
│  - customer_id_mask  - financial_band_mask                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│             RAW_DATA Schema (Source Data)                   │
│  - bank_customer_risk_summary                               │
│  - insurance_claim_risk_summary                             │
└─────────────────────────────────────────────────────────────┘
```

Data flows bottom-up through progressive masking and aggregation layers, ensuring privacy is enforced at every level.

---

## Snowflake Features Used

**Core Platform**
- Dynamic Tables (automated incremental refresh)
- Streams & Tasks (change data capture pipeline)
- Masking Policies (PII protection)
- Row Access Policies (risk-based filtering)
- Data Tagging (PII identification)

**Governance & Security**
- Audit Logging (ACCOUNT_USAGE views)
- Role-Based Access Control
- Secure Views (prevent optimization leakage)

**AI & Analytics**
- Cortex AI (COMPLETE function for text generation)
- User-Defined Functions (custom risk calculations)
- Stored Procedures (business logic)

---

## Getting Started

### Prerequisites

- Snowflake account (Standard tier or above)
- Python 3.8+
- Streamlit

### Setup

1. **Clone the repository**
```bash
git clone https://github.com/lesliefdo08/CrossRisk.git
cd CrossRisk
```

2. **Set up Snowflake**
```bash
# Run SQL setup scripts in order
snowsql -f snowflake/setup.sql
snowsql -f snowflake/schemas.sql
snowsql -f snowflake/masking_policies.sql
snowsql -f snowflake/access_policies.sql
```

3. **Load sample data**
```bash
snowsql -f data/load_bank_data.sql
snowsql -f data/load_insurance_data.sql
```

4. **Configure Streamlit**
```bash
cp .streamlit/secrets.toml.example .streamlit/secrets.toml
# Edit secrets.toml with your Snowflake credentials
```

5. **Install dependencies**
```bash
pip install -r requirements.txt
```

6. **Run the application**
```bash
cd app
streamlit run Home.py
```

The application will open in your browser at `http://localhost:8501`

---

## Running Offline (Demo Mode)

The application includes an offline demo mode with sample data for testing without Snowflake:

```bash
cd app
streamlit run Home.py
```

When Snowflake credentials are missing, the app automatically switches to offline mode using pre-generated sample datasets.

---

## Project Structure

```
CrossRisk/
├── app/
│   ├── Home.py                          # Main dashboard
│   ├── db_connection.py                 # Connection handler with offline fallback
│   ├── utils.py                         # Helper functions
│   └── pages/
│       ├── 1_Pre_Approved_Questions.py  # Curated analytics
│       ├── 2_Risk_Explorer.py           # Interactive filtering
│       ├── 3_Organization_Comparison.py # Bank vs insurance analysis
│       └── 4_Governance_Audit.py        # Compliance monitoring
├── snowflake/
│   ├── setup.sql                        # Database and warehouse setup
│   ├── schemas.sql                      # Schema creation
│   ├── masking_policies.sql             # Data masking rules
│   ├── access_policies.sql              # Row-level security
│   ├── risk_engine.sql                  # Risk calculation UDFs
│   ├── ai_sql_queries.sql               # Cortex AI integration
│   ├── stored_procedures.sql            # Business logic
│   ├── stream_creation.sql              # CDC streams
│   ├── tasks.sql                        # Scheduled jobs
│   ├── dynamic_tables.sql               # Auto-refreshing tables
│   ├── tags.sql                         # PII tagging
│   └── logging.sql                      # Audit logging setup
├── data/
│   ├── load_bank_data.sql               # Bank data loader
│   └── load_insurance_data.sql          # Insurance data loader
├── README.md                            # This file
├── EXEC_SUMMARY.md                      # Executive summary
├── DEMO_SCRIPT.md                       # Demo walkthrough
├── DATA_DICTIONARY.md                   # Data schema documentation
└── requirements.txt                     # Python dependencies
```

---

## Data Flow

1. **Ingestion**: Raw customer data from banking and insurance systems lands in `RAW_DATA` schema
2. **Masking**: PII fields are masked in `MASKED_DATA` schema based on user roles
3. **Joining**: Clean room logic in `CLEAN_ROOM` schema combines data from both organizations
4. **Aggregation**: Dynamic tables in `ANALYTICS` schema aggregate data with k-anonymity
5. **Access**: Streamlit interface queries analytics views with audit logging

---

## Privacy Guarantees

**K-Anonymity (k≥3)**
- All aggregated segments contain at least 3 customers
- Segments below threshold are automatically filtered
- Enforced at query time via SQL constraints

**Dynamic Masking**
- Customer IDs replaced with hashed tokens
- Financial values masked to ranges (e.g., "$50K-$100K")
- Full data only visible to authorized roles

**Row Access Policies**
- High-risk data (score >75) restricted to RISK_ANALYST role
- Critical risk data requires RISK_MANAGER approval
- All access decisions logged

**Secure Clean Room**
- No direct table access permitted
- Only pre-approved query templates allowed
- Views use SECURE flag to prevent optimization leaks

---

## AI Capabilities

**Cortex AI Integration**
- Generates natural language explanations for risk patterns
- Summarizes fraud detection results
- Provides context for anomalies

**Example AI Output**:
```
"Customers aged 45-54 in the Northeast region show elevated risk
scores (avg 67.3) primarily driven by insurance claim patterns.
This segment has 23% higher fraud correlation than the national
average, suggesting enhanced monitoring is warranted."
```

---

## Governance & Compliance

**Audit Logging**
- Every query is logged with user, timestamp, and row count
- Access patterns analyzed for anomalies
- Exportable reports for compliance teams

**Compliance Dashboard**
- Real-time privacy compliance checks
- K-anonymity violation detection
- Policy application monitoring

**Data Lineage**
- Full tracking from raw data to analytics
- Masking policy application documented
- Change history for all transformations

---

## Use Cases

**Fraud Detection**
- Identify customers with high risk in both banking and insurance
- Detect unusual patterns across organizational boundaries
- Flag suspicious activity that wouldn't be visible in isolation

**Risk Assessment**
- Calculate composite risk scores combining multiple data sources
- Identify demographic segments with elevated risk
- Discover regional risk hotspots

**Compliance Monitoring**
- Ensure k-anonymity is maintained across all queries
- Monitor data access patterns for suspicious activity
- Generate audit reports for regulators

---

## Technical Stack

- **Database**: Snowflake
- **Frontend**: Streamlit (Python)
- **Visualization**: Plotly
- **AI**: Snowflake Cortex
- **Languages**: SQL, Python

---

## Performance

- Dynamic tables refresh incrementally (only changed data)
- Secure views optimize queries without exposing data
- Caching reduces redundant Snowflake calls
- Streamlit session state minimizes re-computation

---

## Limitations

- Requires Snowflake Standard tier or above for Cortex AI
- K-anonymity requirement may filter small segments
- Real-time updates limited by dynamic table refresh intervals
- AI summaries depend on Cortex availability

---

## Future Enhancements

- Machine learning models for fraud prediction
- Real-time streaming data ingestion
- Additional organization types (healthcare, retail)
- Enhanced AI explanations with drill-down capabilities
- Mobile-responsive interface

---

## Contributing

This project was built for the Snowflake Hackathon. Contributions are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

## License

MIT License - see LICENSE file for details

---

## Contact

Leslie Fernando  
GitHub: [@lesliefdo08](https://github.com/lesliefdo08)

---

## Acknowledgments

- Built on Snowflake platform
- Uses Snowflake Cortex AI
- Inspired by privacy-preserving data collaboration research
- Sample data generated for demonstration purposes

---

**Built for Snowflake Hackathon 2024**
