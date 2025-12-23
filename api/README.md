# Notes API (Serverless on AWS)

This folder contains a stateless, serverless REST API for personal notes built with TypeScript and AWS Lambda behind API Gateway, persisting data in DynamoDB.

The design follows the API Lambda Mentor Rules: preserve serverless architecture, prioritize readability, document the request lifecycle, enforce consistent error handling, and keep security top-of-mind.

## Architecture Overview

- API Gateway → Lambda → DynamoDB (no servers, no stateful processes)
- Handlers route requests and orchestrate services
- Services encapsulate business logic and call repositories
- Repositories wrap the AWS SDK (DynamoDB) access
- Types define input/output contracts
- Utilities provide logging, ID generation, and response formatting

```
api/
  src/
    handlers/           # Lambda entrypoints (API Gateway triggers these)
      notes/
        readHandler.ts  # GET /notes, GET /notes/{id}
        writeHandler.ts # POST /notes, PUT /notes/{id}, DELETE /notes/{id}
    services/
      NotesService.ts   # Business logic
    repositories/
      DynamoDBClient.ts # DynamoDB client and helpers
      NotesRepository.ts# Data access
    types/
      note.ts           # DTOs & interfaces
      errors.ts         # Typed errors with HTTP status codes
    utils/
      response.ts       # CORS + JSON response helpers
      logger.ts         # Minimal logger wrapper
      id.ts             # ULID/ID helpers
```

## Request Lifecycle (Beginner Friendly)

1. Client calls an endpoint (e.g., GET /notes).
2. API Gateway validates JWT (Cognito or custom authorizer) and forwards claims in `requestContext`.
3. Lambda handler receives the event, extracts the authenticated `userId` from claims.
4. Handler validates inputs and routes to a service method.
5. Service uses a repository to read/write DynamoDB (scoped to this `userId`).
6. Handler formats a safe JSON response with CORS headers.
7. API Gateway returns the response to the client.

Statelessness: Each invocation stands alone. No in-memory state is carried across requests (warm containers may be reused but logic must not depend on that!).

Cold starts: The first invocation after deployment or inactivity may be slower. Keep dependencies lean and reuse top-level singletons where safe.

Timeout & memory: Allocate only what you need. More memory can reduce latency but increases cost.

## Error Handling

Use the typed errors in `src/types/errors.ts` to keep responses consistent and safe:

- `ValidationError` → 400 Bad Request
- `NotFoundError` → 404 Not Found
- `UnauthorizedError` → 401 Unauthorized (or 403 when appropriate)

Handlers catch these and map to HTTP responses using `responseFormatter` in `src/utils/response.ts`, avoiding stack traces or sensitive info in client-visible messages.

## Prerequisites

- Node.js 18+
- AWS SAM CLI (for local API Gateway/Lambda emulation and deployments)
- AWS credentials configured for your profiles referenced in package scripts

## Installing AWS SAM CLI

AWS SAM CLI is required to build, test locally, and deploy your serverless application.

### Windows (using Chocolatey or MSI)

**Option 1: Using Chocolatey (Recommended)**
```bash
choco install aws-sam-cli
```

**Option 2: Using MSI Installer**
1. Download the latest MSI installer from: https://github.com/aws/aws-sam-cli/releases/latest
2. Run the `.msi` file and follow the installation wizard
3. Restart your terminal

### macOS (using Homebrew)

```bash
brew tap aws/tap
brew install aws-sam-cli
```

### Linux (using pip)

```bash
pip install aws-sam-cli
```

Or use the AWS-provided installer:
```bash
wget https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip
unzip aws-sam-cli-linux-x86_64.zip -d sam-installation
sudo ./sam-installation/install
```

### Verify Installation

After installation, verify SAM is installed correctly:
```bash
sam --version
```

You should see output like: `SAM CLI, version 1.x.x`

### Configure AWS Credentials

SAM uses AWS credentials to deploy resources. Configure them using the AWS CLI:

```bash
# Install AWS CLI first if you haven't
# Windows: choco install awscli
# macOS: brew install awscli
# Linux: pip install awscli

# Configure your credentials
aws configure
```

