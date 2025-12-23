/**
 * NOTES REPOSITORY - DATABASE ACCESS LAYER
 *
 * PURPOSE:
 * This repository handles all DynamoDB operations for notes.
 * It's the ONLY place in our code that knows about DynamoDB's structure.
 *
 * REPOSITORY PATTERN (BEGINNER CONCEPT):
 * Instead of writing DynamoDB code everywhere, we centralize it here.
 * Benefits: Easy to test, easy to change database later, cleaner service layer.
 *
 * SINGLE-TABLE DESIGN (ADVANCED DYNAMODB PATTERN):
 * We use ONE DynamoDB table for all data types. Items are organized using:
 * - pk (partition key): Groups related items together (e.g., all notes for a user)
 * - sk (sort key): Identifies specific items within a partition (e.g., a specific note)
 *
 * Example keys:
 *   pk: "USER#user123"  sk: "NOTE#note456"  ← This is a note
 *   pk: "USER#user123"  sk: "NOTE#note789"  ← Another note for same user
 *
 * Why? DynamoDB is super fast when querying by partition key + sort key prefix.
 */

import { ddb, PutCommand, GetCommand, QueryCommand, UpdateCommand, DeleteCommand } from './DynamoDBClient';
import { Note, CreateNoteInput, UpdateNoteInput } from '../types/note';
import { NotFoundError } from '../types/errors';

/**
 * ENVIRONMENT VARIABLE: TABLE_NAME
 *
 * SECURITY NOTE:
 * - Table name comes from an environment variable (set by Terraform/CloudFormation)
 * - Lambda's IAM role grants access to ONLY this specific table
 * - The '!' tells TypeScript "trust me, this will be defined at runtime"
 *
 * WHY NOT HARDCODE?
 * - Different environments (dev/staging/prod) use different tables
 * - Easier to manage through infrastructure-as-code
 */
const TABLE = process.env.TABLE_NAME!;

/**
 * NOTES REPOSITORY CLASS
 * All methods are async because DynamoDB operations are network calls.
 */
export class NotesRepository {
  /**
   * CREATE: Save a new note to DynamoDB
   *
   * DATA FLOW:
   * Service layer → Repository (here) → DynamoDB Client → AWS DynamoDB
   *
   * RESPONSIBILITY SEPARATION (BEGINNER CONCEPT):
   * - Service layer: Creates the complete Note object (generates ID, timestamps)
   * - Repository layer: Just saves it to DynamoDB (doesn't create/modify data)
   * This separation makes code easier to test and understand.
   *
   * SINGLE-TABLE DESIGN:
   * We add 'pk' and 'sk' to organize the note in our table:
   * - pk: "USER#userId" (partition key - groups all notes for this user)
   * - sk: "NOTE#noteId" (sort key - identifies this specific note)
   * - ...note: Spreads all note properties (id, title, content, tags, timestamps)
   *
   * WHY PutCommand?
   * PutCommand creates a new item OR overwrites if pk+sk already exist.
   * (In our case, noteId is unique, so we won't accidentally overwrite)
   *
   * SECURITY:
   * - userId comes from authenticated JWT token (verified by API Gateway)
   * - Each user can only access their own partition (USER#theirId)
   * - Lambda's IAM role only allows PutItem on this table
   */
  async create(userId: string, note: Note): Promise<Note> {
    // Construct the DynamoDB item with partition/sort keys
    const item = {
      pk: `USER#${userId}`,      // Partition key: groups all user's notes
      sk: `NOTE#${note.id}`,     // Sort key: identifies this specific note
      ...note,                    // Spread all note properties (id, title, content, etc.)
    };

    // Send the PutCommand to DynamoDB
    await ddb.send(
      new PutCommand({
        TableName: TABLE,         // Which table to write to
        Item: item,               // The complete item to save
      })
    );

    // Return the note (we already have it, no need to fetch from DB)
    return note;
  }

