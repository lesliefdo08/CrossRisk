# CrossRisk Data Dictionary

This document describes all data tables, fields, and data types used in the CrossRisk platform.

---

## RAW_DATA Schema

### bank_customer_risk_summary

Source data from banking organization containing customer risk assessments.

| Field | Type | Description | Privacy Level |
|-------|------|-------------|---------------|
| customer_id | VARCHAR(50) | Unique customer identifier | PII - Masked |
| age_group | VARCHAR(20) | Age range (e.g., "35-44") | Public |
| region | VARCHAR(50) | Geographic region | Public |
| occupation_category | VARCHAR(50) | Job category | Public |
| income_band | VARCHAR(50) | Income range | Sensitive - Masked |
| credit_score_band | VARCHAR(20) | Credit score range | Sensitive |
| account_age_years | NUMBER | Years as customer | Public |
| transaction_volume_band | VARCHAR(50) | Transaction volume range | Sensitive - Masked |
| risk_score | NUMBER(5,2) | Bank-calculated risk (0-100) | Public (Aggregated) |
| fraud_flag_history | NUMBER | Count of previous fraud flags | Sensitive |
| last_risk_assessment | TIMESTAMP | Most recent assessment date | Public |

**Sample Values**:
```
customer_id: "CUST_12345"
age_group: "45-54"
region: "Northeast"
occupation_category: "Technology"
income_band: "$75K-$100K"
credit_score_band: "700-750"
risk_score: 42.50
```

---

### insurance_claim_risk_summary

Source data from insurance organization containing claim risk assessments.

| Field | Type | Description | Privacy Level |
|-------|------|-------------|---------------|
| customer_id | VARCHAR(50) | Unique customer identifier | PII - Masked |
| age_group | VARCHAR(20) | Age range | Public |
| region | VARCHAR(50) | Geographic region | Public |
| occupation_category | VARCHAR(50) | Job category | Public |
| policy_type | VARCHAR(50) | Insurance policy category | Public |
| claim_frequency | NUMBER | Number of claims filed | Sensitive |
| claim_amount_band | VARCHAR(50) | Claim value range | Sensitive - Masked |
| suspicious_claim_flags | NUMBER | Count of suspicious claims | Sensitive |
| policy_tenure_years | NUMBER | Years as policyholder | Public |
| risk_score | NUMBER(5,2) | Insurance-calculated risk (0-100) | Public (Aggregated) |
| last_claim_date | DATE | Most recent claim | Public |

**Sample Values**:
```
customer_id: "CUST_12345"
age_group: "45-54"
region: "Northeast"
occupation_category: "Technology"
policy_type: "Auto + Home"
claim_frequency: 3
suspicious_claim_flags: 1
risk_score: 58.75
```

---

## MASKED_DATA Schema

### masked_bank_customers

Bank data with PII masking policies applied.

| Field | Masking Policy | Visible To |
|-------|----------------|-------------|
| customer_id | customer_id_mask | RISK_ANALYST, RISK_MANAGER |
| income_band | financial_band_mask | RISK_ANALYST, RISK_MANAGER |
| transaction_volume_band | financial_band_mask | RISK_MANAGER only |
| All other fields | No masking | All roles |

**Masking Behavior**:
- `customer_id_mask`: Returns SHA2 hash for unauthorized roles
- `financial_band_mask`: Returns "REDACTED" for unauthorized roles

---

### masked_insurance_claims

Insurance data with PII masking policies applied.

| Field | Masking Policy | Visible To |
|-------|----------------|-------------|
| customer_id | customer_id_mask | RISK_ANALYST, RISK_MANAGER |
| claim_amount_band | financial_band_mask | RISK_ANALYST, RISK_MANAGER |
| All other fields | No masking | All roles |

---

## CLEAN_ROOM Schema

### bank_insurance_join

Core clean room table joining banking and insurance data on customer_id.

