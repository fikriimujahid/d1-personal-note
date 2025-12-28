# d1-personal-note Architecture Document

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Architecture Diagram](#architecture-diagram)
4. [Service Selection & Justification](#service-selection--justification)
5. [Tech Stack](#tech-stack)
6. [Security Model](#security-model)
7. [Disaster Recovery Strategy](#disaster-recovery-strategy)
8. [Cost Management](#cost-management)
9. [Monitoring & Observability](#monitoring--observability)
10. [Future Considerations](#future-considerations)

---

## Executive Summary

**d1-personal-note** is a modern, serverless personal note-taking application built on AWS. The application follows a cloud-native architecture pattern, leveraging AWS managed services to minimize operational overhead while maximizing scalability, security, and cost-efficiency.

### Key Characteristics
- **Serverless-First Architecture**: No servers to manage, pay-per-use pricing
- **Single-Page Application (SPA)**: Modern React-based frontend
- **REST API**: Lambda-backed API Gateway for backend operations
- **NoSQL Database**: DynamoDB for flexible, scalable data storage
- **Infrastructure as Code**: Terraform + AWS SAM for reproducible deployments

---

## Architecture Overview

The application consists of three main tiers:

1. **Presentation Tier**: React SPA hosted on S3, delivered via CloudFront CDN
2. **Application Tier**: Serverless API using AWS Lambda behind API Gateway
3. **Data Tier**: DynamoDB for persistent storage, Cognito for identity management

### High-Level Flow
```
User → Route53 → CloudFront → S3 (Frontend Assets)
                     ↓
User → Route53 → API Gateway → Lambda → DynamoDB
                     ↓
              Cognito (Authentication)
```

---

## Architecture Diagram

### Complete System Architecture

```mermaid
flowchart TB
    subgraph Users["👤 Users"]
        Browser["Web Browser"]
        Mobile["Mobile Browser"]
    end

    subgraph DNS["DNS Layer"]
        Route53["🌐 Route53\n(DNS Management)"]
    end

    subgraph CDN["Content Delivery"]
        CloudFront["⚡ CloudFront\n(CDN + WAF)"]
    end

    subgraph Frontend["Frontend Tier"]
        S3_Frontend["📦 S3 Bucket\n(Static Assets)"]
    end

    subgraph Security["Security & Identity"]
        Cognito["🔐 Cognito\n(User Pool)"]
        WAF["🛡️ WAF v2\n(Web Firewall)"]
    end

    subgraph API["API Tier"]
        APIGateway["🚪 API Gateway\n(REST API)"]
        LambdaRead["λ Lambda Read\n(Node.js 24.x)"]
        LambdaWrite["λ Lambda Write\n(Node.js 24.x)"]
        SQS_DLQ["📨 SQS DLQ\n(Dead Letter Queue)"]
    end

    subgraph Data["Data Tier"]
        DynamoDB["🗄️ DynamoDB\n(Notes Table)"]
    end

    subgraph Monitoring["Monitoring & Observability"]
        CloudWatch["📊 CloudWatch\n(Logs & Metrics)"]
        XRay["🔍 X-Ray\n(Tracing)"]
        SNS["📢 SNS\n(Alerts)"]
    end

    subgraph IaC["Infrastructure as Code"]
        Terraform["🏗️ Terraform\n(Infrastructure)"]
        SAM["📜 AWS SAM\n(API Stack)"]
        GitHub["🐙 GitHub Actions\n(CI/CD)"]
    end

    %% User Flow
    Browser --> Route53
    Mobile --> Route53
    Route53 --> CloudFront
    
    %% Frontend Flow
    CloudFront --> S3_Frontend
    CloudFront --> WAF
    WAF --> APIGateway
    
    %% API Flow
    APIGateway --> Cognito
    APIGateway --> LambdaRead
    APIGateway --> LambdaWrite
    LambdaRead --> DynamoDB
    LambdaWrite --> DynamoDB
    LambdaRead --> SQS_DLQ
    LambdaWrite --> SQS_DLQ
    
    %% Monitoring
    LambdaRead --> CloudWatch
    LambdaWrite --> CloudWatch
    LambdaRead --> XRay
    LambdaWrite --> XRay
    CloudWatch --> SNS
    
    %% IaC
    Terraform --> Frontend
    Terraform --> Security
    SAM --> API
    GitHub --> Terraform
    GitHub --> SAM

    style CloudFront fill:#ff9900,color:#000
    style S3_Frontend fill:#569a31,color:#fff
    style Cognito fill:#dd344c,color:#fff
    style APIGateway fill:#ff4f8b,color:#fff
    style LambdaRead fill:#ff9900,color:#000
    style LambdaWrite fill:#ff9900,color:#000
    style DynamoDB fill:#4053d6,color:#fff
    style WAF fill:#ff5722,color:#fff
    style CloudWatch fill:#ff4f8b,color:#fff
```

### Request Flow Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant CF as CloudFront
    participant S3 as S3 (Frontend)
    participant AG as API Gateway
    participant CG as Cognito
    participant LR as Lambda (Read)
    participant LW as Lambda (Write)
    participant DB as DynamoDB

    Note over U,DB: Static Content Request
    U->>CF: GET /index.html
    CF->>S3: Fetch static assets
    S3-->>CF: HTML/JS/CSS
    CF-->>U: Cached content

    Note over U,DB: Authentication Flow
    U->>CG: Sign In (SRP)
    CG-->>U: JWT Tokens (ID, Access, Refresh)

    Note over U,DB: API Read Request
    U->>AG: GET /notes (+ JWT)
    AG->>CG: Validate JWT
    CG-->>AG: Token Valid ✓
    AG->>LR: Invoke Lambda
    LR->>DB: Query Notes
    DB-->>LR: Notes Data
    LR-->>AG: Response
    AG-->>U: JSON Response

    Note over U,DB: API Write Request
    U->>AG: POST /notes (+ JWT + Body)
    AG->>CG: Validate JWT
    CG-->>AG: Token Valid ✓
    AG->>LW: Invoke Lambda
    LW->>DB: PutItem
    DB-->>LW: Success
    LW-->>AG: Response
    AG-->>U: Created Response
```

### Infrastructure Deployment Pipeline

```mermaid
flowchart LR
    subgraph Development["Development"]
        Code["📝 Code Changes"]
        Tests["🧪 Tests"]
    end

    subgraph CI["CI Pipeline"]
        Lint["ESLint/Checkov"]
        Security["🔒 Security Scans"]
        Build["🔨 Build"]
    end

    subgraph CD["CD Pipeline"]
        TF_Plan["Terraform Plan"]
        TF_Apply["Terraform Apply"]
        SAM_Deploy["SAM Deploy"]
        FE_Deploy["Frontend Deploy"]
    end

    subgraph AWS["AWS Environment"]
        Infra["Infrastructure"]
        API["API Stack"]
        Frontend["Frontend"]
    end

    Code --> Tests
    Tests --> Lint
    Lint --> Security
    Security --> Build
    Build --> TF_Plan
    TF_Plan --> TF_Apply
    TF_Apply --> Infra
    Build --> SAM_Deploy
    SAM_Deploy --> API
    Build --> FE_Deploy
    FE_Deploy --> Frontend

    style Security fill:#f44336,color:#fff
    style TF_Apply fill:#844fba,color:#fff
    style SAM_Deploy fill:#ff9900,color:#000
```

---

## Service Selection & Justification

### Frontend Hosting

| Service | Selection | Justification |
|---------|-----------|---------------|
| **Amazon S3** | Selected | Cost-effective static hosting, high durability (11 9's), native AWS integration |
| **Amazon CloudFront** | Selected | Global CDN with 400+ edge locations, built-in DDoS protection, HTTPS enforcement |
| **AWS WAF v2** | Selected | Protects against OWASP Top 10 attacks, rate limiting for DDoS mitigation |
| **Route53** | Selected | DNS management with health checks, supports alias records for AWS services |
| **ACM** | Selected | Free SSL/TLS certificates for CloudFront, automatic renewal |

**Alternative Considered**: AWS Amplify Hosting
- *Rejected*: Less control over infrastructure, higher cost at scale

### API Layer

| Service | Selection | Justification |
|---------|-----------|---------------|
| **API Gateway (REST)** | Selected | Managed API service, built-in throttling, native Cognito integration |
| **AWS Lambda** | Selected | Serverless compute, pay-per-invocation, automatic scaling to zero |
| **Node.js 24.x Runtime** | Selected | LTS support, TypeScript compatibility, fast cold starts |
| **SQS Dead Letter Queue** | Selected | Captures failed invocations for debugging and replay |

**Alternative Considered**: HTTP API (API Gateway v2)
- *Rejected*: Limited authorizer caching, fewer features than REST API

**Alternative Considered**: AppSync (GraphQL)
- *Rejected*: GraphQL complexity not needed for simple CRUD operations

### Data Storage

| Service | Selection | Justification |
|---------|-----------|---------------|
| **Amazon DynamoDB** | Selected | Serverless NoSQL, single-digit millisecond latency, automatic scaling |
| **On-Demand Billing** | Selected | Pay-per-request, ideal for variable/unpredictable workloads |
| **Point-in-Time Recovery** | Recommended | Continuous backups, 35-day recovery window, ~5-min RPO |

**Alternative Considered**: Amazon RDS (PostgreSQL)
- *Rejected*: Requires capacity planning, higher baseline cost, server management

**Alternative Considered**: Amazon Aurora Serverless v2
- *Rejected*: Higher cost, more complex for simple key-value access patterns

### Authentication & Authorization

| Service | Selection | Justification |
|---------|-----------|---------------|
| **Amazon Cognito User Pools** | Selected | Managed identity service, MFA support, OAuth2/OIDC compliant |
| **SRP Authentication** | Selected | Secure Remote Password protocol, passwords never sent over network |
| **JWT Tokens** | Selected | Stateless authentication, API Gateway native validation |

**Alternative Considered**: Auth0 / Okta
- *Rejected*: Third-party dependency, additional cost, less AWS integration

**Alternative Considered**: Custom JWT with self-managed user store
- *Rejected*: Security risk, maintenance burden, no managed MFA

### Infrastructure as Code

| Service | Selection | Justification |
|---------|-----------|---------------|
| **Terraform** | Selected | Multi-cloud support, robust state management, mature ecosystem |
| **AWS SAM** | Selected | Simplified Lambda/API Gateway deployment, local testing support |
| **S3 + DynamoDB Backend** | Selected | Remote state with locking prevents concurrent modifications |

**Alternative Considered**: AWS CDK
- *Rejected*: Steeper learning curve, less declarative than Terraform

**Alternative Considered**: CloudFormation Only
- *Rejected*: Verbose syntax, limited abstraction capabilities

---

## Tech Stack

### Frontend

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Core Framework** | React | 18.3.1 | Component-based UI library |
| **Language** | TypeScript | ~5.9 | Type-safe JavaScript |
| **Build Tool** | Vite | 7.2.7 | Fast ESM-based bundler |
| **Styling** | Tailwind CSS | 4.1.18 | Utility-first CSS framework |
| **UI Components** | Material-UI (MUI) | 7.3.6 | Pre-built React components |
| **UI Primitives** | Radix UI | Various | Accessible component primitives |
| **HTTP Client** | Axios | 1.13.2 | HTTP requests with interceptors |
| **State Management** | TanStack React Query | 5.90.12 | Server state caching & synchronization |
| **Routing** | React Router | v6 | Client-side navigation |
| **Authentication** | AWS Amplify | 6.15.9 | Cognito SDK integration |
| **Testing** | Vitest | 4.0.16 | Vite-native test runner |
| **Testing Library** | React Testing Library | 16.3.1 | Component testing utilities |

### Backend (API)

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Runtime** | Node.js | 24.x | Lambda execution environment |
| **Language** | TypeScript | 5.9.3 | Type-safe JavaScript |
| **AWS SDK** | @aws-sdk/client-dynamodb | 3.954.0 | DynamoDB operations |
| **ID Generation** | ULID | 3.0.2 | Universally unique lexicographically sortable IDs |
| **Testing** | Jest | 30.2.0 | Unit testing framework |
| **Build** | esbuild | 0.27.2 | Fast TypeScript compilation |

### Infrastructure

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **IaC (Infrastructure)** | Terraform | >= 1.0 | Core infrastructure provisioning |
| **IaC (Serverless)** | AWS SAM | Latest | Lambda/API Gateway deployment |
| **AWS Provider** | hashicorp/aws | ~> 5.0 | Terraform AWS resources |
| **State Backend** | S3 + DynamoDB | - | Remote state with locking |

### Security Scanning

| Tool | Purpose |
|------|---------|
| **Checkov** | Infrastructure security scanning |
| **Semgrep** | Static code analysis |
| **Gitleaks** | Secrets detection |
| **OWASP Dependency Check** | Vulnerability scanning |
| **OWASP ZAP** | Dynamic application security testing |
| **detect-secrets** | Pre-commit secrets detection |

---

## Security Model

### Defense in Depth Architecture

```mermaid
flowchart TB
    subgraph Layer1["Layer 1: Network Edge"]
        DNS["Route53 DNS"]
        CloudFront["CloudFront CDN"]
        WAF["AWS WAF v2"]
    end

    subgraph Layer2["Layer 2: API Security"]
        APIGW["API Gateway"]
        Cognito["Cognito Authorizer"]
        RateLimit["Rate Limiting"]
    end

    subgraph Layer3["Layer 3: Application Security"]
        Lambda["Lambda Functions"]
        InputValidation["Input Validation"]
        ErrorHandling["Safe Error Handling"]
    end

    subgraph Layer4["Layer 4: Data Security"]
        DynamoDB["DynamoDB"]
        Encryption["Server-Side Encryption"]
        IAM["Least Privilege IAM"]
    end

    Layer1 --> Layer2
    Layer2 --> Layer3
    Layer3 --> Layer4

    style WAF fill:#f44336,color:#fff
    style Cognito fill:#dd344c,color:#fff
    style Encryption fill:#4caf50,color:#fff
```

### Authentication & Authorization

| Control | Implementation | Details |
|---------|----------------|---------|
| **User Authentication** | AWS Cognito User Pools | Email-based sign-up/sign-in with verification |
| **Password Policy** | Cognito Configuration | Min 8 chars, uppercase, lowercase, numbers, symbols |
| **MFA** | Optional (Configurable) | TOTP-based second factor |
| **Token Management** | JWT (ID, Access, Refresh) | 60-min access tokens, 30-day refresh tokens |
| **Session Handling** | Cognito Managed | Token revocation, device tracking |
| **Authorization** | User-Scoped Data | All queries filtered by authenticated userId |

### Transport Security

| Control | Implementation |
|---------|----------------|
| **TLS Version** | TLSv1.2_2021 minimum |
| **HTTPS Enforcement** | CloudFront redirect HTTP→HTTPS |
| **Certificate Management** | ACM with auto-renewal |
| **HSTS Headers** | CloudFront Security Headers Policy |

### Data Security

| Control | Implementation |
|---------|----------------|
| **Encryption at Rest** | DynamoDB SSE (AWS-owned key) |
| **S3 Encryption** | AES-256 server-side encryption |
| **CloudWatch Logs** | Optional KMS encryption |
| **SNS Topics** | AWS-managed KMS encryption |
| **Terraform State** | S3 versioning + DynamoDB locking |

### API Security

| Control | Implementation |
|---------|----------------|
| **CORS** | Configured allowed origins, methods, headers |
| **Input Validation** | Request body validation in Lambda handlers |
| **Error Handling** | Typed errors mapped to HTTP status codes |
| **Rate Limiting** | WAF rate-based rules (configurable limit) |
| **Request Tracing** | X-Ray distributed tracing |

### Infrastructure Security

| Control | Implementation |
|---------|----------------|
| **S3 Public Access Block** | All public access blocked |
| **Least Privilege IAM** | Function-specific policies (DynamoDBReadPolicy, DynamoDBCrudPolicy) |
| **Resource Tagging** | Environment, project, managed_by tags |
| **Deletion Protection** | Cognito User Pool, DynamoDB (configurable) |

### Web Application Firewall (WAF)

| Rule Set | Protection |
|----------|------------|
| **AWS Managed Core Rules** | OWASP Top 10 (SQLi, XSS, LFI, etc.) |
| **Rate Limiting** | Configurable requests per 5-minute window |
| **Visibility** | CloudWatch metrics, sampled requests |

### Security Scanning & DevSecOps

| Phase | Tools |
|-------|-------|
| **Pre-commit** | detect-secrets, gitleaks |
| **SAST** | Semgrep, Checkov |
| **SCA** | OWASP Dependency Check |
| **DAST** | OWASP ZAP (baseline + API scans) |
| **IaC Scanning** | Checkov (Terraform, SAM templates) |

---

## Disaster Recovery Strategy

### Recovery Objectives

| Metric | Definition | Target |
|--------|------------|--------|
| **RPO** | Recovery Point Objective (max data loss) | 5 minutes (DynamoDB PITR) |
| **RTO** | Recovery Time Objective (max downtime) | 2 hours (full recovery) |

### Component-Level Objectives

| Component | RPO | RTO | DR Strategy |
|-----------|-----|-----|-------------|
| **DynamoDB (Notes)** | 5 minutes | 1 hour | Point-in-Time Recovery (PITR) |
| **Cognito User Pool** | 24 hours | 4 hours | AWS Managed + User Export |
| **S3 (Frontend)** | 0 (Zero) | 30 minutes | Git repo + rebuild |
| **Lambda Functions** | 0 (Zero) | 15 minutes | Git repo + SAM deploy |
| **API Gateway** | 0 (Zero) | 15 minutes | SAM template |
| **CloudFront** | 0 (Zero) | 30 minutes | Terraform |
| **Terraform State** | Immediate | 1 hour | S3 versioning |

### Backup Strategy

```mermaid
flowchart LR
    subgraph Continuous["Continuous Backups"]
        PITR["DynamoDB PITR\n(35-day retention)"]
        S3Ver["S3 Versioning\n(180-day lifecycle)"]
        TFState["Terraform State\n(S3 versioning)"]
    end

    subgraph Scheduled["Scheduled Backups"]
        CognitoExp["Cognito User Export\n(Weekly)"]
        OnDemand["DynamoDB On-Demand\n(Before changes)"]
    end

    subgraph IaC["Code as Backup"]
        Git["Git Repository\n(All source code)"]
        IaCDef["Terraform + SAM\n(Infrastructure)"]
    end

    style PITR fill:#4caf50,color:#fff
    style Git fill:#2196F3,color:#fff
```

### Recovery Procedures

| Scenario | Procedure | Recovery Time |
|----------|-----------|---------------|
| **Accidental Data Deletion** | DynamoDB PITR restore to new table | 1 hour |
| **Ransomware/Encryption** | PITR restore + credential rotation | 2 hours |
| **Lambda Code Corruption** | SAM redeploy from Git | 15 minutes |
| **Frontend Corruption** | npm build + S3 sync | 30 minutes |
| **Full Infrastructure Failure** | Terraform apply + SAM deploy | 2 hours |
| **Terraform State Corruption** | S3 version restore or import | 1 hour |
| **Cognito User Pool Deletion** | Recreate + user import | 4 hours |

### Testing Schedule

| Test Type | Frequency |
|-----------|-----------|
| DynamoDB PITR Restore | Quarterly |
| Lambda Rollback | Monthly |
| Frontend Rebuild | Monthly |
| Full Infrastructure Restore | Annually |
| Terraform State Recovery | Semi-annually |

### Multi-Region Considerations (Future)

For enhanced disaster recovery, consider:
1. **DynamoDB Global Tables** for cross-region replication
2. **S3 Cross-Region Replication** for static assets
3. **Route53 Health Checks** with failover routing
4. **Multi-region Terraform state** with regional backends

---

## Cost Management

### Monthly Cost Estimation (Low Traffic)

| Service | Estimated Cost | Notes |
|---------|----------------|-------|
| **Lambda** | $0-5 | First 1M requests free |
| **API Gateway** | $3-10 | $3.50 per million requests |
| **DynamoDB (On-Demand)** | $1-5 | Pay per read/write unit |
| **S3 + CloudFront** | $5-15 | Storage + data transfer |
| **Cognito** | $0-5 | First 50,000 MAUs free |
| **Route53** | $0.50-1 | Hosted zone + queries |
| **CloudWatch** | $0-5 | Logs + metrics |
| **WAF** | $5-10 | Web ACL + rules |
| **Total Estimate** | **$15-56/month** | Low-traffic workload |

### Cost Controls

| Control | Implementation |
|---------|----------------|
| **AWS Budgets** | Monthly alerts at 80% and 100% threshold |
| **On-Demand Throughput Limits** | DynamoDB max request units |
| **Lambda Memory Optimization** | 128 MB default (increase as needed) |
| **CloudFront Price Class** | PriceClass_100 (fewer edge locations) |
| **S3 Lifecycle Policies** | Transition to IA/Glacier, delete old versions |

---

## Monitoring & Observability

### CloudWatch Alarms

| Category | Metric | Threshold | Severity |
|----------|--------|-----------|----------|
| **API Health** | 5XXError | > 10 per 5min | Critical |
| **API Health** | 4XXError | > 100 per 5min | Warning |
| **API Latency** | Latency | > 3 seconds | Warning |
| **Lambda** | Errors | > 0 | Critical |
| **Lambda** | Throttles | > 0 | Critical |
| **Lambda** | Duration | > 8 seconds | Warning |
| **DynamoDB** | ReadThrottleEvents | > 5 | Critical |
| **DynamoDB** | WriteThrottleEvents | > 5 | Critical |
| **CloudFront** | 5xxErrorRate | > 1% | Critical |
| **Cognito** | UserAuthenticationErrors | > 10 | Warning |

### Composite Alarms

- **API Health Critical**: Triggers if ANY of: 5XX errors, Lambda errors, or Lambda throttles

### Dashboards

- **Incident Response Dashboard**: API Gateway, Lambda, DynamoDB metrics
- **CloudWatch Insights Queries**: Lambda errors, performance analysis

### Tracing

- **AWS X-Ray**: Enabled for Lambda functions and API Gateway
- **Distributed Tracing**: End-to-end request tracking

---

## Future Considerations

### Scalability Improvements
- [ ] DynamoDB Global Tables for multi-region support
- [ ] Lambda Provisioned Concurrency for consistent latency
- [ ] ElastiCache for frequently accessed data

### Feature Enhancements
- [ ] Real-time sync with AppSync/WebSockets
- [ ] File attachments with S3 presigned URLs
- [ ] Full-text search with OpenSearch

### Security Enhancements
- [ ] AWS Shield Advanced for enhanced DDoS protection
- [ ] AWS Secrets Manager for sensitive configuration
- [ ] VPC Endpoints for private AWS service access

### Operational Improvements
- [ ] Automated Chaos Engineering (AWS Fault Injection Simulator)
- [ ] Canary deployments with Lambda aliases
- [ ] Automated runbooks with Systems Manager

---

## Document Information

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Created** | 2025-12-28 |
| **Author** | Architecture Team |
| **Last Updated** | 2025-12-28 |
| **Next Review** | 2026-03-28 |
| **Status** | Active |

### Related Documents
- [Disaster Recovery Plan](disaster-recovery.md)
- [Incident Response Plan](incident-response.md)
- [Disaster Recovery Exercise Guide](disaster-recovery-exercise.md)
