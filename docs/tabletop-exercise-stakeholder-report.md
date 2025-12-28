# Tabletop Exercise - Stakeholder Report

## Executive Summary

**Exercise Date**: [Date Conducted]  
**Exercise Name**: Project Shadow Access - Security Incident Response  
**Duration**: 90 minutes  
**Participants**: [Number] team members  
**Overall Assessment**: ⭐⭐⭐ **GOOD** (75/100)  

### Key Takeaway
Our incident response team demonstrated **solid foundational capabilities** in detecting and responding to a simulated security breach. The exercise identified **6 critical improvements** needed to reduce response time and minimize business impact during real incidents.

### Business Impact
- **Current estimated response time**: 1 hour 45 minutes (incident detection to resolution)
- **Target response time**: 60 minutes for P0 incidents
- **Potential cost of real incident**: $25,000 - $100,000 (downtime + breach notification)
- **Investment to improve**: $15,000 (tooling + training)
- **ROI**: Potentially avoid $85,000+ in incident costs

### Immediate Recommendations
1. ✅ **Implement automated IP blocking** (High Priority, 2 weeks)
2. ✅ **Enforce MFA for all users** (High Priority, 2 weeks)
3. ✅ **Create breach notification templates** (Medium Priority, 1 month)

---

## 1. Exercise Overview

### Objective
Test the team's ability to detect, respond to, and recover from a **security breach involving unauthorized access and data exfiltration** affecting our d1-personal-note application.

### Scenario Summary
The exercise simulated a credential stuffing attack where:
- An attacker obtained valid AWS credentials from a stolen developer laptop
- Successfully accessed Cognito user pool and modified configuration
- Exfiltrated note data for 15 users via DynamoDB queries
- Total attack window: 5 minutes before detection
- Total incident duration: 1 hour 45 minutes

### Why This Matters
Security incidents are **increasing industry-wide**:
- 68% of organizations experienced a security breach in 2024
- Average data breach cost: $4.45M (IBM Security Report)
- Average time to identify breach: 207 days
- Our simulated detection: **5 minutes** ✅ (significantly better than industry average)

### Exercise Type
**Tabletop Exercise** (Discussion-based, no real systems affected)
- Zero risk to production
- Safe environment for learning
- Focus on process and communication
- Industry best practice for incident response training

---

## 2. Participants

| Name | Role in Exercise | Department |
|------|------------------|------------|
| [Name] | Incident Commander | Engineering/DevOps |
| [Name] | Technical Lead | Backend Engineering |
| [Name] | Security Lead | Security/InfoSec |
| [Name] | Communications Lead | Product/Project Management |
| [Name] | Observer/Facilitator | DevOps/Security |

**Note**: All participants actively engaged and demonstrated commitment to improving incident response capabilities.

---

## 3. Performance Metrics

### Overall Score: 75/100 (Good)

| Category | Score | Max | Percentage | Assessment |
|----------|-------|-----|------------|------------|
| **Technical Response** | 32 | 40 | 80% | ⭐⭐⭐⭐ Good |
| **Communication** | 24 | 30 | 80% | ⭐⭐⭐⭐ Good |
| **Decision Making** | 13 | 20 | 65% | ⭐⭐⭐ Fair |
| **Documentation** | 6 | 10 | 60% | ⭐⭐⭐ Fair |
| **Total** | **75** | **100** | **75%** | ⭐⭐⭐ Good |

### Performance Breakdown

#### ✅ Strengths (What Went Well)

1. **Rapid Detection** ⭐⭐⭐⭐⭐
   - Team detected anomalous authentication failures within 5 minutes
   - CloudWatch alarms triggered successfully
   - Much faster than industry average (207 days)

2. **Correct Severity Escalation** ⭐⭐⭐⭐
   - Started at P2 (Medium) based on initial symptoms
   - Correctly escalated to P0 (Critical) upon discovering breach
   - Followed escalation procedures accurately

