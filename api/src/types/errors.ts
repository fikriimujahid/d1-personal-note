/**
 * Typed error classes used by our Lambda handlers.
 *
 * Why this exists (Lambda + API Gateway context):
 * - Handlers throw specific errors (validation, auth, not found) so we can
 *   map them cleanly to API Gateway HTTP responses (e.g., 400, 401, 404)
 *   without leaking sensitive details.
 * - Keeping error types simple and explicit improves readability for
 *   beginners and makes our serverless functions easier to maintain.
 *
 * Security and serverless notes:
 * - Do not include internal stack traces or secrets in messages returned
 *   to clients. These classes carry minimal, user-safe messages.
 * - Lambdas are stateless; errors should describe what went wrong in the
 *   single invocation, not maintain or depend on external state.
 * - IAM roles and least privilege: throwing `UnauthorizedError` typically
 *   reflects failed auth/authorization checks performed by Cognito/JWT or
 *   our own checks. Keep role permissions tight; do not expose details.
 * - Cold starts: the first invocation of a new Lambda runtime can be slower;
 *   keeping error handling simple avoids extra overhead during cold starts.
 * - Timeout & memory trade-offs: more memory can reduce latency (including
 *   cold starts) but costs more; errors should be lightweight to avoid
 *   unnecessary compute during failure paths.
 */

/**
 * Thrown when the incoming request fails input validation.
 *
 * Example: missing required fields, invalid UUID formats, or wrong types.
 *
 * How it becomes an HTTP response:
 * - Our handler or a shared error-to-response utility should translate this
 *   to a `400 Bad Request` with a concise message.
 */
export class ValidationError extends Error {
  /** Numeric HTTP status code to help format responses. */
  public readonly statusCode = 400;

  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
    // Ensure `instanceof ValidationError` works reliably across transpilation.
    Object.setPrototypeOf(this, ValidationError.prototype);
  }
}

/**
 * Thrown when a requested resource cannot be found.
 *
 * Example: trying to read a note by ID that does not exist.
 *
 * How it becomes an HTTP response:
 * - Translate to `404 Not Found` with a user-safe message.
 */
export class NotFoundError extends Error {
  /** Numeric HTTP status code to help format responses. */
  public readonly statusCode = 404;

  constructor(message: string) {
    super(message);
    this.name = 'NotFoundError';
    Object.setPrototypeOf(this, NotFoundError.prototype);
  }
}

/**
 * Thrown when authentication or authorization fails.
 *
 * Examples:
 * - Missing/invalid JWT in the `Authorization` header.
 * - Caller is authenticated but not allowed to access the resource.
 *
 * How it becomes an HTTP response:
 * - Translate to `401 Unauthorized` (or `403 Forbidden` if appropriate).
 *   We default to `401` here; choose based on your auth flow.
 */
export class UnauthorizedError extends Error {
  /** Numeric HTTP status code to help format responses. */
  public readonly statusCode = 401;

  constructor(message: string) {
    super(message);
    this.name = 'UnauthorizedError';
    Object.setPrototypeOf(this, UnauthorizedError.prototype);
  }
}
