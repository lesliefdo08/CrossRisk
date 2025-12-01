# CrossRisk Data Dictionary

Complete reference guide for all data structures, columns, and definitions used in the CrossRisk platform.

---

## Table of Contents

1. [RAW_DATA Schema](#raw_data-schema)
2. [ANALYTICS Schema](#analytics-schema)
3. [GOVERNANCE Schema](#governance-schema)
4. [AI_INSIGHTS Schema](#ai_insights-schema)
5. [CLEAN_ROOM Views](#clean_room-views)
6. [Data Types & Constraints](#data-types--constraints)
7. [Calculated Fields](#calculated-fields)

---

## RAW_DATA Schema

Contains masked source data from partner organizations.

### bank_customer_risk_summary

Primary source table for banking risk data.

| Column Name | Data Type | Description | Privacy Level |
|------------|-----------|-------------|---------------|
| customer_id | VARCHAR(50) | Hashed customer identifier (PK) | MASKED |
| age_group | VARCHAR(20) | Age bracket (e.g., '25-34', '35-44') | PUBLIC |
| region | VARCHAR(50) | Geographic region | PUBLIC |
| occupation_category | VARCHAR(50) | Generalized occupation type | PUBLIC |
| account_tenure_years | INT | Years as customer | PUBLIC |
| product_count | INT | Number of active banking products | PUBLIC |
| total_balance_band | VARCHAR(20) | Balance range (e.g., '10k-50k') | MASKED |
| credit_score_band | VARCHAR(20) | Credit score range | MASKED |
| transaction_velocity | VARCHAR(20) | Transaction frequency category | PUBLIC |
| fraud_flag_history | INT | Historical fraud flags count (default: 0) | SENSITIVE |
| risk_score | FLOAT | Bank's internal risk score (0-100) | MASKED |
| last_updated | TIMESTAMP_NTZ | Last update timestamp | PUBLIC |
| data_source | VARCHAR(50) | Source organization (default: 'BANK_ALPHA') | PUBLIC |

**Constraints**:
- Primary Key: customer_id
- Default: fraud_flag_history = 0
- Default: last_updated = CURRENT_TIMESTAMP()

**Privacy Policies Applied**:
- customer_id: mask_customer_id
- total_balance_band: mask_financial_details
- risk_score: mask_risk_score

---

### insurance_claim_risk_summary

Primary source table for insurance risk data.

| Column Name | Data Type | Description | Privacy Level |
|------------|-----------|-------------|---------------|
| policy_id | VARCHAR(50) | Hashed policy identifier (PK) | MASKED |
| customer_id | VARCHAR(50) | Hashed customer identifier (linkable to bank) | MASKED |
| age_group | VARCHAR(20) | Age bracket | PUBLIC |
| region | VARCHAR(50) | Geographic region | PUBLIC |
| occupation_category | VARCHAR(50) | Generalized occupation type | PUBLIC |
| policy_type | VARCHAR(50) | Insurance product type | PUBLIC |
| coverage_amount_band | VARCHAR(20) | Coverage range | MASKED |
| premium_band | VARCHAR(20) | Premium range | MASKED |
| claim_count_12m | INT | Claims in last 12 months (default: 0) | SENSITIVE |
| claim_amount_band | VARCHAR(20) | Total claim amount range | MASKED |
| claim_frequency_pattern | VARCHAR(20) | Pattern indicator (Normal, Elevated, Critical) | SENSITIVE |
| suspicious_claim_flags | INT | Red flag indicators (default: 0) | SENSITIVE |
| risk_score | FLOAT | Insurer's risk score (0-100) | MASKED |
| last_updated | TIMESTAMP_NTZ | Last update timestamp | PUBLIC |
| data_source | VARCHAR(50) | Source organization (default: 'INSURANCE_BETA') | PUBLIC |

**Constraints**:
- Primary Key: policy_id
- Default: claim_count_12m = 0
- Default: suspicious_claim_flags = 0
- Default: last_updated = CURRENT_TIMESTAMP()

**Privacy Policies Applied**:
- policy_id: mask_policy_id
- customer_id: mask_customer_id
- coverage_amount_band: mask_financial_details
- risk_score: mask_risk_score

---

## ANALYTICS Schema

Contains derived analytics and aggregated insights.

### risk_join_aggregated

Privacy-safe aggregations of cross-organizational risk data.

| Column Name | Data Type | Description | Constraints |
|------------|-----------|-------------|-------------|
| analysis_id | VARCHAR(50) | Unique segment identifier (PK) | NOT NULL |
| age_group | VARCHAR(20) | Age bracket | NOT NULL |
| region | VARCHAR(50) | Geographic region | NOT NULL |
| occupation_category | VARCHAR(50) | Occupation type | NULL allowed |
| record_count | INT | Number of customers in segment | >= 3 (k-anonymity) |
| avg_bank_risk_score | FLOAT | Average banking risk score | 0-100 |
| avg_insurance_risk_score | FLOAT | Average insurance risk score | 0-100 |
| composite_risk_score | FLOAT | Weighted combined risk score | 0-100+ |
| risk_category | VARCHAR(20) | LOW, MEDIUM, HIGH, or CRITICAL | NOT NULL |
| fraud_correlation_score | FLOAT | Cross-signal correlation (0-1) | 0-1 |
| analysis_timestamp | TIMESTAMP_NTZ | When analysis was generated | Default: CURRENT_TIMESTAMP() |

**Constraints**:
- Primary Key: analysis_id
- Check: record_count >= 3 (k-anonymity enforcement)

**Calculation Logic**:
```sql
composite_risk_score = (avg_bank_risk_score * 0.6) + 
                       (avg_insurance_risk_score * 0.4) + 
                       (fraud_flags * 5) + 
                       (claim_flags * 3)
```

---

### risk_category_definitions

Reference table for risk category thresholds.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| category | VARCHAR(20) | Risk category name (PK) |
| min_score | FLOAT | Minimum score for category |
| max_score | FLOAT | Maximum score for category |
| description | VARCHAR(500) | Category description |
| recommended_action | VARCHAR(500) | Suggested action for category |

**Reference Values**:

| Category | Min Score | Max Score | Description |
|----------|-----------|-----------|-------------|
| LOW | 0 | 25 | Minimal risk indicators |
| MEDIUM | 25 | 50 | Moderate risk requiring attention |
| HIGH | 50 | 75 | Significant risk factors detected |
| CRITICAL | 75 | 100 | Severe risk requiring urgent action |

---

### regional_risk_trends

Time-series risk trends by region.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| trend_id | VARCHAR(50) | Unique trend identifier (PK) |
| region | VARCHAR(50) | Geographic region |
| analysis_date | DATE | Date of analysis |
| customer_count | INT | Total customers analyzed |
| avg_composite_risk | FLOAT | Average risk score for region |
| high_risk_percentage | FLOAT | % of customers in HIGH/CRITICAL |
| trend_direction | VARCHAR(20) | INCREASING, STABLE, or DECREASING |
| created_at | TIMESTAMP_NTZ | Record creation timestamp |

**Trend Calculation**:
- Compares current avg_composite_risk to 7-day prior value
- INCREASING if difference > 5 points
- DECREASING if difference < -5 points
- STABLE otherwise

---

### fraud_cross_signals

Detected fraud patterns across organizations.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| signal_id | VARCHAR(50) | Unique signal identifier (PK) |
| age_group | VARCHAR(20) | Age bracket where pattern detected |
| region | VARCHAR(50) | Region where pattern detected |
| pattern_description | VARCHAR(500) | Human-readable pattern description |
| affected_customer_count | INT | Number of customers affected |
| confidence_score | FLOAT | Detection confidence (0-1) |
| detected_at | TIMESTAMP_NTZ | When pattern was detected |

**Constraints**:
- Check: affected_customer_count >= 3 (k-anonymity)

**Confidence Score Ranges**:
- 0.80-1.00: Critical - immediate action required
- 0.60-0.79: Elevated - investigation warranted
- 0.40-0.59: Warning - monitor closely
- 0.00-0.39: Low - baseline surveillance

---

## GOVERNANCE Schema

Audit trails and compliance tracking.

### access_audit_log

Complete audit trail of all data access.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| audit_id | VARCHAR(50) | Unique audit record (PK) |
| user_name | VARCHAR(100) | Snowflake user who executed query |
| role_name | VARCHAR(100) | Active role during query |
| query_text | VARCHAR(5000) | Full query text |
| query_type | VARCHAR(50) | SELECT, INSERT, UPDATE, etc. |
| tables_accessed | ARRAY | List of tables accessed |
| row_count | INT | Number of rows returned |
| execution_time_ms | INT | Query execution time |
| session_id | VARCHAR(100) | Snowflake session identifier |
| client_ip | VARCHAR(50) | Client IP address (if available) |
| executed_at | TIMESTAMP_NTZ | Query execution timestamp |

**Retention**: 90 days in main table, archived after to access_audit_log_archive

---

### privacy_compliance_log

Log of privacy and compliance checks.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| compliance_id | VARCHAR(50) | Unique compliance check (PK) |
| check_type | VARCHAR(50) | Type of check (K_ANONYMITY, MASKING, etc.) |
| table_name | VARCHAR(200) | Table being checked |
| check_result | VARCHAR(20) | PASSED, FAILED, or WARNING |
| details | VARCHAR(1000) | Detailed check results |
| checked_at | TIMESTAMP_NTZ | When check was performed |

**Check Types**:
- K_ANONYMITY: Verifies minimum group sizes
- DATA_QUALITY: Validates data completeness
- MASKING: Confirms masking policies active
- ACCESS_MONITORING: Reviews access patterns
- EMERGENCY_FREEZE: System freeze events

---

### data_access_requests

Clean room access request tracking.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| request_id | VARCHAR(50) | Unique request identifier (PK) |
| requesting_user | VARCHAR(100) | User requesting access |
| requesting_org | VARCHAR(100) | Organization name |
| query_purpose | VARCHAR(500) | Business justification |
| requested_data_elements | ARRAY | List of data elements requested |
| approval_status | VARCHAR(20) | PENDING, APPROVED, or REJECTED |
| approved_by | VARCHAR(100) | Approver name |
| approved_at | TIMESTAMP_NTZ | Approval timestamp |
| request_created_at | TIMESTAMP_NTZ | Request creation timestamp |

---

## AI_INSIGHTS Schema

AI-generated content and explanations.

### ai_explanations

Natural language explanations generated by Cortex.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| explanation_id | VARCHAR(50) | Unique explanation (PK) |
| context_type | VARCHAR(50) | ANOMALY, TREND, PATTERN, etc. |
| reference_data | VARIANT | JSON with source data summary |
| ai_explanation | TEXT | Natural language explanation |
| confidence_score | FLOAT | Explanation confidence (0-1) |
| generated_model | VARCHAR(50) | AI model used (e.g., 'cortex-mistral-large') |
| generated_at | TIMESTAMP_NTZ | Generation timestamp |

**Context Types**:
- HIGH_RISK_SEGMENT: Explanation for elevated risk segments
- FRAUD_PATTERN: Description of detected fraud patterns
- REGIONAL_TREND: Regional risk trend analysis
- ANOMALY: Unusual pattern explanation

---

### approved_questions_cache

Cached results for pre-approved analytics questions.

| Column Name | Data Type | Description |
|------------|-----------|-------------|
| question_id | VARCHAR(50) | Unique question identifier (PK) |
| question_text | VARCHAR(500) | Question in natural language |
| category | VARCHAR(50) | Question category |
| result_data | VARIANT | JSON with query results |
| ai_summary | TEXT | AI-generated summary of results |
| last_refreshed | TIMESTAMP_NTZ | When cache was last updated |

**Categories**:
- Risk Overview
- Age Analysis
- Regional Analysis
- Fraud Detection
- Occupation Analysis

---

## CLEAN_ROOM Views

Secure views for privacy-safe cross-organizational queries.

### bank_aggregated_view

```sql
SELECT 
    age_group,
    region,
    occupation_category,
    COUNT(*) as customer_count,
    AVG(risk_score) as avg_risk_score,
    STDDEV(risk_score) as risk_stddev
FROM RAW_DATA.bank_customer_risk_summary
GROUP BY age_group, region, occupation_category
HAVING COUNT(*) >= 3  -- k-anonymity
```

### insurance_aggregated_view

```sql
SELECT 
    age_group,
    region,
    occupation_category,
    policy_type,
    COUNT(*) as policy_count,
    AVG(risk_score) as avg_risk_score,
    SUM(claim_count_12m) as total_claims
FROM RAW_DATA.insurance_claim_risk_summary
GROUP BY age_group, region, occupation_category, policy_type
HAVING COUNT(*) >= 3  -- k-anonymity
```

### cross_org_insights

```sql
SELECT 
    b.age_group,
    b.region,
    b.occupation_category,
    COUNT(DISTINCT b.customer_id) as unique_customers,
    AVG(b.risk_score) as avg_bank_risk,
    AVG(i.risk_score) as avg_insurance_risk,
    (AVG(b.risk_score) * 0.6 + AVG(i.risk_score) * 0.4) as composite_risk
FROM RAW_DATA.bank_customer_risk_summary b
JOIN RAW_DATA.insurance_claim_risk_summary i
    ON b.customer_id = i.customer_id
GROUP BY b.age_group, b.region, b.occupation_category
HAVING COUNT(DISTINCT b.customer_id) >= 3  -- k-anonymity
```

---

## Data Types & Constraints

### Standard Data Types

| Type | Usage | Example Values |
|------|-------|----------------|
| VARCHAR(n) | Text fields | 'Northeast', 'Technology' |
| INT | Whole numbers | 5, 100, 1000 |
| FLOAT | Decimal numbers | 42.5, 0.85 |
| TIMESTAMP_NTZ | Date/time without timezone | '2025-01-15 14:30:00' |
| ARRAY | Lists | ['TABLE1', 'TABLE2'] |
| VARIANT | JSON data | {"key": "value"} |
| TEXT | Long text | AI explanations, descriptions |

### Common Constraints

- **NOT NULL**: Field must have a value
- **PRIMARY KEY**: Unique identifier for record
- **CHECK**: Validation rule (e.g., record_count >= 3)
- **DEFAULT**: Automatic value if not provided
- **FOREIGN KEY**: (Not used - denormalized for performance)

---

## Calculated Fields

### composite_risk_score

**Formula**:
```
composite_risk_score = (bank_risk * 0.6) + 
                       (insurance_risk * 0.4) + 
                       (fraud_flags * 5) + 
                       (claim_flags * 3)
```

**Weights Rationale**:
- Banking data: 60% (larger transaction volume, more data points)
- Insurance data: 40% (less frequent but high-impact events)
- Fraud penalties: +5 per bank flag, +3 per insurance flag

**Range**: 0-100+ (can exceed 100 with fraud flags)

---

### fraud_correlation_score

**Logic**:
```sql
CASE
    WHEN fraud_flags > 0 AND claim_flags > 0 
         AND tx_velocity = 'High' AND claim_frequency IN ('Elevated', 'Critical')
    THEN 0.95  -- High correlation
    
    WHEN (fraud_flags > 0 OR claim_flags > 0) 
         AND (tx_velocity = 'High' OR claim_frequency IN ('Elevated', 'Critical'))
    THEN 0.75  -- Medium-high correlation
    
    WHEN fraud_flags > 0 OR claim_flags > 0
    THEN 0.50  -- Medium correlation
    
    WHEN tx_velocity = 'High' OR claim_frequency = 'Elevated'
    THEN 0.25  -- Low correlation
    
    ELSE 0.05  -- No correlation
END
```

**Range**: 0.05-0.95 (never 0 or 1 for model stability)

---

### risk_category

**Mapping**:
```sql
CASE
    WHEN composite_risk_score >= 75 THEN 'CRITICAL'
    WHEN composite_risk_score >= 50 THEN 'HIGH'
    WHEN composite_risk_score >= 25 THEN 'MEDIUM'
    ELSE 'LOW'
END
```

---

## Value Ranges & Enumerations

### age_group
- '18-24'
- '25-34'
- '35-44'
- '45-54'
- '55-64'
- '65+'

### region
- 'Northeast'
- 'Southeast'
- 'Midwest'
- 'West'
- 'Southwest' (future)

### occupation_category
- 'Technology'
- 'Healthcare'
- 'Finance'
- 'Education'
- 'Manufacturing'
- 'Retail'
- 'Service'

### transaction_velocity
- 'Low': < 10 transactions/month
- 'Medium': 10-50 transactions/month
- 'High': > 50 transactions/month

### claim_frequency_pattern
- 'Normal': Expected claim frequency
- 'Elevated': Above baseline but not suspicious
- 'Critical': Suspicious frequency requiring investigation

### balance/coverage bands
- '0-5k'
- '5k-10k'
- '10k-50k'
- '50k-100k'
- '100k-250k'
- '250k-500k'
- '500k-1M'
- '1M+'

---

## Privacy Classifications

### PUBLIC
Aggregated or non-identifying data accessible to all roles.

### MASKED
PII or sensitive data with role-based masking policies.

### SENSITIVE
High-value data requiring elevated permissions.

### RESTRICTED
Admin-only access for compliance and security.

---

## Naming Conventions

### Tables
- Lowercase with underscores
- Descriptive names
- Example: `risk_join_aggregated`, `fraud_cross_signals`

### Columns
- Lowercase with underscores
- Consistent suffixes: `_id`, `_at`, `_count`, `_score`
- Boolean flags: `_flag`, `_is_active`

### Views
- Prefix: `v_` for regular views
- Prefix: `dt_` for dynamic tables
- Example: `v_risk_join_aggregated`, `dt_realtime_risk_aggregation`

### Stored Procedures
- Snake_case
- Verb-first naming
- Example: `calculate_regional_trends()`, `refresh_risk_aggregations()`

---

## Change Log

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-15 | 1.0 | Initial data dictionary |

---

**Document maintained by**: CrossRisk Development Team  
**Last updated**: 2025-01-15  
**Version**: 1.0