  /**
   * LIST: Fetch all notes for a user (with pagination)
   *
   * QUERY vs SCAN:
   * - Query: Fast! Uses the partition key to find only relevant items
   * - Scan: Slow! Reads the entire table (we never use this)
   *
   * HOW PAGINATION WORKS:
   * 1. Client requests first page (no nextToken)
   * 2. We fetch up to 'limit' items from DynamoDB
   * 3. If more items exist, DynamoDB returns 'LastEvaluatedKey'
   * 4. We encode it as base64 and return as 'nextToken'
   * 5. Client sends nextToken with next request to get more items
   *
   * WHY PAGINATION?
   * - DynamoDB limits response size (1MB max)
   * - Better performance for clients (don't load 10,000 notes at once)
   * - Users get faster initial response
   *
   * SECURITY:
   * - We query ONLY items where pk = "USER#userId"
   * - User can never see another user's notes (isolated by partition key)
   */
  async list(userId: string, limit: number = 20, nextToken?: string): Promise<any> {
    // Build the DynamoDB query parameters
    const params: any = {
      TableName: TABLE,
      // KeyConditionExpression: "WHERE clause" for DynamoDB queries
      // We're saying: "Find all items where pk equals USER#userId"
      KeyConditionExpression: 'pk = :pk',
      // Expression values: Replace :pk placeholder with actual value
      ExpressionAttributeValues: {
        ':pk': `USER#${userId}`,
      },
      // Limit: Maximum number of items to return (for pagination)
      Limit: limit,
    };

    // PAGINATION: If client sent a nextToken, start from that position
    if (nextToken) {
      // Decode the base64 token back to DynamoDB's LastEvaluatedKey format
      params.ExclusiveStartKey = JSON.parse(Buffer.from(nextToken, 'base64').toString());
    }

    // Execute the query
    const result = await ddb.send(new QueryCommand(params));

    // Return notes + nextToken for pagination
    return {
      items: result.Items || [],  // The notes we found (or empty array)
      // If there are more items, encode LastEvaluatedKey as base64 for next request
      nextToken: result.LastEvaluatedKey
        ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
        : null,  // No more items? Return null
    };
  }

  /**
   * GET: Fetch a single note by ID
   *
   * HOW IT WORKS:
   * GetCommand is the fastest DynamoDB operation - it fetches ONE item by exact key.
   * We need BOTH pk and sk to uniquely identify the note.
   *
   * SECURITY:
   * - We require BOTH userId AND noteId
   * - Even if someone knows a noteId, they can't fetch it without the correct userId
   * - This prevents users from accessing each other's notes
   *
   * ERROR HANDLING:
   * - If the item doesn't exist, DynamoDB returns an empty result (not an error)
   * - We check for this and throw NotFoundError (which becomes HTTP 404)
   */
  async get(userId: string, noteId: string): Promise<Note> {
    // Fetch the item by its composite key (pk + sk)
    const result = await ddb.send(
      new GetCommand({
        TableName: TABLE,
        Key: {
          pk: `USER#${userId}`,   // Must match the partition key
          sk: `NOTE#${noteId}`,   // Must match the sort key
        },
      })
    );

    // DynamoDB returns undefined Item if not found (not an error!)
    if (!result.Item) {
      throw new NotFoundError(`Note ${noteId} not found`);
    }

    // TypeScript: we know this is a Note, cast it
    return result.Item as Note;
  }

