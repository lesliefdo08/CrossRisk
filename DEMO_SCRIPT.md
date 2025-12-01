# CrossRisk Demo Script

**For Judges and Evaluators**

This script walks through the key features of CrossRisk in a logical sequence. Total demo time: 10-12 minutes.

---

## Setup (1 minute)

If running with Snowflake:
```bash
cd CrossRisk/app
streamlit run Home.py
```

If running in offline demo mode (no Snowflake):
- Application automatically detects missing credentials
- Switches to sample data
- Full functionality available with realistic data

---

## 1. Home Page - Platform Overview (2 minutes)

**Show**: Main dashboard with key metrics

**Highlight**:
- Total customers analyzed across both organizations
- Average composite risk score
- Risk category distribution (pie chart)
- Regional risk heatmap

**Key Points**:
- Data combines banking and insurance sources
- All visualizations use aggregated data (k≥3)
- Notice the offline mode indicator if in demo mode

**Narrative**:
"CrossRisk provides a unified risk view across banking and insurance data. The platform maintains k-anonymity by ensuring every segment contains at least 3 customers. This dashboard shows the overall risk landscape with composite scores calculated from both data sources."

---

## 2. Pre-Approved Questions (3 minutes)

**Navigate**: Click "Pre-Approved Questions" in sidebar

**Show**:
- Question selector with categories
- AI-generated summaries for each question

**Demo Flow**:
1. Select "Overall risk distribution"
   - Show pie chart of customer distribution
   - Point out segment counts
   
2. Select "Age group risk analysis"
   - Show risk trends across demographics
   - Highlight age groups with elevated risk
   
3. Select "Regional risk hotspots"
   - Show geographic risk patterns
   - Discuss actionable insights

4. Select "Fraud pattern detection"
   - Show cross-organizational fraud signals
   - Explain confidence scores

**Key Points**:
- Questions are pre-approved by governance teams
- AI summaries provide context
- Privacy maintained through aggregation

**Narrative**:
"These curated questions represent common risk analytics needs. Each question pulls from the secure clean room, applying privacy protections automatically. The AI summaries help non-technical stakeholders understand the findings."

---

## 3. Risk Explorer - Interactive Filtering (2 minutes)

**Navigate**: Click "Risk Explorer" in sidebar

**Show**:
- Interactive filters (age, region, occupation, risk category)
- Dynamic visualizations
- Real-time segment analysis

**Demo Flow**:
1. Apply filters:
   - Select "45-54" age group
   - Select "Northeast" region
   - Risk score range: 60-100
   
2. Show results:
   - Summary metrics update
   - Bank vs Insurance risk scatter plot
   - Regional breakdown

3. Export data:
   - Click CSV export button
   - Show downloaded file

**Key Points**:
- Minimum 3 customers per segment enforced
- Empty results show warning message
- All combinations maintain privacy

**Narrative**:
"The Risk Explorer lets analysts drill into specific segments while maintaining privacy guarantees. Notice if we filter too aggressively, we get warnings about k-anonymity violations. The system prevents any query that could expose individual customers."

---

## 4. Organization Comparison (2 minutes)

**Navigate**: Click "Organization Comparison" in sidebar

**Show**:
- Side-by-side bank vs insurance metrics
- Regional comparison charts
- Age group risk trends
- Correlation analysis

**Demo Flow**:
1. Overview comparison:
   - Compare average risk scores
   - Show risk ranges
   
2. Regional analysis:
   - Grouped bar chart by region
   - Risk difference visualization
   
3. Correlation scatter plot:
   - Bank risk vs Insurance risk
   - Correlation coefficient
   - Fraud flag overlap

**Key Points**:
- Reveals patterns invisible to single organizations
- Correlation analysis shows alignment (or divergence)
- Customers with flags in both systems require attention

**Narrative**:
"This view shows the power of cross-organizational analytics. We can see where banking and insurance risk assessments align or diverge. The correlation analysis helps validate risk models and identify customers who appear risky across both domains."

---

## 5. Governance & Compliance (2 minutes)

**Navigate**: Click "Governance & Audit" in sidebar

