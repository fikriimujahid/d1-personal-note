/**
 * DynamoDB Client Configuration
 *
 * PURPOSE:
 * This file sets up the AWS SDK client that our Lambda handlers use to talk to DynamoDB.
 * It's a "singleton" pattern - we create the client ONCE and reuse it across requests.
 * This is important for Lambda performance because initialization happens outside the handler.
 *
 * HOW IT WORKS:
 * 1. Lambda receives a request → triggers our handler code
 * 2. Handler calls Service → Service calls Repository → Repository imports this client (already initialized - fast!)
 * 3. Repository uses 'ddb' to put/get/update data in DynamoDB
 * 4. Lambda returns the response back to API Gateway
 *
 * SECURITY NOTE:
 * The Lambda function's IAM role (not this file) controls what DynamoDB operations
 * are allowed. This client assumes the role is properly configured with least-privilege
 * permissions (only PutItem, GetItem, Query, UpdateItem, DeleteItem on the correct table).
 */

// Low-level client: Knows how to talk to AWS DynamoDB service
// We import this but don't use it directly - it's wrapped by DocumentClient below
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';

// Document Client: Makes DynamoDB easier to work with JavaScript objects
// Instead of dealing with AWS's type system (like { S: 'value' }), we use plain JS objects
// Commands: Pre-built operations for common DynamoDB actions
import {
  DynamoDBDocumentClient,
  PutCommand,      // Create or overwrite an item
  GetCommand,      // Fetch a single item
  QueryCommand,    // Find items that match conditions
  UpdateCommand,   // Change specific fields in an item
  DeleteCommand,   // Remove an item
} from '@aws-sdk/lib-dynamodb';

/**
 * Initialize the DynamoDB client
 * Empty {} means: use AWS credentials from the Lambda's IAM role
 * (no hardcoded keys - that would be a security risk!)
 */
const client = new DynamoDBClient({});

/**
 * Wrap the client with DocumentClient for easier JavaScript interaction
 *
 * WHAT'S MARSHALLING?
 * AWS stores data in a special format. Marshalling converts:
 *   JavaScript: { name: 'Alice', age: 30, tags: undefined }
 *   AWS format: { name: { S: 'Alice' }, age: { N: '30' }, tags: <missing> }
 *
 * The Document Client handles this conversion automatically, and:
 * removeUndefinedValues: true → Don't send 'undefined' values to DynamoDB
 *   (This prevents wasting storage on empty fields)
 */
export const ddb = DynamoDBDocumentClient.from(client, {
  marshallOptions: {
    removeUndefinedValues: true,
  },
});

/**
 * Export all DynamoDB command types
 * Handlers import and use these like: new PutCommand({ ... })
 * This re-export keeps the import statements in handlers clean and focused
 */
export {
  PutCommand,
  GetCommand,
  QueryCommand,
  UpdateCommand,
  DeleteCommand,
};