| Field | Type | Description | Source |
|-------|------|-------------|--------|
| customer_id | VARCHAR(50) | Customer identifier (masked) | Both |
| age_group | VARCHAR(20) | Age range | Both |
| region | VARCHAR(50) | Region | Both |
| occupation_category | VARCHAR(50) | Occupation | Both |
| bank_risk_score | NUMBER(5,2) | Banking risk score | Bank |
| insurance_risk_score | NUMBER(5,2) | Insurance risk score | Insurance |
| bank_fraud_flags | NUMBER | Bank fraud indicators | Bank |
| insurance_suspicious_claims | NUMBER | Insurance fraud indicators | Insurance |
| composite_risk_score | NUMBER(5,2) | Calculated combined risk | Computed |
| risk_category | VARCHAR(20) | LOW/MEDIUM/HIGH/CRITICAL | Computed |

**Composite Risk Calculation**:
```sql
composite_risk_score = (bank_risk_score * 0.5) + (insurance_risk_score * 0.5)

risk_category = CASE
    WHEN composite_risk_score >= 75 THEN 'CRITICAL'
    WHEN composite_risk_score >= 50 THEN 'HIGH'
    WHEN composite_risk_score >= 25 THEN 'MEDIUM'
    ELSE 'LOW'
END
```

---

## ANALYTICS Schema

### risk_join_aggregated

Main analytics table with k-anonymity enforcement.

| Field | Type | Description | K-Anonymity |
|-------|------|-------------|-------------|
| analysis_id | VARCHAR(100) | Unique segment identifier | N/A |
| age_group | VARCHAR(20) | Age range | Grouping key |
| region | VARCHAR(50) | Geographic region | Grouping key |
| occupation_category | VARCHAR(50) | Occupation | Grouping key |
| record_count | NUMBER | Customers in segment | **≥3 required** |
| composite_risk_score | NUMBER(5,2) | Average composite risk | Aggregated |
| risk_category | VARCHAR(20) | Segment risk category | Derived |
| avg_bank_risk_score | NUMBER(5,2) | Average bank risk | Aggregated |
| avg_insurance_risk_score | NUMBER(5,2) | Average insurance risk | Aggregated |
| fraud_correlation_score | NUMBER(5,2) | Cross-org fraud correlation | Computed |

**K-Anonymity Enforcement**:
```sql
-- Only segments with ≥3 customers are included
HAVING COUNT(*) >= 3
```

---

### fraud_cross_signals

Detected fraud patterns across organizations.

| Field | Type | Description |
|-------|------|-------------|
| signal_id | VARCHAR(100) | Unique signal identifier |
| age_group | VARCHAR(20) | Affected age group |
| region | VARCHAR(50) | Affected region |
| pattern_description | VARCHAR(500) | Fraud pattern description |
| affected_customer_count | NUMBER | Customers matching pattern |
| confidence_score | NUMBER(3,2) | Detection confidence (0-1) |
| detected_at | TIMESTAMP | Detection timestamp |

**Pattern Detection Logic**:
```sql
-- Example: High risk in both systems
WHERE bank_fraud_flags > 0 
  AND insurance_suspicious_claims > 0
  AND composite_risk_score > 70
```

---

## AI_INSIGHTS Schema

### approved_questions_cache

Pre-approved analytics questions with AI summaries.

| Field | Type | Description |
|-------|------|-------------|
| question_id | VARCHAR(20) | Question identifier (e.g., "Q001") |
| question_text | VARCHAR(500) | Question in natural language |
| category | VARCHAR(50) | Question category |
| result_data | VARIANT | Query results (JSON) |
| ai_summary | VARCHAR(2000) | Cortex-generated explanation |
| last_refreshed | TIMESTAMP | Last update timestamp |

**AI Summary Example**:
```
"Customers aged 45-54 in the Northeast region show elevated risk 
scores (avg 67.3) primarily driven by insurance claim patterns. 
This segment has 23% higher fraud correlation than the national 
average, suggesting enhanced monitoring is warranted."
```

---

## GOVERNANCE Schema

### privacy_compliance_log

Privacy compliance check results.