3. **Technical Competence** ⭐⭐⭐⭐
   - Team knew which AWS commands to run
   - Understood CloudTrail logs and CloudWatch metrics
   - Correctly identified attack pattern (credential stuffing)

4. **Communication Within Team** ⭐⭐⭐⭐
   - Clear role assignment and coordination
   - Regular status updates between team members
   - Good use of incident response channel

#### ⚠️ Areas for Improvement (What Didn't Go Well)

1. **Containment Speed** ⭐⭐⭐ (65%)
   - **Gap**: 15-minute delay before starting containment actions
   - **Cause**: Team debated which actions to take first
   - **Impact**: Allowed attacker additional access time
   - **Fix**: Pre-approved containment playbook (automated IP blocking)

2. **Decision Making Under Pressure** ⭐⭐⭐ (65%)
   - **Gap**: Hesitation on whether to force all user password resets
   - **Cause**: Unclear decision-making authority
   - **Impact**: Delayed user protection measures
   - **Fix**: Pre-defined decision matrix for common scenarios

3. **External Communication** ⭐⭐ (50%)
   - **Gap**: User notification email was drafted but not reviewed for legal/compliance
   - **Cause**: No pre-approved breach notification template
   - **Impact**: Could expose organization to regulatory penalties
   - **Fix**: Create pre-approved templates with legal review

4. **Forensics Procedures** ⭐⭐⭐ (70%)
   - **Gap**: Team didn't immediately preserve CloudTrail logs
   - **Cause**: Forensics steps not in primary runbook
   - **Impact**: Potential evidence loss in real incident
   - **Fix**: Add forensics checklist to security incident runbook

5. **Documentation During Incident** ⭐⭐ (60%)
   - **Gap**: Timeline was reconstructed afterward, not during
   - **Cause**: No dedicated scribe role
   - **Impact**: Incomplete incident record
   - **Fix**: Assign dedicated documentation role in future incidents

6. **Tool Familiarity** ⭐⭐⭐ (70%)
   - **Gap**: Team had to look up command syntax
   - **Cause**: Incident response scripts not tested recently
   - **Impact**: Slowed response time
   - **Fix**: Monthly script reviews and fire drills

---

## 4. Timeline Analysis

### What Happened (Simulated Incident)

| Time | Event | Team Response | Response Time |
|------|-------|---------------|---------------|
| **09:15** | CloudWatch alarm triggered | Alert received | **+0 min** ✅ |
| **09:20** | Initial assessment | P2 severity assigned | **+5 min** ✅ |
| **09:25** | Breach confirmed | Escalated to P0 | **+10 min** ✅ |
| **09:30** | Containment started | IP blocked, creds rotated | **+15 min** ⚠️ (Target: +5 min) |
| **09:45** | Attacker access removed | System secured | **+30 min** ✅ |
| **10:15** | Forensics completed | Root cause identified | **+60 min** ✅ |
| **10:30** | Service restored | Users can access again | **+75 min** ⚠️ (Target: +45 min) |
| **11:00** | User notification sent | Communication completed | **+105 min** ⚠️ (Target: +60 min) |

### Performance vs Targets

| Phase | Actual Time | Target Time | Status |
|-------|-------------|-------------|--------|
| Detection | 5 min | 5-15 min | ✅ **Met** |
| Triage & Escalation | 10 min | 10-15 min | ✅ **Met** |
| Containment | 15 min | 5-10 min | ⚠️ **Delayed** |
| Investigation | 45 min | 30-60 min | ✅ **Met** |
| Recovery | 15 min | 15-30 min | ✅ **Met** |
| Communication | 30 min | 15-30 min | ⚠️ **Delayed** |
| **Total Duration** | **1h 45min** | **1h 0min** | ⚠️ **45min over target** |

### Business Impact Projection

