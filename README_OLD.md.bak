# CrossRisk Platform

**Privacy-Safe Multi-Organization Cross-Risk Insights Platform**

![CrossRisk Logo](https://img.shields.io/badge/CrossRisk-v1.0-blue) ![Snowflake](https://img.shields.io/badge/Snowflake-Powered-29B5E8) ![AI Enabled](https://img.shields.io/badge/AI-Cortex%20Enabled-orange) ![License](https://img.shields.io/badge/license-MIT-green)

---

## 🎯 Overview

CrossRisk is an innovative platform built entirely within Snowflake that enables secure, privacy-preserving cross-organizational risk analytics. By combining banking and insurance data, CrossRisk detects fraud patterns, identifies risk correlations, and generates actionable insights—all while maintaining strict privacy standards through k-anonymity, dynamic masking, and secure clean room technology.

### The Problem We Solve

Financial institutions and insurance companies independently assess customer risk, missing critical cross-organizational signals that could indicate fraud, elevated risk, or emerging patterns. Sharing raw customer data poses severe privacy and regulatory risks. CrossRisk solves this by:

- **Enabling secure data collaboration** without exposing individual customer records
- **Detecting fraud patterns** that only become visible across organizational boundaries
- **Maintaining compliance** with GDPR, CCPA, and financial privacy regulations
- **Leveraging AI** to explain risk patterns in plain English

---

## ✨ Key Features

### 🔒 Privacy-First Architecture
- **K-Anonymity Enforcement**: All aggregations require minimum 3 customers per group
- **Dynamic Data Masking**: Automatic PII protection based on user roles
- **Row Access Policies**: Risk-based data access control
- **Secure Clean Room**: Pre-approved query templates prevent data leakage

### 🤖 AI-Powered Insights
- **Natural Language Summaries**: Snowflake Cortex generates human-readable explanations
- **Anomaly Detection**: AI identifies unusual risk patterns automatically
- **Pre-Approved Questions**: Curated analytics with AI interpretations
- **Fraud Pattern Recognition**: Cross-organizational fraud signal detection

### 📊 Comprehensive Analytics
- **Composite Risk Scoring**: Weighted combination of banking and insurance risk
- **Regional Risk Trends**: Geographic risk hotspot identification
- **Age Group Analysis**: Demographic risk profiling
- **Occupation Risk Patterns**: Industry-specific risk insights

### 🎛️ Full Governance & Compliance
- **Complete Audit Trail**: Every data access logged and monitored
- **Compliance Dashboard**: Real-time privacy compliance monitoring
- **Access Anomaly Detection**: Automatic flagging of suspicious activity
- **Regulatory Reporting**: Exportable audit reports for compliance teams

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     CROSSRISK PLATFORM                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐           ┌──────────────┐                  │
│  │   Bank       │           │  Insurance   │                  │
│  │   Data       │──────┬────│  Data        │                  │
│  │  (Masked)    │      │    │  (Masked)    │                  │
│  └──────────────┘      │    └──────────────┘                  │
│                        │                                        │
│                        ↓                                        │
│              ┌──────────────────┐                              │
│              │  SECURE CLEAN    │                              │
│              │      ROOM        │                              │
│              │  • Masking       │                              │
│              │  • K-Anonymity   │                              │
│              │  • Access Control│                              │
│              └──────────────────┘                              │
│                        ↓                                        │
│              ┌──────────────────┐                              │
│              │  ANALYTICS       │                              │
│              │   ENGINE         │                              │
│              │  • Risk Scoring  │                              │
│              │  • Fraud Detect  │                              │
│              │  • Aggregations  │                              │
│              └──────────────────┘                              │
│                        ↓                                        │
│         ┌────────────────────────────┐                         │
│         │   AI INSIGHTS              │                         │
│         │   (Snowflake Cortex)       │                         │
│         │  • NLP Summaries           │                         │
│         │  • Anomaly Explanation     │                         │
│         └────────────────────────────┘                         │
│                        ↓                                        │
│         ┌────────────────────────────┐                         │
│         │   STREAMLIT APP            │                         │
│         │  • Interactive Dashboard   │                         │
│         │  • Risk Explorer           │                         │
│         │  • Governance Logs         │                         │
│         └────────────────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Technology Stack

- **Database**: Snowflake (Database, Schemas, Tables, Dynamic Tables)
- **Data Governance**: Snowflake Horizon (Masking, Tags, Access Policies)
- **AI/ML**: Snowflake Cortex (LLM for natural language generation)
- **Automation**: Snowflake Streams & Tasks
- **Frontend**: Streamlit (Native Snowflake Integration)
- **Languages**: SQL, Python

---

## 🚀 Quick Start

### Prerequisites

- Snowflake account with:
  - ACCOUNTADMIN or similar privileges
  - Cortex AI features enabled
  - Streamlit in Snowflake enabled

### Installation Steps

#### 1. Database Setup

```sql
-- Execute setup scripts in order
snowsql -f snowflake/setup.sql
snowsql -f snowflake/schemas.sql
snowsql -f snowflake/masking_policies.sql
```

#### 2. Load Sample Data

```sql
-- Upload CSV files to Snowflake stage
PUT file://snowflake/sample_data/bank_data.csv @CROSSRISK_STAGE AUTO_COMPRESS=FALSE;
PUT file://snowflake/sample_data/insurance_data.csv @CROSSRISK_STAGE AUTO_COMPRESS=FALSE;

-- Load data into tables
CALL load_bank_data();
CALL load_insurance_data();
```

#### 3. Initialize Analytics

```sql
-- Run analytics setup
snowsql -f snowflake/analytics/risk_engine.sql
snowsql -f snowflake/analytics/stored_procedures.sql
snowsql -f snowflake/analytics/ai_sql_queries.sql

-- Execute initial calculations
CALL run_complete_data_refresh();
```

#### 4. Setup Automation

```sql
-- Create streams and tasks
snowsql -f snowflake/tasks/stream_creation.sql
snowsql -f snowflake/tasks/tasks.sql
snowsql -f snowflake/tasks/dynamic_tables.sql

-- Activate automation (optional)
CALL resume_all_tasks();
```

#### 5. Configure Governance

```sql
-- Apply governance policies
snowsql -f snowflake/governance/tags.sql
snowsql -f snowflake/governance/access_policies.sql
snowsql -f snowflake/governance/logging.sql
```

#### 6. Deploy Streamlit App

1. Navigate to Snowflake UI → Streamlit
2. Create new Streamlit app
3. Upload files from `app/` directory
4. Set main file as `Home.py`
5. Configure Snowflake connection
6. Run app

---

## 📖 Usage Guide

### For Analysts

**Risk Explorer**: Filter and analyze risk segments across multiple dimensions
```
1. Navigate to "Risk Explorer"
2. Apply filters (age group, region, occupation)
3. Adjust risk score range
4. View visualizations and export data
```

**Pre-Approved Questions**: Access curated analytics with AI explanations
```
1. Navigate to "Pre-Approved Questions"
2. Select question category
3. Choose specific question
4. View results with AI-generated insights
```

### For Risk Managers

**Organization Comparison**: Compare risk profiles between institutions
```
1. Navigate to "Organization Comparison"
2. View side-by-side metrics
3. Analyze correlation patterns
4. Identify cross-organizational fraud signals
```

**Governance Dashboard**: Monitor compliance and access patterns
```
1. Navigate to "Governance & Audit"
2. Review compliance status
3. Check access audit logs
4. Generate compliance reports
```

### For Data Scientists

**Custom Analytics**: Execute approved queries in clean room
```sql
-- Example: Regional fraud correlation
SELECT 
    region,
    AVG(fraud_correlation_score) as avg_correlation,
    COUNT(*) as segment_count
FROM ANALYTICS.risk_join_aggregated
WHERE record_count >= 3  -- k-anonymity
GROUP BY region;
```

---

## 🔐 Security & Privacy

### Privacy Protections

1. **K-Anonymity (k≥3)**: All aggregations contain minimum 3 customers
2. **Dynamic Masking**: PII automatically masked based on user role
3. **Row-Level Security**: Access restricted by risk score and role
4. **Secure Views**: Clean room prevents raw data access
5. **Audit Logging**: Complete trail of all data access

### Compliance Features

- **GDPR**: Right to erasure, data minimization, purpose limitation
- **CCPA**: Consumer privacy rights, data disclosure
- **SOX**: Audit trails, access controls
- **Financial Privacy**: Customer data protection, consent management

### Data Flow Controls

```
Raw Data → Masking Policies → Aggregation (k≥3) → Secure Views → Applications
             ↓                      ↓                   ↓
         Row Access           K-Anonymity        Clean Room
           Policies            Enforcement        Templates
```

---

## 📊 Sample Insights

### Detected Patterns

1. **Cross-Org Fraud Correlation**: Customers with both banking fraud flags and suspicious insurance claims
2. **Regional Risk Concentration**: Geographic areas with elevated composite risk
3. **Age-Based Risk Drivers**: Demographic segments showing distinct risk patterns
4. **Occupation Risk Profiles**: Industry-specific risk characteristics

### AI-Generated Explanations

> "The 25-34 age group in the West region shows elevated risk (score: 68.4) primarily driven by high transaction velocity combined with multiple insurance claim flags. This pattern suggests potential fraud coordination and warrants immediate investigation."

---

## 🛠️ Development

### Project Structure

```
CrossRisk/
├── snowflake/
│   ├── setup.sql                    # Database initialization
│   ├── schemas.sql                  # Table definitions
│   ├── masking_policies.sql         # Privacy controls
│   ├── sample_data/
│   │   ├── bank_data.csv           # Sample bank records
│   │   └── insurance_data.csv      # Sample insurance records
│   ├── analytics/
│   │   ├── risk_engine.sql         # Core analytics logic
│   │   ├── stored_procedures.sql   # Utility procedures
│   │   └── ai_sql_queries.sql      # Cortex AI functions
│   ├── tasks/
│   │   ├── stream_creation.sql     # Change data capture
│   │   ├── tasks.sql               # Automated jobs
│   │   └── dynamic_tables.sql      # Real-time aggregations
│   └── governance/
│       ├── tags.sql                # Data classification
│       ├── access_policies.sql     # RBAC configuration
│       └── logging.sql             # Audit trail setup
├── app/
│   ├── Home.py                      # Main dashboard
│   ├── utils.py                     # Shared utilities
│   └── pages/
│       ├── 1_Pre_Approved_Questions.py
│       ├── 2_Risk_Explorer.py
│       ├── 3_Organization_Comparison.py
│       └── 4_Governance_Audit.py
├── README.md                        # This file
├── EXEC_SUMMARY.md                  # Executive summary
├── DEMO_SCRIPT.md                   # Demo walkthrough
└── DATA_DICTIONARY.md               # Data definitions
```

### Extending the Platform

**Add New Data Source**:
1. Create schema in `RAW_DATA`
2. Apply masking policies
3. Update analytics views to include new source
4. Refresh aggregations

**Add Custom Analytics**:
1. Create function in `ANALYTICS` schema
2. Ensure k-anonymity compliance
3. Add to pre-approved questions if needed
4. Update Streamlit pages

---

## 🧪 Testing

### Data Quality Validation
```sql
CALL validate_data_quality();
```

### Privacy Compliance Check
```sql
CALL check_k_anonymity_compliance();
```

### System Health Check
```sql
SELECT system_health_check();
```

---

## 📈 Performance

- **Query Response**: < 3 seconds for aggregated queries
- **Real-Time Updates**: 5-minute lag via dynamic tables
- **Data Volume**: Scales to millions of records
- **Concurrent Users**: Supports 100+ simultaneous analysts

---

## 🤝 Contributing

This is a hackathon project, but contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Implement your enhancement
4. Add tests and documentation
5. Submit a pull request

---

## 📄 License

MIT License - see LICENSE file for details

---

## 👥 Team

Built for the Snowflake AI for Good Hackathon

**Key Technologies**: Snowflake, Snowflake Cortex, Streamlit, SQL, Python

---

## 🙏 Acknowledgments

- Snowflake for providing the platform and AI capabilities
- Banking and insurance industry for inspiring the use case
- Privacy advocates who champion data protection

---

## 📞 Contact

For questions, issues, or collaboration opportunities, please open an issue in this repository.

---

## 🎯 Why This Matters

Financial crime and fraud cost organizations billions annually. By enabling privacy-safe data collaboration, CrossRisk helps:

- **Detect fraud earlier** through cross-organizational signals
- **Reduce false positives** with richer risk context
- **Protect customer privacy** through built-in governance
- **Comply with regulations** via comprehensive audit trails
- **Save costs** by preventing fraud before it scales

**CrossRisk proves that AI for Good means building technology that protects both people and organizations.**

---

*Built with ❤️ for a safer, more transparent financial ecosystem*
