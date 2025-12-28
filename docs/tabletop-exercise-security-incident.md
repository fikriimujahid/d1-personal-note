# Tabletop Exercise: Security Incident - Unauthorized Access

## Exercise Overview

**Exercise Name**: "Project Shadow Access"  
**Scenario Type**: Security Incident (Unauthorized Access)  
**Duration**: 90 minutes  
**Difficulty**: High  
**Primary Runbook**: Runbook #4 - Security Incident (Unauthorized Access)  
**Date**: [To be scheduled]  
**Facilitator**: [Security Lead or DevOps Lead]

---

## Objectives

By the end of this exercise, participants should be able to:

1. ✅ Identify indicators of a security breach
2. ✅ Execute containment procedures rapidly
3. ✅ Follow the Security Incident runbook accurately
4. ✅ Coordinate communication across technical and non-technical teams
5. ✅ Make critical decisions under pressure
6. ✅ Document incident response actions
7. ✅ Identify gaps in current procedures

---

## Participants and Roles

| Role | Responsibilities During Exercise | Player Name |
|------|----------------------------------|-------------|
| **Incident Commander** | Lead response, make final decisions, coordinate teams | [TBD] |
| **Technical Lead** | Execute technical commands, investigate root cause | [TBD] |
| **Security Lead** | Handle forensics, assess security impact | [TBD] |
| **Communications Lead** | Manage stakeholder communication | [TBD] |
| **Observer** | Take notes, track time, provide evaluation | [TBD] |
| **Facilitator** | Inject scenario details, answer questions | [TBD] |

---

## Pre-Exercise Checklist

**24 Hours Before**:
- [ ] Send calendar invite with roles assigned
- [ ] Share this document with all participants
- [ ] Ensure access to AWS Console (read-only for exercise)
- [ ] Set up Slack channel: `#tabletop-exercise-security`
- [ ] Print incident response runbook quick reference

**15 Minutes Before**:
- [ ] All participants in meeting room or video call
- [ ] Screen sharing enabled
- [ ] Timer ready
- [ ] Incident response scripts accessible
- [ ] CloudWatch Dashboard open (or screenshot prepared)

**Ground Rules**:
1. This is a **simulation** - no actual commands will be executed
2. Speak your actions aloud (e.g., "I would now run this command...")
3. Ask clarifying questions - facilitator will provide additional details
4. Focus on **process** not perfection
5. No blame - this is a learning exercise

---

## Scenario Timeline

### Phase 1: Initial Detection (T+0 to T+15 minutes)

#### 🔔 SCENARIO INJECTION #1 (T+0)

**Time**: Monday, 09:15 AM  
**Alert Received**: 

```
From: AWS CloudWatch Alarms
Subject: ALARM: "d1-personal-note-main-cognito-auth-errors" in Asia Pacific (Singapore)

You are receiving this email because your Amazon CloudWatch Alarm 
"d1-personal-note-main-cognito-auth-errors" in the Asia Pacific (Singapore) 
region has entered the ALARM state.

Alarm Details:
- Alarm Name: d1-personal-note-main-cognito-auth-errors
- State Change: OK -> ALARM
- Reason: Threshold Crossed: 1 datapoint (47.0) was greater than the threshold (10.0)
- Timestamp: Monday, 28 December 2025 09:14:23 UTC
```

**Additional Context** (if asked):
- Your team receives this alert via email and Slack
- It's a normal Monday morning, no deployments scheduled
- User reports have NOT come in yet
- The system is processing approximately 200 requests/minute

**PAUSE FOR DISCUSSION**

**Discussion Questions**:
1. What is your immediate assessment of severity? (P0/P1/P2/P3)
2. Who should be the Incident Commander?
3. What are your first 3 actions?
4. What additional information do you need?

**Expected Actions**:
- [ ] Assign Incident Commander
- [ ] Create incident ticket/channel
- [ ] Initial severity assessment (likely P2, could escalate)
- [ ] Check CloudWatch metrics for more context
- [ ] Review recent deployments/changes

---

#### 🔔 SCENARIO INJECTION #2 (T+5 minutes)

**Incident Commander**: You've assigned roles. Technical Lead is investigating.

