/**
 * READ HANDLER FOR NOTES API
 * 
 * REQUEST LIFECYCLE:
 * 1. API Gateway receives HTTP request (GET /notes or GET /notes/:id)
 * 2. API Gateway triggers this Lambda function with the event object
 * 3. Authentication: API Gateway validates JWT token, passes userId in event.requestContext
 * 4. This handler routes the request to the correct service method
 * 5. Service retrieves data from DynamoDB
 * 6. Handler returns formatted JSON response to API Gateway
 * 7. API Gateway sends response back to client
 * 
 * SERVERLESS ARCHITECTURE NOTE:
 * This Lambda is stateless - it has no memory of previous requests.
 * The 'service' instance is created once per Lambda warm start.
 */

import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { NotesService } from '../../services/NotesService';
import { responseFormatter } from '../../utils/response';
import { logger } from '../../utils/logger';
import { NotFoundError, ValidationError } from '../../types/errors';

// Create a single instance of the service
// This instance is reused across multiple invocations (warm starts)
const service = new NotesService();

// HELPER FUNCTION: Extract and validate userId from API Gateway authorizer
// 
// AUTHENTICATION FLOW:
// 1. API Gateway uses Cognito/JWT to validate the token
// 2. If valid, it passes the decoded claims in event.requestContext.authorizer
// 3. The 'sub' (subject) claim is the unique user ID
// 4. We extract it here - if missing, the request wasn't properly authenticated
//
// SECURITY NOTE: This userId comes from the API Gateway authorizer, 
// which means we can trust it (not user-provided input)
function extractUserId(event: APIGatewayProxyEvent): string | null {
  return event.requestContext.authorizer?.claims?.sub || null;
}

// HELPER FUNCTION: Validate that we have a valid request
function validateAuthentication(userId: string | null): APIGatewayProxyResult | null {
  if (!userId) {
    logger.warn('Unauthorized request: no userId in authorizer claims');
    return responseFormatter.error('Unauthorized', 401);
  }
  return null;
}

// HELPER FUNCTION: Handle GET /notes (list all notes for a user)
//
// PARAMETERS FROM API GATEWAY:
// - limit: max number of notes to return (pagination)
// - nextToken: for fetching the next page of results
//
// SECURITY NOTE: We always filter by userId to ensure users only see their own notes
// (DynamoDB queries use userId as the partition key)
async function handleListNotes(
  userId: string,
  limit?: string,
  nextToken?: string
): Promise<APIGatewayProxyResult> {
  const parsedLimit = parseInt(limit || '20', 10);
  
  // Input validation: ensure limit is reasonable
  if (isNaN(parsedLimit) || parsedLimit < 1 || parsedLimit > 100) {
    return responseFormatter.error('Limit must be between 1 and 100', 400);
  }

  const result = await service.listNotes(userId, parsedLimit, nextToken);
  return responseFormatter.success(result, 200);
}

// HELPER FUNCTION: Handle GET /notes/:id (get a single note)
//
// ROUTE PARAMETER:
// - id: the unique note ID (extracted from URL path)
//
// SECURITY NOTE: The service.getNote() verifies that the note belongs to the userId
// (it won't return notes from other users)
async function handleGetNoteById(
  userId: string,
  noteId?: string
): Promise<APIGatewayProxyResult> {
  if (!noteId) {
    return responseFormatter.error('Note ID is required', 400);
  }

  const note = await service.getNote(userId, noteId);
  return responseFormatter.success(note, 200);
}

// HELPER FUNCTION: Handle GET /notes/tags (get unique tags for the user)
async function handleGetTags(userId: string): Promise<APIGatewayProxyResult> {
  const tags = await service.getAllTags(userId);
  return responseFormatter.success({ items: tags }, 200);
}

// MAIN HANDLER FUNCTION
// 
// This is the entry point for the Lambda function.
// AWS Lambda invokes this function with an APIGatewayProxyEvent.
// 
// WHAT WE DO:
// 1. Validate CORS preflight requests (browser sends these before actual requests)
// 2. Extract and validate the user ID from the authentication token
// 3. Route to the correct handler based on HTTP method and path
// 4. Catch any errors and return appropriate responses
//
// LEARNING NOTE - COLD STARTS:
// The first request to this Lambda (cold start) takes longer because AWS needs to
// initialize the Node.js runtime. Subsequent requests (warm starts) are faster.
// This is why we create the 'service' instance outside the handler.
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  try {
    // CORS PREFLIGHT: Browsers send OPTIONS requests before actual requests
    // We respond with success to allow the actual request to proceed
    if (event.httpMethod === 'OPTIONS') {
      logger.info('CORS preflight request handled');
      return responseFormatter.success({}, 200);
    }

    // STEP 1: AUTHENTICATION
    // Extract userId from the JWT token (validated by API Gateway)
    const userId = extractUserId(event);
    
    // STEP 2: AUTHORIZATION CHECK
    // Make sure we have a valid authenticated user
    const authError = validateAuthentication(userId);
    if (authError) {
      return authError;
    }

    // At this point, userId is guaranteed to be a non-null string (TypeScript narrowing)
    const authenticatedUserId = userId as string;

    logger.info('Read handler invoked', { 
      path: event.path, 
      method: event.httpMethod,
      userId: authenticatedUserId
    });

    // STEP 3: ROUTE THE REQUEST
    // Match the HTTP path and method to the appropriate handler

    // Route: GET /notes (list all notes)
    if (event.path === '/notes' && event.httpMethod === 'GET') {
      return await handleListNotes(
        authenticatedUserId,
        event.queryStringParameters?.limit,
        event.queryStringParameters?.nextToken
      );
    }

    // Route: GET /notes/tags (unique tag list)
    if (event.path === '/notes/tags' && event.httpMethod === 'GET') {
      return await handleGetTags(authenticatedUserId);
    }

    // Route: GET /notes/:id (get a specific note)
    if (event.path.startsWith('/notes/') && event.httpMethod === 'GET') {
      const noteId = event.pathParameters?.id;
      return await handleGetNoteById(authenticatedUserId, noteId);
    }

    // No matching route found
    logger.warn('No matching route', { path: event.path, method: event.httpMethod });
    return responseFormatter.error('Not Found', 404);

  } catch (error: any) {
    // ERROR HANDLING
    // We catch all errors here and transform them into appropriate HTTP responses
    logger.error('Read handler error', error);

    // Custom application errors - handle gracefully
    if (error instanceof NotFoundError) {
      return responseFormatter.error(error.message, 404);
    }

    if (error instanceof ValidationError) {
      return responseFormatter.error(error.message, 400);
    }

    // Unexpected errors - don't leak sensitive information to the client
    // Always return a generic error message
    return responseFormatter.error('Internal Server Error', 500);
  }
};