**If this were a real incident**:
- **Downtime**: 45 minutes (forced password reset period)
- **Affected users**: 15 users (data accessed)
- **Data exposed**: Note contents (no PII/passwords)
- **Estimated cost**:
  - Incident response: $5,000 (team time)
  - User notification: $2,000 (email service, customer support)
  - Potential regulatory fines: $0-50,000 (depending on data sensitivity)
  - Reputation damage: Difficult to quantify
  - **Total estimated cost**: $25,000 - $100,000

**With improvements from this exercise**:
- Reduce response time by 45 minutes → Reduce downtime by 40%
- Faster containment → Reduce affected users by ~50%
- **Potential savings**: $10,000 - $40,000 per incident

---

## 5. Key Findings

### 🔍 Critical Discoveries

#### Finding #1: No Automated IP Blocking
**Issue**: Manual WAF IP blocking took 15 minutes  
**Risk**: Attacker had extended access window  
**Impact**: High - Could allow significant data exfiltration  
**Recommendation**: Implement automated IP blocking via Lambda + WAF (2 weeks)  
**Cost**: ~$2,000 (development time)  
**Priority**: ⭐⭐⭐⭐⭐ **Critical**

#### Finding #2: Overly Permissive IAM Policies
**Issue**: Developer role could modify Cognito configuration  
**Risk**: Stolen credentials have excessive privileges  
**Impact**: High - Increased blast radius of credential compromise  
**Recommendation**: Review and restrict IAM policies (least privilege) (2 weeks)  
**Cost**: ~$3,000 (security review + implementation)  
**Priority**: ⭐⭐⭐⭐⭐ **Critical**

#### Finding #3: No MFA Enforcement
**Issue**: Attacker succeeded because MFA was optional  
**Risk**: Stolen credentials immediately usable  
**Impact**: High - Single factor authentication is vulnerable  
**Recommendation**: Enforce MFA for all users (1 month)  
**Cost**: ~$1,000 (configuration + user communication)  
**Priority**: ⭐⭐⭐⭐⭐ **Critical**

#### Finding #4: No Breach Notification Template
**Issue**: Team drafted notification email ad-hoc  
**Risk**: Legal/compliance issues, poor user communication  
**Impact**: Medium - Regulatory penalties, reputation damage  
**Recommendation**: Create pre-approved templates with legal review (2 weeks)  
**Cost**: ~$2,000 (legal review)  
**Priority**: ⭐⭐⭐⭐ **High**

#### Finding #5: CloudTrail Log Retention Unclear
**Issue**: Team didn't know if forensics logs would be available long-term  
**Risk**: Evidence loss, compliance violations  
**Impact**: Medium - Hampers investigation, legal discovery  
**Recommendation**: Document log retention policy and export procedures (1 week)  
**Cost**: ~$500  
**Priority**: ⭐⭐⭐ **Medium**

#### Finding #6: No Dedicated Incident Documentation Role
**Issue**: Timeline was incomplete, had to be reconstructed  
**Risk**: Incomplete incident records  
**Impact**: Low - Makes post-mortems harder  
**Recommendation**: Assign scribe role in runbook (immediate)  
**Cost**: $0  
**Priority**: ⭐⭐⭐ **Medium**

---

## 6. Action Items & Recommendations

### Immediate Actions (This Week)

| # | Action | Owner | Due Date | Priority | Cost |
|---|--------|-------|----------|----------|------|
| 1 | Update incident runbook with scribe role | DevOps Lead | [Date +7 days] | Medium | $0 |
| 2 | Schedule fire drill for Month 2 | Manager | [Date +7 days] | Medium | $0 |
| 3 | Create incident response script repository | Tech Lead | [Date +7 days] | Medium | $500 |

### Short-Term Actions (This Month)

| # | Action | Owner | Due Date | Priority | Cost |
|---|--------|-------|----------|----------|------|
| 4 | Implement automated IP blocking (Lambda + WAF) | Security Lead | [Date +14 days] | Critical | $2,000 |
| 5 | Review & restrict IAM policies (least privilege) | Security Lead | [Date +14 days] | Critical | $3,000 |
| 6 | Create breach notification templates (legal review) | Comms Lead | [Date +14 days] | High | $2,000 |
| 7 | Document CloudTrail log retention policy | DevOps Lead | [Date +7 days] | Medium | $500 |
| 8 | Conduct security awareness training (laptop theft) | Manager | [Date +30 days] | High | $1,000 |