**Technical Lead discovers**:

```powershell
# You check Cognito metrics
aws cloudwatch get-metric-statistics `
  --namespace AWS/Cognito `
  --metric-name UserAuthenticationErrors `
  --dimensions Name=UserPool,Value=ap-southeast-1_XXXXXXXXX `
  --start-time (Get-Date).AddHours(-1).ToUniversalTime() `
  --end-time (Get-Date).ToUniversalTime() `
  --period 300 `
  --statistics Sum
```

**Result**: 
- 09:00-09:05: 3 errors (normal)
- 09:05-09:10: 8 errors (slightly elevated)
- 09:10-09:15: **47 errors** (ALARM!)

**Simultaneously, you receive a Slack DM**:

```
user_maria_santos: Hey, I keep getting "Invalid username or password" 
but I'm 100% sure my password is correct. I've tried 5 times now. 
Is something wrong with the system?
```

**PAUSE FOR DISCUSSION**

**Discussion Questions**:
1. Does this change your severity assessment?
2. What are potential causes for authentication failures?
3. What additional diagnostics should you run?
4. Should you communicate anything to users yet?

**Expected Actions**:
- [ ] Check CloudTrail for suspicious events
- [ ] Review Cognito User Pool configuration
- [ ] Check if issue is widespread or isolated
- [ ] Document the timeline

---

#### 🔔 SCENARIO INJECTION #3 (T+10 minutes)

**Security Lead** investigates CloudTrail:

```powershell
aws cloudtrail lookup-events `
  --lookup-attributes AttributeKey=EventName,AttributeValue=AdminInitiateAuth `
  --start-time (Get-Date).AddHours(-2).ToUniversalTime() `
  --max-items 50
```

**You discover**:

```json
{
    "EventTime": "2025-12-28T09:12:00Z",
    "EventName": "AdminInitiateAuth",
    "Username": "automated-scanner",
    "SourceIPAddress": "185.220.101.47",
    "ErrorMessage": "Incorrect username or password",
    "Resources": [{
        "ResourceName": "d1-personal-note-main-user-pool"
    }]
}
```

**Additional findings**:
- **185 authentication attempts** in last 30 minutes from IP `185.220.101.47`
- All attempts targeting different usernames (credential stuffing attack!)
- IP is from a known VPN provider (suspicious)
- **3 legitimate users** are now locked out due to failed login attempts

**CRITICAL**: You also notice:

```json
{
    "EventTime": "2025-12-28T09:14:32Z",
    "EventName": "UpdateUserPoolClient",
    "Username": "AIDACKCEVSQ6C2EXAMPLE",
    "SourceIPAddress": "185.220.101.47",
    "ResponseElements": {
        "UserPoolClient": {
            "ClientId": "7example1234567890",
            "RefreshTokenValidity": 30,
            "ReadAttributes": ["email", "phone_number", "name", "address"]
        }
    }
}
```

**🚨 CRITICAL DISCOVERY**: Someone successfully authenticated and modified the Cognito client configuration!

**PAUSE FOR DISCUSSION**

**Discussion Questions**:
1. **CRITICAL**: What severity is this now? (Should escalate to P0/P1)
2. What immediate containment actions must you take?
3. Do you have evidence of a successful breach?
4. What are the next steps per the Security Incident runbook?
5. Who needs to be notified immediately?

**Expected Actions**:
- [ ] **ESCALATE to P0** - Active security breach confirmed
- [ ] Begin immediate containment procedures
- [ ] Notify management/stakeholders
- [ ] Prepare for credential rotation
- [ ] Start incident documentation

---

### Phase 2: Containment (T+15 to T+30 minutes)

#### 🔔 SCENARIO INJECTION #4 (T+15 minutes)

**Incident Commander**: You've escalated to P0. What containment actions do you execute **RIGHT NOW**?

**Facilitator Note**: Walk through each containment step from the runbook. Participants should verbalize commands.

**PAUSE FOR TEAM TO PLAN CONTAINMENT**

