# Architecture Decision Log

## Overview

This document records all significant architectural and technology decisions made for the **d1-personal-note** application. Each decision follows the format: Context → Options → Chosen → Rationale.

**Document Status**: Active  
**Last Updated**: 2025-12-28  
**Version**: 1.0

---

## Table of Contents

1. [ADR-001: Frontend Hosting Strategy](#adr-001-frontend-hosting-strategy)
2. [ADR-002: Content Delivery Network Selection](#adr-002-content-delivery-network-selection)
3. [ADR-003: Web Application Firewall Implementation](#adr-003-web-application-firewall-implementation)
4. [ADR-004: DNS Management Service](#adr-004-dns-management-service)
5. [ADR-005: SSL/TLS Certificate Management](#adr-005-ssltls-certificate-management)
6. [ADR-006: API Gateway Type Selection](#adr-006-api-gateway-type-selection)
7. [ADR-007: Serverless Compute Platform](#adr-007-serverless-compute-platform)
8. [ADR-008: API Runtime Environment](#adr-008-api-runtime-environment)
9. [ADR-009: Failed Invocation Handling](#adr-009-failed-invocation-handling)
10. [ADR-010: API Architecture Pattern](#adr-010-api-architecture-pattern)
11. [ADR-011: Database Technology Selection](#adr-011-database-technology-selection)
12. [ADR-012: Database Billing Model](#adr-012-database-billing-model)
13. [ADR-013: Data Backup Strategy](#adr-013-data-backup-strategy)
14. [ADR-014: Authentication Provider](#adr-014-authentication-provider)
15. [ADR-015: Authentication Protocol](#adr-015-authentication-protocol)
16. [ADR-016: Token Management Strategy](#adr-016-token-management-strategy)
17. [ADR-017: Infrastructure as Code Framework](#adr-017-infrastructure-as-code-framework)
18. [ADR-018: Serverless Deployment Tool](#adr-018-serverless-deployment-tool)
19. [ADR-019: Terraform State Backend](#adr-019-terraform-state-backend)
20. [ADR-020: Frontend Framework Selection](#adr-020-frontend-framework-selection)
21. [ADR-021: Build Tool Selection](#adr-021-build-tool-selection)
22. [ADR-022: State Management Strategy](#adr-022-state-management-strategy)

---

## Frontend Infrastructure Decisions

### ADR-001: Frontend Hosting Strategy

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Architecture Team

#### Context
Need to select a hosting solution for the React SPA that is cost-effective, scalable, and easy to manage.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Amazon S3** | Cost-effective ($0.023/GB), 99.999999999% durability, native AWS integration, versioning support | No built-in CDN, requires additional services for HTTPS |
| **AWS Amplify Hosting** | Integrated CI/CD, automatic builds, branch previews, built-in SSL | Higher cost at scale, less infrastructure control, vendor lock-in |
| **Netlify/Vercel** | Excellent DX, automatic deployments, edge functions | Third-party dependency, additional cost, data egress charges |
| **EC2 + Nginx** | Full control, customizable | Server management overhead, scaling complexity, higher cost |

#### Chosen Option
**Amazon S3** for static hosting

#### Rationale
- **Cost**: ~$0.50-2/month for typical usage vs $15-50/month for Amplify
- **Durability**: 11 nines (99.999999999%) data durability
- **Integration**: Native integration with CloudFront, Route53, and other AWS services
- **Simplicity**: No server management, automatic scaling
- **Versioning**: Built-in object versioning for rollback capability
- **IaC Friendly**: Easy to manage via Terraform

---

### ADR-002: Content Delivery Network Selection

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Architecture Team

#### Context
Need a CDN to deliver static assets globally with low latency and built-in security features.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Amazon CloudFront** | 400+ edge locations, native AWS integration, built-in DDoS protection, free SSL via ACM | AWS vendor lock-in |
| **Cloudflare** | Large network, generous free tier, advanced security features | Third-party dependency, additional configuration |
| **Fastly** | Real-time purging, advanced VCL customization | Higher cost, more complex configuration |
| **No CDN** | Simplest setup, lowest cost | Poor global performance, no edge caching |

#### Chosen Option
**Amazon CloudFront**

#### Rationale
- **Performance**: 400+ global edge locations for low-latency delivery
- **Security**: Built-in DDoS protection (AWS Shield Standard included)
- **Cost**: Pay-as-you-go pricing (~$0.085/GB in US/Europe)
- **Integration**: Native OAC (Origin Access Control) for S3 security
- **SSL/TLS**: Free certificates via ACM with automatic renewal
- **HTTPS**: Built-in HTTP to HTTPS redirect
- **Monitoring**: CloudWatch integration for metrics and alarms

---

### ADR-003: Web Application Firewall Implementation

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Security Team

#### Context
Need to protect the application from common web attacks (OWASP Top 10) and DDoS attempts.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **AWS WAF v2** | Managed rule sets, CloudFront integration, rate limiting | Additional cost (~$5-10/month) |
| **Cloudflare WAF** | Included in paid plan, large threat database | Third-party dependency |
| **No WAF** | Zero cost, simpler architecture | Vulnerable to attacks, no rate limiting |

#### Chosen Option
**AWS WAF v2**

#### Rationale
- **OWASP Top 10**: AWS Managed Core Rules protect against SQLi, XSS, LFI, etc.
- **Rate Limiting**: Configurable DDoS protection (e.g., 2000 requests per IP per 5 min)
- **Integration**: Native CloudFront integration
- **Visibility**: CloudWatch metrics and sampled request logging
- **Customization**: Ability to add custom rules as needed
- **Cost**: Acceptable (~$6-8/month for baseline protection)

---

### ADR-004: DNS Management Service

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Infrastructure Team

#### Context
Need DNS management for custom domain with health checks and AWS service integration.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Amazon Route53** | Native AWS integration, alias records, health checks | Slightly higher cost than some registrars |
| **Cloudflare DNS** | Free, fast, includes basic DDoS protection | Requires separate registrar |
| **Domain Registrar DNS** | Included with domain | Limited features, no health checks |

#### Chosen Option
**Amazon Route53**

#### Rationale
- **Alias Records**: Point to AWS services (CloudFront, S3) without IP addresses
- **Health Checks**: Monitor endpoint availability for failover
- **Integration**: Seamless with CloudFront and ACM
- **Reliability**: 100% uptime SLA
- **Cost**: Acceptable (~$0.50/month per hosted zone)

---

### ADR-005: SSL/TLS Certificate Management

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Security Team

#### Context
Need free, automatically renewed SSL/TLS certificates for CloudFront distribution.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **AWS Certificate Manager (ACM)** | Free, automatic renewal, CloudFront integration | Must be in us-east-1 for CloudFront |
| **Let's Encrypt** | Free, widely trusted | Manual renewal process, certificate management overhead |
| **Commercial SSL** | Extended validation options | Annual cost ($50-300/year), manual renewal |

#### Chosen Option
**AWS Certificate Manager (ACM)**

#### Rationale
- **Cost**: Free for AWS-integrated services
- **Automation**: Automatic renewal (no expiration worries)
- **Security**: TLS 1.2+ enforcement
- **Integration**: Native CloudFront support
- **Management**: Zero operational overhead

---

## API Infrastructure Decisions

### ADR-006: API Gateway Type Selection

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Backend Team

#### Context
Need to expose Lambda functions as a REST API with authentication and throttling.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **API Gateway (REST)** | Full feature set, authorizer caching, request/response validation | Slightly higher latency than HTTP API |
| **API Gateway (HTTP API)** | Lower cost (~70% cheaper), lower latency | Limited authorizer caching (300s max), fewer features |
| **AppSync (GraphQL)** | Real-time subscriptions, automatic caching | GraphQL complexity, over-fetching/under-fetching concerns |
| **Lambda Function URLs** | Simplest, no API Gateway cost | No built-in throttling, CORS, or authorizers |

#### Chosen Option
**API Gateway (REST)**

#### Rationale
- **Authorizer Caching**: Up to 3600s (1 hour) JWT validation caching reduces Cognito calls
- **Cognito Integration**: Native Cognito User Pool authorizer support
- **Request Validation**: Built-in request/response validation
- **Throttling**: Account-level and method-level throttling
- **Features**: Request transformation, response mapping, API keys
- **Cost**: $3.50 per million requests (acceptable for expected traffic)

---

### ADR-007: Serverless Compute Platform

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Backend Team

#### Context
Need a compute platform for API backend that scales automatically and minimizes operational overhead.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **AWS Lambda** | Pay-per-invocation, automatic scaling, no server management | Cold starts, 15-min max execution |
| **AWS Fargate** | Container-based, longer execution time | Higher baseline cost, more complex |
| **EC2 Instances** | Full control, no timeout limits | Server management, scaling complexity, higher cost |
| **ECS on EC2** | Container orchestration, cost-effective at scale | Requires cluster management |

#### Chosen Option
**AWS Lambda**

#### Rationale
- **Cost**: First 1M requests/month free, then $0.20 per 1M requests
- **Scaling**: Automatic scaling to zero when idle
- **Operations**: Zero server management, automatic patching
- **Integration**: Native API Gateway, DynamoDB, and CloudWatch integration
- **Development**: Fast iteration with SAM local testing
- **Timeout**: 10 seconds sufficient for CRUD operations

---

### ADR-008: API Runtime Environment

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Backend Team

#### Context
Need to select a runtime for Lambda functions that supports TypeScript and has good cold start performance.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Node.js 24.x** | Fast cold starts (~200ms), TypeScript support, LTS until 2027 | JavaScript ecosystem variability |
| **Python 3.12** | Simple syntax, extensive libraries, good cold starts | Less type safety without mypy |
| **Go 1.x** | Fastest cold starts (~100ms), compiled binary | Steeper learning curve, verbose error handling |
| **Java 21** | Strong typing, mature ecosystem | Slow cold starts (~1-2s), higher memory usage |

#### Chosen Option
**Node.js 24.x**

#### Rationale
- **TypeScript**: Full TypeScript support for type safety
- **Cold Starts**: ~200ms average cold start time
- **LTS**: Long-term support until April 2027
- **Ecosystem**: Rich npm ecosystem (AWS SDK, testing tools)
- **Team Familiarity**: Frontend team also uses TypeScript
- **Tooling**: Excellent IDE support, debugging, and testing tools

---

### ADR-009: Failed Invocation Handling

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Reliability Team

#### Context
Need a mechanism to capture and analyze failed Lambda invocations for debugging and potential replay.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **SQS Dead Letter Queue** | Managed service, message retention, replay capability | Additional cost (~$0.40/million requests) |
| **CloudWatch Logs Only** | Already exists, zero additional cost | No structured retry, difficult to extract failures |
| **No DLQ** | Simplest, zero cost | Lost failure information, no replay capability |

#### Chosen Option
**SQS Dead Letter Queue**

#### Rationale
- **Debugging**: Captures full event payload for failed invocations
- **Retention**: 14-day message retention
- **Replay**: Messages can be reprocessed after fixing bugs
- **Monitoring**: CloudWatch metrics for queue depth
- **Encryption**: KMS encryption for sensitive data
- **Cost**: Minimal (~$0.40 per million failed requests)

---

### ADR-010: API Architecture Pattern

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Backend Team

#### Context
Need to decide on API architecture pattern: monolithic vs microservices vs function-per-endpoint.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Function per Endpoint** | Isolated failures, independent scaling, fine-grained IAM | More functions to manage, potential code duplication |
| **Monolithic Lambda** | Single deployment, shared code, simpler | All-or-nothing deployments, coarse-grained scaling |
| **Microservices** | Domain separation, team autonomy | Over-engineering for small app, operational complexity |

#### Chosen Option
**Function per Operation Type (Read/Write split)**

#### Rationale
- **Separation of Concerns**: Read and write operations have different characteristics
- **Independent Scaling**: Read-heavy workloads don't affect write capacity
- **IAM Least Privilege**: Read function only needs DynamoDBReadPolicy
- **Blast Radius**: Issues in write logic don't affect read operations
- **Simplicity**: Two functions easier to manage than one per endpoint
- **Code Sharing**: Shared utilities (repositories, types, logging) via npm workspace

---

## Data Layer Decisions

### ADR-011: Database Technology Selection

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Backend Team

#### Context
Need a database for storing user notes with flexible schema and automatic scaling.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Amazon DynamoDB** | Serverless, single-digit ms latency, auto-scaling, flexible schema | NoSQL limitations, eventual consistency (default) |
| **Amazon RDS (PostgreSQL)** | Relational model, strong consistency, complex queries | Requires capacity planning, higher baseline cost, server management |
| **Amazon Aurora Serverless v2** | Auto-scaling, PostgreSQL compatible | Higher cost, cold start delays, more complex than DynamoDB |
| **MongoDB Atlas** | Flexible schema, rich query language | Third-party dependency, data egress costs |

#### Chosen Option
**Amazon DynamoDB**

#### Rationale
- **Serverless**: No server provisioning, automatic scaling
- **Performance**: Single-digit millisecond latency at any scale
- **Cost**: Pay-per-request model aligns with usage
- **Availability**: 99.99% SLA, multi-AZ replication
- **Schema Flexibility**: NoSQL model suits varying note structures
- **Integration**: Native Lambda SDK, DynamoDB Streams for events
- **Backup**: Point-in-Time Recovery for 35 days

---

### ADR-012: Database Billing Model

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Finance & Engineering Team

#### Context
Need to choose between provisioned capacity and on-demand billing for DynamoDB.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **On-Demand Billing** | Pay-per-request, no capacity planning, instant scaling | ~5x higher cost per request than provisioned |
| **Provisioned Capacity** | Lower cost at steady traffic, auto-scaling available | Requires forecasting, potential throttling |
| **Reserved Capacity** | Up to 76% savings | 1-3 year commitment, upfront payment |

#### Chosen Option
**On-Demand Billing**

#### Rationale
- **Variable Traffic**: Unpredictable usage patterns (personal note app)
- **Simplicity**: No capacity planning or scaling configuration
- **Cost**: At low traffic (<10M requests/month), on-demand is comparable
- **Flexibility**: Can switch to provisioned if traffic becomes predictable
- **Throttle Protection**: No risk of throttling during traffic spikes
- **Development**: Ideal for development/testing environments

---

### ADR-013: Data Backup Strategy

**Date**: 2025-12-28  
**Status**: Recommended  
**Decision Maker**: Reliability Team

#### Context
Need a backup strategy to protect against data loss from deletion, corruption, or ransomware.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Point-in-Time Recovery (PITR)** | Continuous backups, 5-min RPO, 35-day retention | ~20% of table storage cost |
| **On-Demand Backups** | Manual control, long-term retention | Manual process, coarser RPO |
| **DynamoDB Streams + S3** | Custom retention, cross-region | Requires custom code, operational overhead |
| **No Backups** | Zero cost | Data loss risk unacceptable |

#### Chosen Option
**Point-in-Time Recovery (PITR)** (Recommended)

#### Rationale
- **RPO**: 5-minute Recovery Point Objective
- **Retention**: 35-day recovery window
- **Automation**: Continuous backups, no manual intervention
- **Flexibility**: Restore to any second within 35 days
- **Cost**: ~$0.20/GB per month (acceptable for critical data)
- **Disaster Recovery**: Enables recovery from ransomware, accidental deletion
- **Compliance**: Meets data protection requirements

**Note**: Currently disabled in code to reduce costs for development environments. **Must enable for production.**

---

## Authentication & Identity Decisions

### ADR-014: Authentication Provider

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Security Team

#### Context
Need a managed authentication service that handles user sign-up, sign-in, MFA, and token management.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Amazon Cognito User Pools** | Managed service, MFA support, free tier (50K MAUs), OAuth2/OIDC | AWS vendor lock-in |
| **Auth0** | Excellent UX, social providers, extensive features | $23/month for 1K MAUs, third-party dependency |
| **Okta** | Enterprise features, compliance certifications | Higher cost, over-engineered for small apps |
| **Custom JWT + Database** | Full control, no vendor lock-in | Security risks, no MFA, maintenance burden |

#### Chosen Option
**Amazon Cognito User Pools**

#### Rationale
- **Cost**: First 50,000 monthly active users free
- **MFA**: Built-in TOTP-based multi-factor authentication
- **Password Policy**: Configurable complexity requirements
- **Token Management**: Automatic JWT generation and validation
- **Device Tracking**: Remember devices to reduce MFA prompts
- **Account Recovery**: Email-based password reset
- **API Gateway Integration**: Native authorizer support
- **Deletion Protection**: Prevent accidental user pool deletion

---

### ADR-015: Authentication Protocol

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Security Team

#### Context
Need to select an authentication protocol that keeps passwords secure and works well with SPAs.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **SRP (Secure Remote Password)** | Password never sent over network, cryptographic proof | More complex than basic auth |
| **USER_PASSWORD_AUTH** | Simple, easy to implement | Password sent to Cognito (encrypted), less secure |
| **OAuth2 + PKCE** | Industry standard, works with third-party IdPs | More complex for simple use cases |

#### Chosen Option
**SRP (Secure Remote Password) Authentication**

#### Rationale
- **Security**: Password never leaves client in plaintext
- **Cryptographic Proof**: Zero-knowledge proof of password possession
- **Cognito Native**: First-class support in AWS Amplify
- **No Plaintext**: Even Cognito never sees the actual password
- **MITM Protection**: Resistant to man-in-the-middle attacks
- **AWS Recommendation**: Recommended by AWS for web/mobile apps

---

### ADR-016: Token Management Strategy

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Security Team

#### Context
Need to manage authentication tokens with appropriate lifetimes and security controls.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **JWT (ID + Access + Refresh)** | Stateless, API Gateway native, revocable | Token size, refresh complexity |
| **Cookie-Based Sessions** | Simple, automatic CSRF protection with SameSite | Requires server-side session store |
| **Opaque Tokens** | Smaller size, server-controlled | Requires validation endpoint on every request |

#### Chosen Option
**JWT Tokens (ID + Access + Refresh)**

#### Rationale
- **Access Token**: 60-minute lifetime for API calls
- **Refresh Token**: 30-day lifetime for obtaining new access tokens
- **ID Token**: 60-minute lifetime with user profile information
- **Stateless**: API Gateway validates JWT without database calls
- **Caching**: API Gateway caches validation results for up to 1 hour
- **Revocation**: Token revocation support via Cognito
- **Device Tracking**: Remember trusted devices to reduce re-auth

---

## Infrastructure as Code Decisions

### ADR-017: Infrastructure as Code Framework

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: DevOps Team

#### Context
Need an IaC framework for provisioning and managing AWS infrastructure.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Terraform** | Multi-cloud, mature ecosystem, declarative, state management | HCL learning curve, state management complexity |
| **AWS CDK** | Type-safe (TypeScript), AWS native, programmatic | AWS-only, transpiles to CloudFormation (slow) |
| **CloudFormation** | AWS native, no external dependencies | Verbose YAML, limited abstraction |
| **Pulumi** | Real programming languages, multi-cloud | Smaller ecosystem, state management |

#### Chosen Option
**Terraform**

#### Rationale
- **Multi-Cloud**: Not locked into AWS (future flexibility)
- **State Management**: Robust S3 + DynamoDB backend with locking
- **Modules**: Extensive module ecosystem (AWS provider has 1000+ resources)
- **Declarative**: Easy to understand desired state
- **Plan**: Preview changes before applying
- **Community**: Large community, extensive documentation
- **Tooling**: terraform-docs, tflint, checkov integration

---

### ADR-018: Serverless Deployment Tool

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Backend Team

#### Context
Need a deployment tool specifically for Lambda functions and API Gateway that supports local testing.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **AWS SAM** | Local testing, simplified syntax, AWS native | CloudFormation-based (slower deployments) |
| **Serverless Framework** | Rich plugin ecosystem, multi-cloud | Commercial features, additional abstraction |
| **Deploy via Terraform** | Single tool for everything | More verbose, no local API testing |

#### Chosen Option
**AWS SAM (Serverless Application Model)**

#### Rationale
- **Local Testing**: `sam local start-api` for local development
- **Simplified Syntax**: Less verbose than CloudFormation
- **API Gateway**: Native support for REST API definition
- **Lambda Layers**: Easy dependency management
- **SAM CLI**: Build, test, deploy in one tool
- **Integration**: Works alongside Terraform (SAM for functions, Terraform for infrastructure)
- **Outputs**: CloudFormation outputs readable by Terraform

**Split Strategy**: Terraform manages infrastructure (VPC, DynamoDB, Cognito), SAM manages serverless API (Lambda, API Gateway)

---

### ADR-019: Terraform State Backend

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: DevOps Team

#### Context
Need a remote state backend that prevents concurrent modifications and provides versioning.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **S3 + DynamoDB Locking** | Versioning, locking, encryption, no additional cost | Requires initial setup |
| **Terraform Cloud** | Free tier, remote execution, state versioning | Third-party dependency, limited free tier |
| **Local State** | Simplest, no setup | No collaboration, no locking, data loss risk |

#### Chosen Option
**S3 + DynamoDB Locking**

#### Rationale
- **Locking**: DynamoDB prevents concurrent `terraform apply` operations
- **Versioning**: S3 versioning enables state recovery
- **Encryption**: Server-side encryption for sensitive data
- **Cost**: S3 storage is pennies per month
- **Team Collaboration**: Multiple team members can share state
- **Disaster Recovery**: State versioning protects against corruption
- **AWS Native**: No third-party dependencies

---

## Frontend Technology Decisions

### ADR-020: Frontend Framework Selection

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Frontend Team

#### Context
Need a modern JavaScript framework for building an interactive single-page application.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **React 18.3** | Component-based, huge ecosystem, concurrent features | Less opinionated, requires additional libraries |
| **Vue 3** | Gentle learning curve, great DX, Composition API | Smaller ecosystem than React |
| **Svelte** | No virtual DOM, smaller bundle size | Smaller ecosystem, fewer job opportunities |
| **Vanilla JS** | No framework overhead | Significant development time, no component model |

#### Chosen Option
**React 18.3**

#### Rationale
- **Ecosystem**: Largest component library ecosystem (MUI, Radix UI)
- **TypeScript**: First-class TypeScript support
- **Concurrent Features**: Automatic batching, transitions for better UX
- **Team Familiarity**: Most widely known framework
- **Community**: Extensive documentation, tutorials, Stack Overflow support
- **Tooling**: Excellent DevTools, testing libraries
- **Long-Term**: Meta-backed, proven longevity

---

### ADR-021: Build Tool Selection

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Frontend Team

#### Context
Need a fast, modern build tool for development and production builds.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **Vite 7.2.7** | Extremely fast HMR, ESM-based, optimized builds | Relatively newer than webpack |
| **Webpack 5** | Mature, extensive plugin ecosystem | Slower dev server, complex configuration |
| **esbuild** | Fastest build times | Limited plugin ecosystem, alpha stage |
| **Parcel** | Zero config, fast | Less control, smaller ecosystem |

#### Chosen Option
**Vite 7.2.7**

#### Rationale
- **Speed**: Instant server start, sub-second HMR
- **ESM**: Native ES modules in development (no bundling)
- **Production**: Rollup-based optimized production builds
- **TypeScript**: Built-in TypeScript support, no config needed
- **React**: Official React plugin with Fast Refresh
- **DX**: Excellent developer experience, minimal configuration
- **Modern**: Designed for modern JavaScript development

---

### ADR-022: State Management Strategy

**Date**: 2025-12-28  
**Status**: Accepted  
**Decision Maker**: Frontend Team

#### Context
Need a state management strategy that handles server data, auth state, and UI state.

#### Options Considered

| Option | Pros | Cons |
|--------|------|------|
| **TanStack React Query** | Automatic caching, background refetching, optimistic updates | Learning curve for complex scenarios |
| **Redux Toolkit** | Predictable state, DevTools, middleware | Boilerplate, overkill for simple apps |
| **Zustand** | Minimal API, no context | Manual cache invalidation |
| **React Context Only** | Built-in, simple | No caching, no background refetching |

#### Chosen Option
**TanStack React Query + React Context**

#### Rationale
- **Server State**: React Query handles API data fetching, caching, synchronization
- **Auth State**: React Context for user session (accessed globally)
- **UI State**: Local `useState` for component-specific state
- **Automatic Caching**: 5-minute stale time reduces API calls
- **Optimistic Updates**: Instant UI feedback, rollback on error
- **Background Refetching**: Automatically refresh stale data
- **DevTools**: React Query DevTools for debugging
- **Bundle Size**: Smaller than Redux (13KB vs 40KB gzipped)

---

## Summary Table

| Decision Area | Chosen Technology | Key Rationale |
|---------------|-------------------|---------------|
| **Frontend Hosting** | Amazon S3 | Cost-effective, 11 9's durability |
| **CDN** | CloudFront | 400+ edge locations, built-in DDoS |
| **WAF** | AWS WAF v2 | OWASP Top 10 protection |
| **DNS** | Route53 | Alias records, health checks |
| **SSL/TLS** | ACM | Free, automatic renewal |
| **API Gateway** | REST API | Authorizer caching, full features |
| **Compute** | Lambda | Pay-per-invocation, auto-scaling |
| **Runtime** | Node.js 24.x | Fast cold starts, TypeScript |
| **Dead Letter Queue** | SQS | Failed invocation debugging |
| **Database** | DynamoDB | Serverless, low latency |
| **Billing** | On-Demand | Variable traffic, no planning |
| **Backup** | PITR | 5-min RPO, 35-day retention |
| **Authentication** | Cognito | Managed, free tier, MFA |
| **Auth Protocol** | SRP | Password never sent |
| **Tokens** | JWT | Stateless, cached validation |
| **IaC** | Terraform | Multi-cloud, mature |
| **Serverless IaC** | SAM | Local testing, simplified |
| **State Backend** | S3 + DynamoDB | Locking, versioning |
| **Frontend Framework** | React 18.3 | Largest ecosystem |
| **Build Tool** | Vite 7.2.7 | Fast HMR, ESM-based |
| **State Management** | React Query | Server state caching |

---

## Decision Process

### How Decisions Are Made

1. **Identify Need**: Technical requirement or problem statement
2. **Research Options**: Evaluate 3-5 alternatives with pros/cons
3. **Prototype** (if needed): Test feasibility with POC
4. **Team Discussion**: Gather input from affected teams
5. **Document Decision**: Record in this log with rationale
6. **Review**: Quarterly review of major decisions

### When to Revisit Decisions

- **Performance Issues**: System not meeting SLAs
- **Cost Concerns**: Technology becomes cost-prohibitive
- **Security Vulnerabilities**: Better alternatives emerge
- **Deprecated Technology**: AWS announces deprecation
- **Scale Changes**: Traffic patterns shift significantly

---

## Document Metadata

| Attribute | Value |
|-----------|-------|
| **Version** | 1.0 |
| **Created** | 2025-12-28 |
| **Last Updated** | 2025-12-28 |
| **Next Review** | 2026-01-28 (Monthly) |
| **Owner** | Architecture Team |
| **Status** | Active |

### Related Documents
- [Architecture Document](architecture.md)
- [Disaster Recovery Plan](disaster-recovery.md)
- [Incident Response Plan](incident-response.md)
