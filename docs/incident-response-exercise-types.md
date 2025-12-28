# Incident Response Exercise Types - Comparison Guide

## Understanding Exercise vs Real Execution

When practicing incident response, there are **three main approaches**, each with different levels of realism and risk:

---

## 1. 📝 Tabletop Exercise (Discussion-Based)

### What It Means
- **Everything is discussed, NOT executed**
- Team sits around a table (or video call)
- Facilitator presents a scenario
- Team **talks through** what they would do
- **NO actual commands are run**
- **NO real systems are touched**

### Example Flow

**Facilitator says**: "You see this CloudWatch alarm. What do you do?"

**Team responds**: "I would run this command:
```powershell
aws cloudwatch describe-alarms --state-value ALARM
```
And I expect to see X, Y, Z..."

**Facilitator says**: "Here's what you would see..." (shows pre-prepared output)

### What Happens

| Activity | Tabletop Exercise | Real Execution |
|----------|-------------------|----------------|
| **Receiving CloudWatch alarm email** | Facilitator reads alert text aloud | Real email arrives in inbox |
| **Checking AWS Console** | Facilitator shows screenshot | Team opens actual AWS Console |
| **Running AWS CLI command** | Team says "I would run..." | Team actually runs command |
| **Sending user notification** | Team drafts email text | Email actually sent to users |
| **Rotating credentials** | Team describes steps | Credentials actually rotated |

### Pros ✅
- **Zero risk** - Can't break anything
- **Fast** - No waiting for actual deployments
- **Flexible** - Facilitator can skip/speed up boring parts
- **Cheap** - No AWS costs
- **Safe for beginners** - Can make mistakes without consequences
- **Can practice rare scenarios** - Don't need actual breach

### Cons ❌
- **Not realistic** - Missing the stress/urgency
- **No muscle memory** - Not actually typing commands
- **Can't discover tool issues** - Don't know if scripts work
- **Easy to say "I would..." but harder to actually do it**

### Best For
- ✅ First-time practice
- ✅ New team members
- ✅ Testing communication/coordination
- ✅ Validating runbooks
- ✅ Rare scenarios (security breach, data loss)
- ✅ Regular quarterly training

---

## 2. 🔥 Fire Drill (Controlled Real Execution)

### What It Means
- **Actually execute commands in a SAFE environment**
- Use a **sandbox/dev AWS account**
- **Really run** the incident response scripts
- **Real systems**, but isolated from production
- Team physically performs actions

### Example Flow

**Pre-Setup**: Facilitator creates a dev environment that mirrors production

**Exercise Starts**: Facilitator **actually triggers** an alarm (e.g., manually break a Lambda function)

**Team responds**: 
1. Really receives the alarm email
2. Actually opens AWS Console
3. Actually runs: `aws cloudwatch describe-alarms --state-value ALARM`
4. Sees real output from real AWS
5. Actually executes fix commands
6. Verifies the fix worked

### What Happens

| Activity | Fire Drill | Production Incident |
|----------|------------|---------------------|
| **Environment** | Dev/Staging sandbox | Production |
| **Data** | Test data | Real user data |
| **User impact** | None (isolated) | Real users affected |
| **Commands** | Really executed | Really executed |
| **Tools** | Same as production | Same tools |
| **Stress level** | Medium | High |

### Pros ✅
- **Realistic** - Actually using the tools
- **Builds muscle memory** - Typing real commands
- **Discovers tool issues** - Find broken scripts before real incident
- **More engaging** - Feels like the real thing
- **Validates automation** - Scripts actually run

### Cons ❌
- **Requires setup** - Need dev/staging environment
- **Costs money** - AWS resources for sandbox
- **Time-consuming** - Can't skip boring parts
- **Can still break things** - Might mess up dev environment
- **Limited scenarios** - Hard to simulate data breach

### Best For
- ✅ After successful tabletop exercises
- ✅ Testing incident response automation/scripts
- ✅ Validating runbooks work in practice
- ✅ Building confidence before production
- ✅ Common scenarios (API errors, DB throttling)

---

## 3. 🎯 Red Team Exercise (Simulated Attack)

### What It Means
- **Real attack simulation against production** (or prod-like)
- "Red team" (attackers) vs "Blue team" (defenders)
- Red team uses real hacking tools
- Blue team uses real incident response
- **Highest realism, highest risk**