**Show**:
- Compliance status dashboard
- Access audit trail
- Privacy metrics
- System health check

**Demo Flow**:
1. Compliance overview:
   - Show passed/failed/warning checks
   - K-anonymity compliance status
   
2. Access audit:
   - Recent queries logged
   - User activity patterns
   - Anomaly detection

3. Privacy metrics:
   - Masking policies active
   - Minimum group sizes
   - Protection measures

4. Run health check:
   - Click "Run System Health Check"
   - Show diagnostic results

**Key Points**:
- Every data access is logged
- Compliance checks run automatically
- Anomalies flagged for review
- Exportable audit reports

**Narrative**:
"Governance isn't an afterthought—it's built into the platform. Every query is logged, privacy checks run continuously, and compliance teams have full visibility. This dashboard would be essential for regulatory audits."

---

## 6. Key Technical Features (1 minute)

**Explain**:

**Snowflake Features Used**:
- Dynamic Tables (automated refresh)
- Masking Policies (PII protection)
- Row Access Policies (risk-based filtering)
- Cortex AI (natural language summaries)
- Streams & Tasks (real-time pipeline)

**Privacy Guarantees**:
- K-anonymity (k≥3) enforced on all aggregations
- Dynamic masking based on user roles
- Row-level access control
- Complete audit trail

**AI Capabilities**:
- Natural language explanations
- Anomaly detection
- Risk pattern interpretation

---

## 7. Offline Demo Mode (30 seconds)

**Show**:
- Info banner indicating offline mode
- Full functionality with sample data
- No Snowflake credentials required

**Key Points**:
- Application detects missing Snowflake connection
- Automatically generates realistic sample data
- All features work identically
- Perfect for demos and testing

**Narrative**:
"The application includes a complete offline mode. When Snowflake credentials aren't available, it automatically switches to sample data. This makes it easy to demo the interface without requiring a Snowflake account."

---

## 8. Closing Points (30 seconds)

**Emphasize**:

**Why This Matters**:
- Fraud patterns only visible across organizations
- Privacy protection enables collaboration
- Built entirely on Snowflake platform
- Production-ready governance

**Real-World Impact**:
- Banks reduce fraud false positives
- Insurance companies improve underwriting
- Customers benefit from better risk assessment
- Regulators get full transparency

**Differentiators**:
- No raw data sharing required
- Real-time collaboration
- AI-powered insights
- Complete audit trail

---

## Q&A Talking Points

**"How is privacy maintained?"**
- K-anonymity ensures minimum 3 customers per segment
- Dynamic masking protects PII
- Row access policies restrict sensitive data
- All aggregations prevent re-identification

**"What Snowflake features are used?"**
- Dynamic Tables for automated refresh
- Masking Policies for PII protection
- Cortex AI for natural language
- Streams & Tasks for real-time pipeline
- Secure Views for optimization safety

**"Can this scale to production?"**
- Yes - Snowflake handles millions of records
- Dynamic Tables optimize performance
- Caching reduces query costs
- Role-based access scales to enterprise

**"What about other organization types?"**
- Architecture supports any organization
- Healthcare + Insurance logical extension
- Retail + Financial services possible
- Clean room pattern generalizes

**"How do customers consent?"**
- Data already aggregated (no individuals)
- Privacy policies cover collaborative analytics
- K-anonymity means no individual identification
- Opt-out would prevent inclusion in segments

---

## Technical Demo (If Time Permits)

**Show SQL Scripts**:
```bash
# Open snowflake/dynamic_tables.sql
# Show k-anonymity enforcement: HAVING COUNT(*) >= 3
# Show masking policies in masking_policies.sql
# Show Row Access Policies in access_policies.sql
```

**Show Code**:
```bash
# Open app/db_connection.py
# Show offline mode detection
# Show sample data generation
```

---

## Reset Demo

To reset for next viewing:
1. Refresh browser (Ctrl+R)
2. Clear cache if needed (Shift+F5)
3. Restart Streamlit if required

---

**Remember**: Focus on business value first, then dive into technical implementation based on audience interest.