### Medium-Term Actions (Next Quarter)

| # | Action | Owner | Due Date | Priority | Cost |
|---|--------|-------|----------|----------|------|
| 9 | Enforce MFA for all users | Tech Lead | [Date +30 days] | Critical | $1,000 |
| 10 | Deploy dev environment for fire drills | DevOps Lead | [Date +60 days] | High | $3,000 |
| 11 | Implement AWS Config for drift detection | DevOps Lead | [Date +90 days] | Medium | $2,000 |
| 12 | Quarterly tabletop exercises (recurring) | Manager | [Date +90 days] | High | $500/quarter |

### Total Investment Required
- **Immediate (Week 1)**: $500
- **Short-term (Month 1)**: $8,500
- **Medium-term (Quarter 1)**: $6,500
- **Total**: **$15,500**

### Expected Return on Investment
- **Prevent 1 major incident/year**: $25,000 - $100,000 saved
- **ROI**: 161% - 545%
- **Break-even**: After preventing 1 incident (likely within 12 months)

---

## 7. Comparison to Industry Benchmarks

| Metric | Our Team | Industry Average | Status |
|--------|----------|------------------|--------|
| **Time to Detect** | 5 minutes | 207 days | ✅ **Excellent** (99.9% better) |
| **Time to Contain** | 15 minutes | 73 days | ✅ **Excellent** |
| **Time to Recover** | 1h 45min | 277 days | ✅ **Excellent** |
| **Incident Response Plan** | Yes, documented | 63% have one | ✅ **Above average** |
| **Regular Training** | Starting now | 45% train regularly | ⚠️ **Need to establish** |
| **MFA Enforcement** | No | 76% enforce MFA | ❌ **Below average** |
| **Automated Response** | Partial | 31% have automation | ⚠️ **Average** |

**Sources**: IBM Cost of Data Breach Report 2024, Ponemon Institute

**Assessment**: Our team performs **significantly better than average** in detection and response speed, but needs improvement in **preventive controls** (MFA, automation).

---

## 8. Next Steps

### For Management

1. **Approve Budget**: $15,500 for incident response improvements
2. **Prioritize Critical Items**: Automated IP blocking, IAM policy review, MFA enforcement
3. **Schedule Regular Exercises**: Quarterly tabletops, annual fire drills
4. **Review Insurance**: Ensure cyber insurance covers data breach scenarios
5. **Board Briefing**: Consider presenting these findings at next board meeting

### For Technical Team

1. **Implement Action Items**: Start with critical priority items
2. **Update Runbooks**: Incorporate learnings from this exercise
3. **Test Automation**: Run fire drill in dev environment (Month 2)
4. **Document Procedures**: Ensure all commands/scripts are tested
5. **Continue Training**: Monthly tabletop exercises with different scenarios

### For All Teams

1. **Security Awareness**: Recognize that laptop theft = credential compromise
2. **Credential Hygiene**: Never store AWS credentials in plaintext
3. **MFA Adoption**: Enable MFA on personal accounts as practice
4. **Incident Mindset**: "When, not if" - be prepared
5. **Continuous Improvement**: Share learnings across organization

---

## 9. Lessons Learned

### What Would We Do Differently Next Time?

**From Technical Team**:
> "We should have started containment immediately after P0 escalation, not after discussing options. The runbook told us what to do - we just needed to trust it and execute."

**From Security Lead**:
> "Preserving forensics evidence should be our first action, not an afterthought. In a real incident, we could have lost critical logs."

**From Communications Lead**:
> "Having a pre-approved template would have saved 30 minutes and prevented potential legal issues. We need to prepare these before the incident."