**Expected Containment Actions** (from Runbook #4):

1. **Rotate ALL credentials**:
   ```powershell
   # Disable compromised IAM access key
   aws iam update-access-key `
     --access-key-id AKIAXXXXXXXXXXXXXX `
     --status Inactive
   ```

2. **Force sign-out all users**:
   ```powershell
   # Force global sign-out for all users (if possible via script)
   # Or for specific compromised user
   aws cognito-idp admin-user-global-sign-out `
     --user-pool-id ap-southeast-1_XXXXXXXXX `
     --username compromised-user@example.com
   ```

3. **Enable MFA enforcement** (if not already):
   ```powershell
   aws cognito-idp set-user-pool-mfa-config `
     --user-pool-id ap-southeast-1_XXXXXXXXX `
     --mfa-configuration OPTIONAL
   ```

4. **Block attack source via WAF**:
   ```powershell
   # Add IP to WAF block list
   aws wafv2 update-ip-set `
     --name d1-personal-note-blocked-ips `
     --scope CLOUDFRONT `
     --id example-ip-set-id `
     --addresses 185.220.101.47/32
   ```

**DECISION POINT**:

Communications Lead asks: **"Should we force all users to change passwords?"**

**Facilitator**: What is your decision and why?

---

#### 🔔 SCENARIO INJECTION #5 (T+20 minutes)

While implementing containment, **Technical Lead** discovers another issue:

```powershell
# Checking recent DynamoDB access
aws cloudtrail lookup-events `
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetItem `
  --start-time (Get-Date).AddMinutes(-30).ToUniversalTime()
```

**Results show**:
- **127 GetItem requests** to `d1-personal-note-main-notes` table
- All from the same suspicious IP address
- Accessed data for **15 different users**
- Timestamps: 09:13 - 09:14 (2-minute window before detection)

**🚨 DATA BREACH CONFIRMED**

**PAUSE FOR DISCUSSION**

**Discussion Questions**:
1. What is the scope of the data breach?
2. Do you have a legal/compliance notification requirement?
3. What forensic data should you preserve immediately?
4. How do you communicate this to affected users?

**Expected Actions**:
- [ ] Preserve CloudTrail logs (export to S3)
- [ ] Document all accessed records
- [ ] Notify legal/compliance team
- [ ] Prepare user notification
- [ ] Consider contacting law enforcement

---

### Phase 3: Investigation & Recovery (T+30 to T+60 minutes)

#### 🔔 SCENARIO INJECTION #6 (T+30 minutes)

**Incident Commander**: Containment is in progress. Security Lead begins forensics.

**Forensics Investigation Questions**:

1. **How did the attacker get valid credentials?**
   
   **Facilitator provides clue** (if asked):
   ```
   You find in CloudTrail that the UpdateUserPoolClient event was made using 
   IAM role: "d1-personal-note-developer-role" which has overly permissive policies.
   
   Checking GitHub audit logs (if you thought to check), you find:
   A developer's laptop was reported stolen 3 days ago (Wednesday). 
   The developer had AWS CLI credentials configured.
   ```

2. **What data was exfiltrated?**
   
   **Facilitator provides**:
   ```
   GetItem requests retrieved:
   - Note titles (metadata)
   - Note content (full text)  
   - User IDs
   - Timestamps
   
   NO sensitive PII like passwords (stored separately in Cognito)
   NO payment information (not collected by app)
   ```

3. **Are there any backdoors or persistence mechanisms?**
   
   **Facilitator provides** (if asked):
   ```
   Checking Lambda function code and environment variables: No changes detected.
   Checking IAM policies: No new policies or roles created.
   Checking Cognito users: 1 new user "automation-test" created by attacker (now deleted).
   ```

**PAUSE FOR DISCUSSION**

**Discussion Questions**:
1. What is the root cause? (5 Whys analysis)
2. What permanent fixes are needed?
3. Can we safely restore service?
4. What monitoring should we add?

**Expected Root Cause Analysis** (example):

```
Why was data accessed? → Attacker had valid AWS credentials
Why did attacker have credentials? → Developer laptop was stolen with credentials
Why were credentials on laptop? → Developer stored in plaintext CLI config
Why was that allowed? → No policy requiring MFA or credential rotation
Why no policy? → Security training and enforcement gaps
```

---

#### 🔔 SCENARIO INJECTION #7 (T+45 minutes)

**Incident Commander**: Time to recover and verify.

**Recovery Steps** (walk through):

1. **Verify containment**:
   - [ ] Confirm malicious IP blocked
   - [ ] Confirm old credentials rotated
   - [ ] Confirm no new malicious activity

2. **Apply security hardening**:
   ```powershell
   # Terraform changes to apply
   # 1. Enforce MFA for all IAM users
   # 2. Reduce IAM role permissions (least privilege)
   # 3. Enable AWS Config for drift detection
   # 4. Add CloudTrail alerts for suspicious events
   ```

3. **Restore service**:
   - [ ] Re-enable user access with mandatory password reset
   - [ ] Monitor for anomalies
   - [ ] Verify legitimate users can access

4. **Communication**:
   - [ ] Send user notification about breach
   - [ ] Update status page
   - [ ] Prepare public statement (if needed)

**PAUSE FOR DISCUSSION**

**Email to Users** - Review and critique:

```
Subject: Important Security Notice - d1-personal-note

Dear valued user,

On December 28, 2025 between 09:10-09:15 UTC, we detected and stopped 
unauthorized access to our system. We immediately took action to secure 
your account and investigate the incident.

WHAT HAPPENED:
A malicious actor gained temporary access using stolen credentials and 
accessed note data for a limited number of accounts.

WHAT DATA WAS AFFECTED:
- Note titles and content
- User IDs (not names or emails)
- Note metadata

WHAT WAS NOT AFFECTED:
- Passwords
- Personal identification information  
- Payment information (we don't collect this)

WHAT WE'VE DONE:
- Blocked the attacker's access
- Rotated all credentials
- Enhanced security monitoring
- Forced all users to reset passwords

WHAT YOU SHOULD DO:
1. Change your password immediately
2. Review your account for unauthorized notes
3. Enable two-factor authentication (when available)

We sincerely apologize for this incident and are committed to earning 
back your trust through improved security measures.

For questions: security@d1-personal-note.com

Security Team
d1-personal-note
```

**Discussion**: Is this communication appropriate? What would you change?

---

### Phase 4: Post-Incident & Lessons Learned (T+60 to T+90 minutes)

#### 🔔 FINAL SCENARIO STATUS (T+60 minutes)

**Facilitator announces**:

```
INCIDENT RESOLVED

Timeline:
- 09:15 - Initial alert (Cognito auth errors)
- 09:20 - P2 declared
- 09:25 - P0 escalation (breach confirmed)
- 09:30 - Containment actions started
- 09:45 - Attacker access removed
- 10:15 - Forensics completed
- 10:30 - Service restored with hardening
- 11:00 - User notification sent

Total Duration: 1 hour 45 minutes
Affected Users: 15 users (data accessed)
Downtime: 45 minutes (forced password reset)
```

---

## Post-Exercise Activities

### Immediate Debrief (30 minutes)

**Facilitator leads discussion**:

#### 1. What Went Well ✅

- What actions did the team execute effectively?
- What procedures worked as designed?
- What communication was clear?

#### 2. What Didn't Go Well ❌

- What caused delays or confusion?
- What information was missing?
- What procedures need improvement?

#### 3. Surprises / Discoveries 🔍

- What did we learn that we didn't know before?
- What assumptions were wrong?
- What risks did we identify?

#### 4. Action Items 📋

Document specific improvements:

| Action Item | Owner | Due Date | Priority |
|-------------|-------|----------|----------|
| Review IAM policies for least privilege | Security Lead | +7 days | High |
| Implement MFA enforcement for all users | Technical Lead | +14 days | High |
| Create automated response script for IP blocking | DevOps | +14 days | Medium |
| Conduct security awareness training | Manager | +30 days | High |
| Update incident runbook with learnings | Incident Commander | +7 days | Medium |

---

## Evaluation Criteria

### Technical Response (40 points)

- [ ] Correctly identified severity escalation path (10 pts)
- [ ] Executed containment procedures from runbook (15 pts)
- [ ] Proper forensics investigation (10 pts)
- [ ] Verified recovery before restoring service (5 pts)

### Communication (30 points)

- [ ] Clear role assignment and coordination (10 pts)
- [ ] Regular status updates (5 pts)
- [ ] Appropriate stakeholder notifications (10 pts)
- [ ] User communication was clear and timely (5 pts)

### Decision Making (20 points)

- [ ] Made correct P0 escalation decision (10 pts)
- [ ] Balanced speed vs thoroughness appropriately (5 pts)
- [ ] Documented decisions and rationale (5 pts)

### Documentation (10 points)

- [ ] Maintained incident timeline (5 pts)
- [ ] Documented actions taken (5 pts)

**Total Score**: ____ / 100

**Performance Rating**:
- 90-100: Excellent - Team is well-prepared
- 75-89: Good - Minor improvements needed
- 60-74: Fair - Significant training required
- <60: Poor - Major process gaps identified

---

## Key Learnings (Example)

Based on this exercise, teams typically learn:

1. **Speed matters**: Delay in escalation allowed attacker more access time
2. **Automation is critical**: Manual credential rotation takes too long
3. **Monitoring gaps**: Didn't detect UpdateUserPoolClient changes quickly enough
4. **IAM least privilege**: Overly permissive roles increase blast radius
5. **Forensics preparation**: CloudTrail retention and log export procedures unclear
6. **Communication templates**: Need pre-approved breach notification templates
7. **Runbook improvements**: Some commands needed more context

---

## Follow-Up Actions

**Within 48 hours**:
- [ ] Send exercise summary to all participants
- [ ] Create tickets for all action items
- [ ] Update incident response runbook
- [ ] Share learnings with broader team

**Within 1 week**:
- [ ] Schedule follow-up tabletop exercise (different scenario)
- [ ] Implement high-priority improvements
- [ ] Update security training materials

**Within 1 month**:
- [ ] Complete all action items
- [ ] Conduct real-world fire drill (controlled)
- [ ] Review and update this exercise based on feedback

---

## Additional Scenarios (Optional Variations)

For future exercises, vary the scenario:

1. **Insider Threat**: Malicious employee with valid credentials
2. **Ransomware**: Attacker encrypts DynamoDB data
3. **Supply Chain**: Compromised npm package in frontend
4. **Multi-Vector**: DDoS + data breach simultaneous attacks
5. **Regulatory**: Incident requiring immediate regulator notification

---

## Resources for Exercise

**Required Tools**:
- [ ] AWS Console (read-only access)
- [ ] Slack workspace
- [ ] Incident response runbook (printed)
- [ ] Timer/stopwatch
- [ ] Whiteboard or shared document for notes

**Optional/Recommended**:
- [ ] Screen recording (for later review)
- [ ] CloudWatch Dashboard screenshots
- [ ] Sample CloudTrail logs
- [ ] Post-incident report template

---

## Facilitator Notes

**Preparation Tips**:
1. Read through entire exercise twice before facilitating
2. Prepare "cheat sheet" with expected answers
3. Have AWS Console ready with example logs
4. Set up Slack channel in advance
5. Time each phase strictly

**During Exercise**:
- Let team struggle briefly before giving hints
- Pause frequently for discussion
- Note interesting decisions/debates
- Keep energy high - this should be engaging!

**Common Pitfalls to Watch For**:
- Team jumps to solutions without assessment
- Poor communication between roles
- Skipping verification steps
- Not documenting actions
- Forgetting about user communication

---

## Appendix: Exercise Variants

### Beginner Version (60 min)
- Provide more hints upfront
- Simplify CloudTrail logs
- Skip forensics deep-dive
- Focus on containment only

### Advanced Version (120 min)
- Add legal/PR stakeholders to exercise
- Include real AWS environment (sandbox)
- Execute actual commands (with safeguards)
- Simulate media inquiries
- Add compliance reporting requirements

### Remote Version
- Use Zoom breakout rooms for team coordination
- Use Miro board for timeline visualization
- Record session for later review
- Use Slack for all communication

---

**Exercise Version**: 1.0  
**Last Updated**: 2025-12-28  
**Next Review**: 2026-03-28  
**Owner**: Security Team  

**Feedback**: Please send exercise feedback to security-training@example.com