### Example Flow

**Pre-Setup**: Red team is told "try to breach the system" (within rules)

**Exercise Starts**: Red team launches credential stuffing attack against **real** Cognito

**Blue team**: 
- Actually receives real CloudWatch alarms
- Actually investigates real CloudTrail logs
- Actually blocks real IP addresses
- Actually rotates real credentials

**Difference**: It's planned and controlled, with safety measures

### Safety Measures
- Done outside business hours
- Red team has strict rules (no data deletion, etc.)
- Blue team knows it's an exercise (but not when it starts)
- Rollback plan ready
- Management approval required

### Pros ✅
- **Maximum realism** - Actual attack, actual response
- **Tests production defenses** - Real security posture
- **Finds gaps** - Discovers what you'd miss in simulation
- **Ultimate validation** - Know your team can handle real incidents

### Cons ❌
- **High risk** - Can cause real outages
- **Expensive** - Requires red team expertise
- **Stressful** - Feels like real emergency
- **Complex coordination** - Need management buy-in
- **Potential user impact** - Even with safeguards

### Best For
- ✅ Mature teams with proven processes
- ✅ After multiple tabletop + fire drills
- ✅ Annual or semi-annual validation
- ✅ Compliance requirements (e.g., financial services)
- ✅ High-security environments

---

## Recommendation: Progressive Approach

### Phase 1: Monthly - Tabletop Exercise
**Start here** for your team.

```
Month 1: Tabletop - Security Incident
Month 2: Tabletop - API High Error Rate  
Month 3: Tabletop - Database Corruption
Month 4: Review & update runbooks
```

**Goal**: Everyone knows the runbooks and can talk through responses.

---

### Phase 2: Quarterly - Fire Drill (Dev Environment)

**After 3-4 successful tabletops**, do real execution in dev.

```powershell
# Example: Actually break something in dev
# Then practice fixing it

# 1. Facilitator "breaks" dev Lambda
aws lambda update-function-code `
  --function-name d1-personal-note-write-dev `
  --zip-file fileb://broken-code.zip

# 2. Team detects (real alarm)
# 3. Team investigates (real logs)
# 4. Team fixes (real deployment)
sam deploy --parameter-overrides Environment=dev
```

**Goal**: Validate that scripts and tools actually work.

---

### Phase 3: Annual - Game Day (Partial Production)

**After successful fire drills**, introduce controlled chaos in production.

Example: Netflix Chaos Monkey approach
- Randomly terminate 1 Lambda function during business hours
- Team must detect and recover
- Real users might be affected (brief, minor)
- Management informed but not team

**Goal**: Build confidence in production responses.

---

### Phase 4: Optional - Red Team Exercise

**Only for mature teams** with security compliance requirements.

**Goal**: Validate defenses against realistic adversary.

---

## For Your d1-personal-note Application

### I Recommend Starting With:

#### Week 1-2: Tabletop Exercise (Using the doc I created)
```
✅ Safe - No risk to production
✅ Fast - 90 minutes
✅ Educational - Builds knowledge
✅ No setup needed - Just a meeting room
```

**How to prepare**:
1. Schedule 90-minute meeting
2. Assign roles (IC, Tech Lead, Security Lead)
3. Print the runbook
4. Have facilitator read scenario injections
5. Team discusses responses
6. Debrief afterward

**Example conversation**:
```
Facilitator: "You see 47 authentication errors. What do you do?"

Tech Lead: "I would run this command to check Cognito metrics:
            aws cloudwatch get-metric-statistics..."

Facilitator: "OK, here's what you see..." (shows prepared output)

Security Lead: "Based on this, I recommend checking CloudTrail for..."

Incident Commander: "Agreed. Severity is P2, escalating to P1 if..."
```

#### Month 2-3: Fire Drill in Dev (After tabletop success)
```
1. Set up dev environment that mirrors production
2. Facilitator actually triggers an issue
3. Team actually fixes it
4. Verify automation works
```

**Example**:
```powershell
# Facilitator breaks dev Lambda
aws lambda update-function-configuration `
  --function-name d1-personal-note-write-dev `
  --environment Variables={TABLE_NAME=wrong-table-name}

# Real alarm triggers
# Team really responds
# Team really fixes it
```

---

## Common Questions

