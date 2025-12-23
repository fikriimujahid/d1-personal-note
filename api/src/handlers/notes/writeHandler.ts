/**
 * WRITE HANDLER FOR NOTES API
 *
 * REQUEST LIFECYCLE (BEGINNER VIEW):
 * 1. API Gateway receives an HTTP request (POST, PUT, DELETE on /notes)
 * 2. API Gateway validates the JWT (Cognito authorizer) and forwards claims to Lambda
 * 3. Lambda receives the event, extracts the authenticated userId from claims
 * 4. We route to the correct action: create, update, or delete a note
 * 5. The NotesService talks to DynamoDB using the user's ID to keep data isolated
 * 6. We format a safe HTTP response and return it to API Gateway
 * 7. API Gateway sends the response back to the client
 *
 * SERVERLESS + STATELESS:
 * - This Lambda holds no user state between requests; every invocation starts fresh.
 * - The NotesService instance is created once per warm container to reduce cold-start cost.
 *
 * PERFORMANCE NOTE (COLD STARTS):
 * - First invoke (cold start) pays the runtime + dependency load cost.
 * - Warm invocations reuse this file's top-level objects (like `service`).
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { NotesService } from '../../services/NotesService';
import { responseFormatter } from '../../utils/response';
import { logger } from '../../utils/logger';
import { NotFoundError, ValidationError } from '../../types/errors';
import { CreateNoteInput, UpdateNoteInput } from '../../types/note';

// Single shared service instance per warm Lambda container (safe: stateless + no globals mutated)
const service = new NotesService();

// AUTH EXTRACTION: Trusts API Gateway's Cognito/JWT authorizer to supply the subject claim (user id)
function extractUserId(event: APIGatewayProxyEvent): string | null {
  return event.requestContext.authorizer?.claims?.sub || null;
}

// AUTH VALIDATION: Ensures every write is tied to an authenticated user
function validateAuthentication(userId: string | null): APIGatewayProxyResult | null {
  if (!userId) {
    logger.warn('Unauthorized write attempt: missing userId in authorizer claims');
    return responseFormatter.error('Unauthorized', 401);
  }
  return null;
}

// SAFE BODY PARSING: Avoids crashes on invalid JSON bodies
function parseJsonBody(body: string | null): Record<string, unknown> | APIGatewayProxyResult {
  try {
    return body ? JSON.parse(body) : {};
  } catch (err) {
    logger.warn('Invalid JSON body', { error: err });
    return responseFormatter.error('Invalid JSON body', 400);
  }
}

// INPUT VALIDATION: Check if parsed body has required fields for creating a note
// TEACHING NOTE: We validate the shape before casting to satisfy TypeScript's type safety
// We use 'unknown' as the input type because we're validating data of unknown shape
function validateCreateNoteInput(data: unknown): data is CreateNoteInput {
  if (typeof data !== 'object' || data === null) return false;
  const obj = data as Record<string, unknown>;
  return typeof obj.title === 'string' && typeof obj.content === 'string';
}

// INPUT VALIDATION: Check if parsed body is valid for updating a note
// TEACHING NOTE: Update allows partial data, so we just check types if fields exist
// We use 'unknown' as the input type because we're validating data of unknown shape
function validateUpdateNoteInput(data: unknown): data is UpdateNoteInput {
  if (typeof data !== 'object' || data === null) return false;
  const obj = data as Record<string, unknown>;
  const hasValidTitle = obj.title === undefined || typeof obj.title === 'string';
  const hasValidContent = obj.content === undefined || typeof obj.content === 'string';
  const hasValidTags = obj.tags === undefined || Array.isArray(obj.tags);
  return hasValidTitle && hasValidContent && hasValidTags;
}

// ROUTE: POST /notes -> create a note
// SECURITY: We validate input here at the handler level (defense in depth)
async function handleCreateNote(userId: string, body: string | null): Promise<APIGatewayProxyResult> {
  const parsedBody = parseJsonBody(body);
  if (isErrorResponse(parsedBody)) return parsedBody;

  // VALIDATION: Check that required fields exist before calling service
  // TypeScript's type guard ensures safe casting after this check
  if (!validateCreateNoteInput(parsedBody)) {
    return responseFormatter.error('Missing required fields: title and content are required', 400);
  }

  // Now TypeScript knows parsedBody is CreateNoteInput (type narrowing)
  const note = await service.createNote(userId, parsedBody);
  return responseFormatter.success(note, 201);
}

// ROUTE: PUT /notes/:id -> update a note
// PARTIAL UPDATES: All fields are optional in UpdateNoteInput
async function handleUpdateNote(
  userId: string,
  noteId: string | undefined,
  body: string | null
): Promise<APIGatewayProxyResult> {
  if (!noteId) {
    return responseFormatter.error('Note ID is required', 400);
  }

  const parsedBody = parseJsonBody(body);
  if (isErrorResponse(parsedBody)) return parsedBody;

  // VALIDATION: Check that update fields have correct types
  if (!validateUpdateNoteInput(parsedBody)) {
    return responseFormatter.error('Invalid update data: check field types', 400);
  }

  // Now TypeScript knows parsedBody is UpdateNoteInput (type narrowing)
  const note = await service.updateNote(userId, noteId, parsedBody);
  return responseFormatter.success(note, 200);
}

// ROUTE: DELETE /notes/:id -> delete a note
async function handleDeleteNote(userId: string, noteId: string | undefined): Promise<APIGatewayProxyResult> {
  if (!noteId) {
    return responseFormatter.error('Note ID is required', 400);
  }

  await service.deleteNote(userId, noteId);
  return responseFormatter.success(null, 204);
}

// TYPE GUARD: Detect if parseJsonBody returned an error response
function isErrorResponse(value: Record<string, unknown> | APIGatewayProxyResult): value is APIGatewayProxyResult {
  return (value as APIGatewayProxyResult).statusCode !== undefined;
}

// MAIN HANDLER: Entry point for API Gateway → Lambda
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    // CORS PREFLIGHT: let browsers verify allowed methods/headers
    if (event.httpMethod === 'OPTIONS') {
      logger.info('CORS preflight request handled');
      return responseFormatter.success({}, 200);
    }

    // STEP 1: AUTHENTICATION (JWT already validated by API Gateway authorizer)
    const userId = extractUserId(event);
    const authError = validateAuthentication(userId);
    if (authError) return authError;
    const authenticatedUserId = userId as string;

    logger.info('Write handler invoked', {
      path: event.path,
      method: event.httpMethod,
      userId: authenticatedUserId
    });

    // STEP 2: ROUTING — pick the action based on HTTP method + path
    if (event.path === '/notes' && event.httpMethod === 'POST') {
      return await handleCreateNote(authenticatedUserId, event.body);
    }

    if (event.path.startsWith('/notes/') && event.httpMethod === 'PUT') {
      return await handleUpdateNote(authenticatedUserId, event.pathParameters?.id, event.body);
    }

    if (event.path.startsWith('/notes/') && event.httpMethod === 'DELETE') {
      return await handleDeleteNote(authenticatedUserId, event.pathParameters?.id);
    }

    logger.warn('No matching write route', { path: event.path, method: event.httpMethod });
    return responseFormatter.error('Not Found', 404);
  } catch (error: any) {
    // ERROR HANDLING
    // Custom errors keep messages specific; unknown errors stay generic to avoid leaking details
    logger.error('Write handler error', error);

    if (error instanceof NotFoundError) {
      return responseFormatter.error(error.message, 404);
    }

    if (error instanceof ValidationError) {
      return responseFormatter.error(error.message, 400);
    }

    return responseFormatter.error('Internal Server Error', 500);
  }
};