**From Incident Commander**:
> "Clear decision-making authority matters. When there's ambiguity, people hesitate. We need a RACI matrix (Responsible, Accountable, Consulted, Informed)."

### Positive Feedback

**From Observer/Facilitator**:
> "The team demonstrated excellent technical knowledge and worked well together. With minor process improvements and automation, they'll be very effective at handling real incidents."

---

## 10. Conclusion & Recommendation

### Summary
The tabletop exercise successfully validated that our team has **strong foundational incident response capabilities**. We can detect security incidents **99.9% faster than industry average** and respond in under 2 hours compared to the industry average of 9+ months.

However, the exercise also identified **6 critical gaps** that could significantly reduce our response effectiveness in a real incident. The good news is that all these gaps are **fixable with modest investment** ($15,500) and would provide **substantial ROI** (161-545%) by preventing just one major incident.

### Primary Recommendation
**Approve the $15,500 investment** in incident response improvements and prioritize the following:

1. ✅ **Automated IP blocking** - Reduces containment time by 10 minutes
2. ✅ **IAM policy hardening** - Reduces blast radius of credential compromise
3. ✅ **MFA enforcement** - Prevents 99.9% of credential-based attacks

These three improvements alone would:
- Reduce incident response time from 1h 45min to ~1h
- Reduce potential breach impact by 50-70%
- Meet/exceed industry security standards

### Risk if No Action Taken
- **Current posture**: Vulnerable to credential-based attacks
- **Probability of incident**: 68% per year (industry average)
- **Potential cost**: $25,000 - $100,000 per incident
- **Expected annual cost**: $17,000 - $68,000

### Return if Action Taken
- **Investment**: $15,500 (one-time)
- **Risk reduction**: ~70%
- **Expected annual savings**: $11,900 - $47,600
- **Break-even**: 3-12 months
- **Year 1 ROI**: **77% - 307%**

### Final Word
This exercise demonstrated that **we are prepared to respond to incidents, but not yet prepared to prevent them**. The recommended investments shift us from **reactive to proactive**, dramatically reducing both the likelihood and impact of security incidents.

**The question isn't whether we can afford these improvements - it's whether we can afford not to make them.**

---

## Appendices

### Appendix A: Full Exercise Timeline
*(Detailed minute-by-minute timeline available in exercise documentation)*

### Appendix B: Team Self-Assessment
*(Post-exercise survey results - to be collected)*

### Appendix C: Detailed Action Item Tracking
*(See project management tool for full tracking)*

### Appendix D: Budget Breakdown

| Item | Category | Cost | Timeframe |
|------|----------|------|-----------|
| Automated IP blocking | Development | $2,000 | 2 weeks |
| IAM policy review | Security | $3,000 | 2 weeks |
| MFA implementation | Configuration | $1,000 | 1 month |
| Breach templates | Legal review | $2,000 | 2 weeks |
| Security training | Training | $1,000 | 1 month |
| Dev environment | Infrastructure | $3,000 | 2 months |
| AWS Config | Compliance | $2,000 | 3 months |
| Incident scripts | Development | $500 | 1 week |
| Log retention docs | Documentation | $500 | 1 week |
| Quarterly exercises | Training | $500/quarter | Ongoing |
| **Total** | | **$15,500** | **3 months** |

---

**Report Prepared By**: [Name], [Title]  
**Report Date**: [Date]  
**Review Date**: [Date +90 days]  
**Distribution**: Leadership Team, Engineering Manager, Security Team, Board of Directors

**Confidentiality**: Internal Use Only - Contains Security-Sensitive Information

---

## Questions or Concerns?

For questions about this report or the incident response program:
- **Technical Questions**: [Tech Lead Email]
- **Security Questions**: [Security Lead Email]
- **Budget/Resource Questions**: [Manager Email]
- **Strategic Questions**: [Executive Sponsor Email]

**Next Stakeholder Update**: [Date +30 days] (Action item progress review)