### Q: "Isn't tabletop less valuable since it's not real?"

**A**: No! Even experts do tabletops because:
- ✅ **Communication** matters more than commands - Tabletops test this
- ✅ **Decision-making** under pressure - Tabletops practice this
- ✅ **Process gaps** - Tabletops reveal these
- ✅ **Cost/benefit** - 80% of learning for 5% of effort

### Q: "Should we skip tabletop and go straight to fire drill?"

**A**: **No, bad idea!** Here's why:
- ❌ Team doesn't know the runbooks yet
- ❌ Scripts might not work → frustration
- ❌ Wastes time on basic confusion
- ❌ Demoralizing if team struggles

**Better**: Tabletop first (learn), Fire drill second (validate).

### Q: "Can we do a surprise fire drill (team doesn't know)?"

**A**: **Not recommended for first exercise**. 
- ✅ **First time**: Announce it's an exercise
- ✅ **Second time**: Announce but don't say when
- ✅ **Third time+**: Consider surprise (with management approval)

### Q: "What if we don't have a dev environment?"

**A**: Start with tabletops. Then:
1. Use AWS Free Tier to create small dev environment
2. Or use prod but with **read-only** actions only
3. Or wait until you have proper dev/staging

---

## Practical Exercise Plan for You

### Option A: Conservative (Recommended for most teams)

```
Month 1: Tabletop - Security Incident (discussion only)
Month 2: Tabletop - API High Error Rate (discussion only)
Month 3: Tabletop - Database Corruption (discussion only)
Month 4: Fire Drill in Dev - API Error (real execution, dev environment)
Month 5: Fire Drill in Dev - Database issue (real execution, dev environment)
Month 6: Review and update runbooks based on learnings
```

### Option B: Aggressive (For experienced teams)

```
Week 1: Tabletop - Security Incident
Week 2: Review & update scripts
Week 3: Fire Drill in Dev - Same scenario
Week 4: Debrief and create action items
Month 2: Repeat for different scenario
```

### Option C: Minimal (If time-constrained)

```
Quarterly: 90-min tabletop exercise (different scenario each time)
Annually: 2-hour fire drill in dev
As needed: Update runbooks
```

---

## My Specific Recommendation for You

Based on your application:

### Step 1: Do the Tabletop Exercise I Created (This Week)
- ✅ **Risk**: None
- ✅ **Time**: 90 minutes
- ✅ **Benefits**: Learn processes, identify gaps, build confidence
- ✅ **Cost**: Free

**Action**: Schedule meeting, assign roles, run exercise

### Step 2: Review Learnings (Next Week)
- Document what worked / didn't work
- Update runbooks
- Fix any broken scripts
- Add missing monitoring

### Step 3: Create Dev Environment (Month 2)
- Set up sandbox AWS account or use dev stage
- Deploy same infrastructure as production
- Add test data

### Step 4: Fire Drill in Dev (Month 2-3)
- Actually break something
- Team actually fixes it
- Validate automation works

### Step 5: Iterate (Ongoing)
- Monthly or quarterly tabletops
- Document each exercise
- Gradually increase realism

---

## Summary Table

| Type | Real Execution? | Risk | Cost | Learning | When to Use |
|------|----------------|------|------|----------|-------------|
| **Tabletop** | ❌ Discussion only | None | Free | High | First time, regular practice |
| **Fire Drill** | ✅ Real commands in dev | Low | Medium | Very High | After tabletops, validate tools |
| **Red Team** | ✅ Real attack on prod | High | High | Maximum | Mature teams only |

---

## Bottom Line

**For the tabletop exercise I created**:
- ✅ It is **discussion-based** (simulation)
- ✅ **NO real commands** are executed
- ✅ **NO emails** are actually sent
- ✅ Team **talks through** what they would do
- ✅ This is **intentional and recommended**
- ✅ Safe way to learn without risk

**After successful tabletops**, you can progress to:
- Fire drills (real execution in dev)
- Game days (controlled chaos)
- Red team exercises (simulated attacks)

**Start with tabletop. It's not "less valuable" - it's the foundation!** Even NASA and military do tabletop exercises before real missions.

---

**Document Version**: 1.0  
**Last Updated**: 2025-12-28  
**Recommendation**: Start with tabletop, progress to fire drills over 3-6 months