| Field | Type | Description |
|-------|------|-------------|
| compliance_id | VARCHAR(100) | Check identifier |
| check_type | VARCHAR(100) | Type of check |
| table_name | VARCHAR(200) | Table being checked |
| check_result | VARCHAR(20) | PASSED/WARNING/FAILED |
| details | VARCHAR(1000) | Check details |
| checked_at | TIMESTAMP | Check timestamp |

**Check Types**:
- `K_ANONYMITY_CHECK`: Verifies minimum group sizes
- `MASKING_POLICY_CHECK`: Confirms policies are applied
- `ACCESS_POLICY_CHECK`: Validates row-level security
- `DATA_QUALITY_CHECK`: Checks for data issues

---

### access_audit_log

Complete audit trail of data access.

| Field | Type | Description |
|-------|------|-------------|
| audit_id | VARCHAR(100) | Audit record identifier |
| user_name | VARCHAR(100) | User who ran query |
| role_name | VARCHAR(100) | Active role |
| query_type | VARCHAR(50) | SELECT/INSERT/UPDATE/DELETE |
| query_text | VARCHAR(5000) | Actual SQL query |
| row_count | NUMBER | Rows returned/affected |
| executed_at | TIMESTAMP | Execution timestamp |

**Audit Trail Coverage**:
- Every SELECT query logged
- User and role captured
- Row counts recorded
- Anomaly detection applied

---

## Masking Policies

### customer_id_mask

**Purpose**: Protect customer identifiers

**Logic**:
```sql
CASE 
    WHEN CURRENT_ROLE() IN ('RISK_ANALYST', 'RISK_MANAGER') 
        THEN val
    ELSE SHA2(val, 256)
END
```

---

### financial_band_mask

**Purpose**: Protect financial data ranges

**Logic**:
```sql
CASE 
    WHEN CURRENT_ROLE() = 'RISK_MANAGER' 
        THEN val
    WHEN CURRENT_ROLE() = 'RISK_ANALYST' 
        THEN val
    ELSE 'REDACTED'
END
```

---

## Row Access Policies

### risk_level_policy

**Purpose**: Restrict access to high-risk customer data

**Logic**:
```sql
CASE 
    WHEN composite_risk_score < 75 
        THEN TRUE
    WHEN CURRENT_ROLE() = 'RISK_MANAGER' 
        THEN TRUE
    ELSE FALSE
END
```

**Effect**:
- All users see LOW/MEDIUM/HIGH risk data
- Only RISK_MANAGER sees CRITICAL risk data

---

## Data Types Reference

### VARCHAR Sizes
- Identifiers: VARCHAR(50-100)
- Short descriptions: VARCHAR(200)
- Long descriptions: VARCHAR(500-1000)
- Query text: VARCHAR(5000)
- AI summaries: VARCHAR(2000)

### Numeric Precision
- Risk scores: NUMBER(5,2) - Range 0.00 to 100.00
- Confidence scores: NUMBER(3,2) - Range 0.00 to 1.00
- Counts: NUMBER - Whole numbers

### Timestamps
- All timestamps use TIMESTAMP_NTZ (no timezone)
- Formatted as 'YYYY-MM-DD HH:MI:SS'

---

## Privacy Guarantees

**K-Anonymity (k≥3)**
- Applied in ANALYTICS schema
- Enforced via HAVING COUNT(*) >= 3
- Segments below threshold excluded

**Dynamic Masking**
- Applied in MASKED_DATA schema
- Role-based visibility
- PII protected automatically

**Row Access Policies**
- Applied to high-risk data
- Manager approval required
- All access logged

**Audit Logging**
- Every query logged
- User and role captured
- Anomaly detection enabled

---

## Data Refresh Schedule

| Table | Refresh Method | Frequency |
|-------|----------------|-----------|
| RAW_DATA.* | Manual/CDC | As needed |
| MASKED_DATA.* | Masking Policy | Real-time |
| CLEAN_ROOM.* | Dynamic Table | Every 5 minutes |
| ANALYTICS.* | Dynamic Table | Every 10 minutes |
| AI_INSIGHTS.* | Scheduled Task | Daily at 2 AM |
| GOVERNANCE.* | Stream + Task | Real-time |

---

**Note**: All sample data in this document is fictional and generated for demonstration purposes.
