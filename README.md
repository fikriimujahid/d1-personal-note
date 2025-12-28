# d1-personal-note

<div align="center">

![AWS](https://img.shields.io/badge/AWS-Serverless-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)
![React](https://img.shields.io/badge/React-18.3-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-1.0+-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![License](https://img.shields.io/badge/License-Private-red?style=for-the-badge)

**A modern, serverless personal note-taking application built on AWS**

[Features](#-features) · [Architecture](#-architecture) · [Quick Start](#-quick-start) · [Documentation](#-documentation)

</div>

---

## Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Quick Start](#-quick-start)
- [Development](#-development)
- [Deployment](#-deployment)
- [Security](#-security)
- [Documentation](#-documentation)
- [Contributing](#-contributing)

---

## Overview

**d1-personal-note** is a cloud-native, serverless personal note-taking application designed with security, scalability, and cost-efficiency in mind. The application follows modern architectural patterns and DevSecOps best practices.

### Key Characteristics

- **Serverless-First Architecture**: No servers to manage, pay-per-use pricing
- **Single-Page Application (SPA)**: Modern React-based frontend with responsive design
- **Secure by Design**: JWT authentication, WAF protection, encryption at rest
- **Observable**: CloudWatch metrics, X-Ray tracing, automated alarms
- **Cost-Optimized**: On-demand pricing, automatic scaling to zero
- **DevSecOps Ready**: Integrated security scanning in CI/CD pipeline

---

## Features

### Core Functionality
- Create, read, update, and delete personal notes
- Tag-based organization and filtering
- Search notes by title and content
- Cursor-based pagination for large collections

### Authentication & Security
- User registration with email verification
- Secure sign-in with AWS Cognito
- Password reset functionality
- JWT-based API authentication
- WAF protection against common attacks

### User Experience
- Responsive design (desktop, tablet, mobile)
- Optimistic UI updates
- Loading states and skeleton screens
- Error handling with user-friendly messages

---

## Architecture

The application consists of three main tiers:

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER LAYER                                │
│    Web Browser / Mobile Browser                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     EDGE LAYER                                   │
│    Route53 (DNS) → CloudFront (CDN) → WAF (Security)            │
└───────────────────────────┬─────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌─────────────────────┐         ┌─────────────────────────────────┐
│   FRONTEND TIER     │         │         API TIER                │
│                     │         │                                 │
│   S3 Bucket         │         │  API Gateway → Lambda (Read)    │
│   (Static Assets)   │         │             → Lambda (Write)    │
│                     │         │                                 │
└─────────────────────┘         └─────────────┬───────────────────┘
                                              │
                            ┌─────────────────┴─────────────────┐
                            ▼                                   ▼
                ┌─────────────────────┐         ┌───────────────────────┐
                │    DATA TIER        │         │   SECURITY TIER       │
                │                     │         │                       │
                │   DynamoDB          │         │   Cognito User Pool   │
                │   (Notes Storage)   │         │   (Authentication)    │
                │                     │         │                       │
                └─────────────────────┘         └───────────────────────┘
```

### Request Flow

1. **Static Content**: User → Route53 → CloudFront → S3
2. **API Requests**: User → Route53 → CloudFront → WAF → API Gateway → Cognito (auth) → Lambda → DynamoDB

---

## Tech Stack

### Frontend
| Technology | Version | Purpose |
|------------|---------|---------|
| React | 18.3.1 | Component-based UI library |
| TypeScript | ~5.9 | Type-safe JavaScript |
| Vite | 7.2.7 | Fast ESM-based bundler |
| Tailwind CSS | 4.1.18 | Utility-first CSS framework |
| Material-UI | 7.3.6 | Pre-built React components |
| TanStack React Query | 5.90.12 | Server state management |
| AWS Amplify | 6.15.9 | Cognito SDK integration |
| Axios | 1.13.2 | HTTP client |
| Vitest | 4.0.16 | Unit testing |

### Backend (API)
| Technology | Version | Purpose |
|------------|---------|---------|
| Node.js | 24.x | Lambda runtime |
| TypeScript | 5.9.3 | Type-safe JavaScript |
| AWS SDK v3 | 3.954.0 | DynamoDB operations |
| ULID | 3.0.2 | Unique ID generation |
| Jest | 30.2.0 | Unit testing |
| AWS SAM | Latest | Serverless deployment |

### Infrastructure
| Technology | Version | Purpose |
|------------|---------|---------|
| Terraform | >= 1.0 | Infrastructure provisioning |
| AWS SAM | Latest | Lambda/API Gateway deployment |
| GitHub Actions | - | CI/CD pipeline |

### Security Scanning
| Tool | Purpose |
|------|---------|
| Checkov | Infrastructure security scanning |
| Semgrep | Static code analysis (SAST) |
| Gitleaks | Secrets detection |
| OWASP Dependency Check | Vulnerability scanning (SCA) |
| OWASP ZAP | Dynamic security testing (DAST) |
| detect-secrets | Pre-commit secrets detection |

---

## Project Structure

```
d1-personal-note/
├── api/                      # Serverless API (Lambda functions)
│   ├── src/
│   │   ├── handlers/            # Lambda entry points
│   │   ├── services/            # Business logic
│   │   ├── repositories/        # Data access layer
│   │   ├── types/               # TypeScript interfaces
│   │   └── utils/               # Helper functions
│   ├── tests/                   # Unit tests
│   ├── template.yaml            # AWS SAM template
│   └── package.json
│
├── frontend/                 # React SPA
│   ├── src/
│   │   ├── app/                 # Main application
│   │   │   ├── components/      # Reusable components
│   │   │   └── pages/           # Page components
│   │   ├── contexts/            # React contexts
│   │   ├── hooks/               # Custom hooks
│   │   ├── services/            # API client
│   │   ├── types/               # TypeScript types
│   │   └── styles/              # Global styles
│   ├── public/                  # Static assets
│   └── package.json
│
├── infra/                    # Infrastructure as Code
│   └── terraform/
│       ├── modules/
│       │   ├── auth/            # Cognito configuration
│       │   ├── budget/          # Cost management
│       │   ├── database/        # DynamoDB tables
│       │   ├── hosting/         # S3 + CloudFront
│       │   ├── iam/             # IAM policies
│       │   ├── iam-roles/       # IAM roles
│       │   └── monitoring/      # CloudWatch alarms
│       └── environments/        # Environment configs
│
├── scripts/                  # Operational scripts
│   ├── dr-backup.ps1            # Disaster recovery backup
│   └── incident-response.ps1    # Incident response automation
│
├── security/                 # Security scanning
│   ├── scripts/                 # Scan scripts
│   │   └── scan-all.ps1         # Comprehensive security scan
│   └── result/                  # Scan results (gitignored)
│
├── docs/                     # Documentation
│   ├── architecture.md          # System architecture
│   ├── decision-log.md          # Architecture decisions
│   ├── disaster-recovery.md     # DR strategy
│   └── incident-response.md     # IR procedures
│
└── .github/                  # GitHub configuration
    └── workflows/
        ├── api-ci.yml           # API continuous integration
        ├── api-deploy.yml       # API deployment
        ├── frontend-ci.yml      # Frontend CI
        ├── frontend-deploy.yml  # Frontend deployment
        ├── infra-plan-apply.yml # Terraform workflow
        └── security.yml         # Security scanning
```

---

## Quick Start

### Prerequisites

- **Node.js** v18+ ([Download](https://nodejs.org/))
- **AWS CLI** v2+ ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- **AWS SAM CLI** ([Install Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html))
- **Terraform** v1.0+ ([Download](https://www.terraform.io/downloads))
- **Git** ([Download](https://git-scm.com/))

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/d1-personal-note.git
cd d1-personal-note
```

### 2. Configure AWS Credentials

```bash
# Configure your AWS profile
aws configure --profile dev

# Set the profile (PowerShell)
$env:AWS_PROFILE = "dev"

# Set the profile (Bash)
export AWS_PROFILE=dev
```

### 3. Deploy Infrastructure (Terraform)

```bash
cd infra/terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="environments/dev.tfvars"

# Apply the configuration
terraform apply -var-file="environments/dev.tfvars"
```

### 4. Deploy API (AWS SAM)

```bash
cd api

# Install dependencies
npm install

# Build and deploy
npm run sam:build
npm run sam:deploy
```

### 5. Deploy Frontend

```bash
cd frontend

# Install dependencies
npm install

# Create environment file
cp .env.example .env
# Edit .env with your API URL and Cognito settings

# Build for production
npm run build

# Deploy to S3 (use AWS CLI or Terraform output)
aws s3 sync dist/ s3://your-frontend-bucket --delete
```

### 6. Access the Application

Navigate to your CloudFront distribution URL or custom domain.

---

## Development

### Frontend Development

```bash
cd frontend

# Install dependencies
npm install

# Start development server (http://localhost:5173)
npm run dev

# Run tests
npm run test

# Run linting
npm run lint
```

### API Development

```bash
cd api

# Install dependencies
npm install

# Build TypeScript
npm run build

# Run tests
npm test

# Start local API (requires SAM CLI)
npm run sam:local
```

### Running Security Scans Locally

```powershell
# Run comprehensive security scan
.\security\scripts\scan-all.ps1

# Run specific scans
.\security\scripts\scan-all.ps1 -Mode sast
.\security\scripts\scan-all.ps1 -Mode sca
.\security\scripts\scan-all.ps1 -Mode secrets
```

---

## Deployment

### CI/CD Pipeline

The project uses GitHub Actions for continuous integration and deployment:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `api-ci.yml` | Pull Request | Run API tests and linting |
| `api-deploy.yml` | Push to main | Deploy API to AWS |
| `frontend-ci.yml` | Pull Request | Run frontend tests |
| `frontend-deploy.yml` | Push to main | Build and deploy frontend |
| `infra-plan-apply.yml` | Push to main | Apply Terraform changes |
| `security.yml` | Scheduled/Manual | Run security scans |

### Manual Deployment

See the [API README](./api/README.md) and [Frontend README](./frontend/README.md) for detailed deployment instructions.

---

## Security

### Security Features

- **Authentication**: AWS Cognito with SRP protocol
- **Authorization**: JWT token validation at API Gateway
- **Transport Security**: TLS 1.2+, HTTPS enforced
- **Data Encryption**: DynamoDB encryption at rest, S3 SSE
- **WAF Protection**: OWASP Core Rule Set, rate limiting
- **Secrets Management**: No hardcoded secrets, environment variables

### Security Scanning

The project implements comprehensive security scanning:

| Type | Tool | Frequency |
|------|------|-----------|
| Secrets | gitleaks, detect-secrets | Continuous |
| SAST | Semgrep | On PR/Push |
| SCA | OWASP Dependency Check | Monthly |
| IaC | Checkov | On PR/Push |
| DAST | OWASP ZAP | Quarterly |

For more details, see [Security README](./security/README.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](./docs/architecture.md) | Complete system architecture |
| [Decision Log](./docs/decision-log.md) | Architecture decision records |
| [Disaster Recovery](./docs/disaster-recovery.md) | DR strategy and procedures |
| [Incident Response](./docs/incident-response.md) | IR runbook and procedures |
| [API Documentation](./api/README.md) | API development guide |
| [Frontend Documentation](./frontend/README.md) | Frontend development guide |
| [Security](./security/README.md) | Security testing strategy |
| [Scripts](./scripts/README.md) | Operational scripts guide |

---

## Contributing

### Development Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Run tests and linting
4. Submit a pull request
5. Wait for CI checks and code review

### Code Style

- **TypeScript**: Strict mode enabled
- **ESLint**: Configured for React and Node.js
- **Prettier**: Code formatting (if configured)

### Commit Messages

Follow conventional commits format:

```
feat: add note search functionality
fix: resolve pagination issue
docs: update API documentation
chore: upgrade dependencies
```

---

## Cost Estimation

Monthly cost for low-traffic workload (~$15-56/month):

| Service | Estimated Cost |
|---------|----------------|
| Lambda | $0-5 |
| API Gateway | $3-10 |
| DynamoDB (On-Demand) | $1-5 |
| S3 + CloudFront | $5-15 |
| Cognito | $0-5 |
| Route53 | $0.50-1 |
| CloudWatch | $0-5 |
| WAF | $5-10 |

---

## License

This project is private and proprietary.

---

## Support

For questions or issues:

1. Check the documentation in the `docs/` folder
2. Review component-specific READMEs
3. Contact the DevOps team
4. Create an issue in the repository

---

<div align="center">

**Built with ❤️ using AWS Serverless**

[⬆ Back to top](#d1-personal-note)

</div>