You'll be prompted for:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., `ap-southeast-1`)
- Default output format (e.g., `json`)

**Using multiple profiles** (recommended for dev/staging/prod):
```bash
aws configure --profile dev
aws configure --profile prod
```

Then reference the profile in SAM commands:
```bash
sam deploy --profile dev
```

## Install

```bash
npm install
```

## Scripts

Defined in `package.json`:

- `npm run build`: Compile TypeScript to JavaScript via `tsc`.
- `npm run test`: Run Jest tests.
- `npm run dev`: Runs `ts-node src/index.ts` (optional; requires an `src/index.ts` entrypoint if you add one).
- `npm run sam:build`: Build TypeScript then run `sam build`.
- `npm run sam:local`: Build then run a local API with `sam local start-api --env-vars env.json --port 3001`.
- `npm run sam:deployfirst`: Build and deploy with guided parameters (first-time, uses `--guided`).
- `npm run sam:deploy`: Build and deploy (non-guided).
- `npm run sam:delete`: Delete the deployed stack.
- `npm run clean`: Remove build artifacts.

Note: `dev` is optional and assumes an application entrypoint at `src/index.ts` which is not included by default. Prefer SAM for running the API locally.

## Local Development with SAM

1. Build:
   ```bash
   npm run sam:build
   ```
2. Provide environment variables via `env.json` (example below).
3. Run the local API:
   ```bash
   npm run sam:local
   ```
4. Invoke endpoints with curl or your REST client.

Example `env.json`:
```json
{
  "Parameters": {
    "DynamoDBTableName": "p1-serverless-web-app-dev-notes",
    "UserPoolId": "ap-southeast-1_XXXXXXXXX"
  }
}
```

Example requests:
```bash
# List notes (GET)
curl -H "Authorization: Bearer <JWT>" http://127.0.0.1:3001/notes

# Get a note (GET)
curl -H "Authorization: Bearer <JWT>" http://127.0.0.1:3001/notes/<id>

# Create a note (POST)
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{"title":"Hello","content":"World","tags":["t1"]}' \
  http://127.0.0.1:3001/notes

# Update a note (PUT)
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <JWT>" \
  -d '{"title":"Updated"}' \
  http://127.0.0.1:3001/notes/<id>

# Delete a note (DELETE)
curl -X DELETE \
  -H "Authorization: Bearer <JWT>" \
  http://127.0.0.1:3001/notes/<id>
```

## Testing

```bash
npm test
```

Keep unit tests focused on small pieces (service methods, repositories). Avoid integration tests that require live AWS unless explicitly needed; prefer SAM local for end-to-end checks.

## Security Notes

- Authentication: API Gateway authorizer validates JWT and forwards claims.
- Authorization: Always scope reads/writes to the authenticated `userId`.
- IAM least privilege: Lambda roles should access only the required DynamoDB table/index operations.
- Input validation: Always validate `event.body` and query/route params before use.
- No secret leakage: Error messages must be minimal; never include stack traces in client responses.

## Common Pitfalls (and fixes)

- CORS errors: Ensure the response includes the CORS headers from `utils/response.ts`.
- Empty updates: Reject updates where no fields are provided (see `writeHandler`).
- Pagination: Respect `limit` bounds and use `nextToken` for subsequent pages.
- Cold start latency: Keep dependencies modest; reuse initialized clients at module scope.

## Deployment

First-time guided deploy (prompts for parameters and saves config):
```bash
npm run sam:deployfirst
```

Subsequent deploys:
```bash
npm run sam:deploy
```

Delete the stack:
```bash
npm run sam:delete
```

Ensure you pass or configure the correct AWS profile(s) referenced in the scripts.

## Where to Start Reading the Code

- Handlers: `src/handlers/notes/readHandler.ts`, `src/handlers/notes/writeHandler.ts`
- Business logic: `src/services/NotesService.ts`
- Data access: `src/repositories/NotesRepository.ts`
- Types & errors: `src/types/note.ts`, `src/types/errors.ts`
- Responses & logging: `src/utils/response.ts`, `src/utils/logger.ts`

These files are heavily commented to teach the request lifecycle and serverless best practices.