  /**
   * UPDATE: Modify specific fields of a note
   *
   * PARTIAL UPDATES (KEY CONCEPT):
   * Unlike PutCommand (overwrites entire item), UpdateCommand changes only specified fields.
   * Example: Update just the title, leave content/tags unchanged.
   *
   * WHY DYNAMIC EXPRESSIONS?
   * We don't know which fields the user wants to update, so we build the expression dynamically:
   * - User sends { title: "New Title" } → Expression: "SET title = :title"
   * - User sends { title: "...", tags: [...] } → Expression: "SET title = :title, tags = :tags"
   *
   * EXPRESSION ATTRIBUTE NAMES:
   * - DynamoDB has reserved words (like 'content', 'title')
   * - We use #placeholder syntax to safely reference attribute names
   * - Example: '#title' maps to 'title'
   *
   * CONDITIONAL EXPRESSION:
   * - 'attribute_exists(pk)' ensures the note exists before updating
   * - If note doesn't exist, DynamoDB throws ConditionalCheckFailedException
   * - This prevents creating notes via update (should use create instead)
   *
   * RETURN VALUES:
   * - 'ALL_NEW' returns the item after the update (with all changes applied)
   * - Alternative: 'UPDATED_NEW' (only changed attributes), 'NONE' (don't return anything)
   */
  async update(userId: string, noteId: string, input: UpdateNoteInput): Promise<Note> {
    // Build dynamic update expression based on which fields are provided
    const updateExpressions: string[] = [];
    const expressionAttributeNames: any = {};
    const expressionAttributeValues: any = {};

    // Check each field and add to expression if provided
    if (input.title !== undefined) {
      updateExpressions.push('#title = :title');
      expressionAttributeNames['#title'] = 'title';      // Map placeholder to actual field
      expressionAttributeValues[':title'] = input.title; // Map placeholder to value
    }

    if (input.content !== undefined) {
      updateExpressions.push('#content = :content');
      expressionAttributeNames['#content'] = 'content';
      expressionAttributeValues[':content'] = input.content;
    }

    if (input.tags !== undefined) {
      updateExpressions.push('#tags = :tags');
      expressionAttributeNames['#tags'] = 'tags';
      expressionAttributeValues[':tags'] = input.tags;
    }

    // Always update the 'updatedAt' timestamp (audit trail)
    updateExpressions.push('#updatedAt = :updatedAt');
    expressionAttributeNames['#updatedAt'] = 'updatedAt';
    expressionAttributeValues[':updatedAt'] = new Date().toISOString();

    try {
      const result = await ddb.send(
        new UpdateCommand({
          TableName: TABLE,
          Key: {
            pk: `USER#${userId}`,
            sk: `NOTE#${noteId}`,
          },
          // Build the SET clause: "SET title = :title, content = :content, updatedAt = :updatedAt"
          UpdateExpression: `SET ${updateExpressions.join(', ')}`,
          // Map all #placeholders to actual attribute names
          ExpressionAttributeNames: expressionAttributeNames,
          // Map all :placeholders to actual values
          ExpressionAttributeValues: expressionAttributeValues,
          // Only update if the note exists (prevents accidental creation)
          ConditionExpression: 'attribute_exists(pk)',
          // Return the updated item with all fields
          ReturnValues: 'ALL_NEW',
        })
      );

      // Should always have Attributes due to ReturnValues: 'ALL_NEW'
      if (!result.Attributes) {
        throw new NotFoundError(`Note ${noteId} not found`);
      }

      return result.Attributes as Note;
    } catch (error: any) {
      // DYNAMO ERROR HANDLING:
      // ConditionalCheckFailedException means the note doesn't exist
      if (error.name === 'ConditionalCheckFailedException') {
        throw new NotFoundError(`Note ${noteId} not found`);
      }
      // Re-throw any other errors (network issues, permissions, etc.)
      throw error;
    }
  }

  /**
   * DELETE: Remove a note from DynamoDB
   *
   * IDEMPOTENT OPERATION:
   * DeleteCommand succeeds even if the item doesn't exist (no error thrown).
   * This is "idempotent" - calling it multiple times has the same effect as calling once.
   *
   * WHY NO ERROR IF NOT FOUND?
   * - The end result is the same: note doesn't exist
   * - Simplifies client code (no need to check if note exists first)
   * - This is a common REST API pattern for DELETE
   *
   * SECURITY:
   * - User must provide correct userId + noteId combo
   * - Can't delete other users' notes (partition key mismatch)
   * - Lambda's IAM role only allows DeleteItem on this table
   *
   * NO RETURN VALUE:
   * - We return void (Promise<void>) because there's nothing to return
   * - Handler will return HTTP 204 No Content (successful deletion)
   */
  async delete(userId: string, noteId: string): Promise<void> {
    // Delete the item by its composite key
    await ddb.send(
      new DeleteCommand({
        TableName: TABLE,
        Key: {
          pk: `USER#${userId}`,   // Partition key
          sk: `NOTE#${noteId}`,   // Sort key
        },
        // Note: We don't use ConditionExpression here (idempotent delete)
        // If you wanted to error on missing note, add: ConditionExpression: 'attribute_exists(pk)'
      })
    );
    
    // No return - deletion successful (or item didn't exist, which is fine)
  }
}
