/**
 * NotesService – Business logic layer for Notes.
 *
 * Serverless request lifecycle:
 *  - API Gateway receives an HTTP request and invokes a Lambda.
 *  - The Lambda handler parses the event, authenticates the user (e.g., Cognito/JWT),
 *    and passes the `userId` plus validated inputs into this service.
 *  - This service is stateless and focuses on validation, logging, and delegating
 *    persistence to the repository. It returns plain data objects back to the handler,
 *    which converts them into HTTP responses.
 *
 * Authentication & Authorization:
 *  - Authentication is typically enforced by an API Gateway Authorizer (e.g., Cognito).
 *  - Authorization is enforced by scoping operations to the caller's `userId`. The repository
 *    uses `userId` as the partition key, ensuring users can only access their own notes.
 *
 * Error Handling:
 *  - This service throws typed errors (e.g., ValidationError) that handlers translate into
 *    clear HTTP responses without leaking sensitive details.
 *
 * Security & IAM:
 *  - Lambda functions should use IAM roles with least privilege — only the DynamoDB actions
 *    required for the notes table.
 *  - Environment variables (e.g., table name) are read by lower layers (repository). This
 *    service does not read env vars directly, keeping concerns separated.
 *
 * Lambda Learning Notes:
 *  - Lambdas are stateless between invocations; never store request state in class fields
 *    that must persist across requests.
 *  - Cold starts can occur when the runtime is initialized. Keep the code light and avoid
 *    heavy synchronous work in the hot path.
 *  - Timeout and memory settings are a trade-off: more memory can reduce cold start time and
 *    increase CPU, but costs more. Tune based on observed performance.
 */
import { NotesRepository } from '../repositories/NotesRepository';
import { Note, CreateNoteInput, UpdateNoteInput, ListNotesResponse } from '../types/note';
import { ValidationError } from '../types/errors';
import { generateId } from '../utils/id';
import { logger } from '../utils/logger';

export class NotesService {
  // Reuse the repository instance across Lambda invocations where possible.
  // This keeps the code stateless but avoids recreating clients on warm starts.
  private readonly repository = new NotesRepository();

  // Validation constraints extracted for clarity and easy maintenance.
  private static readonly TITLE_MAX = 120;
  private static readonly CONTENT_MAX = 10000;
  private static readonly TAGS_MAX = 10;
  private static readonly DEFAULT_LIST_LIMIT = 20;

  async createNote(userId: string, input: CreateNoteInput): Promise<Note> {
    logger.info('Creating note for user', { userId });
    this.validateCreateInput(input);

    // Create note
    const now = new Date().toISOString();
    const noteId = generateId();

    const note: Note = {
      id: noteId,
      title: input.title.trim(),
      content: input.content.trim(),
      tags: input.tags ?? [],
      createdAt: now,
      updatedAt: now,
    };

    await this.repository.create(userId, note);
    logger.info('Note created', { noteId });

    return note;
  }

  async listNotes(userId: string, limit: number = NotesService.DEFAULT_LIST_LIMIT, nextToken?: string): Promise<ListNotesResponse> {
    logger.info('Listing notes for user', { userId, limit });
    const result = await this.repository.list(userId, limit, nextToken);
    return result;
  }

  async getNote(userId: string, noteId: string): Promise<Note> {
    logger.info('Getting note', { userId, noteId });
    // Repository throws NotFoundError if the note does not exist.
    // Handlers should convert that into a 404 response.
    return await this.repository.get(userId, noteId);
  }

  async updateNote(userId: string, noteId: string, input: UpdateNoteInput): Promise<Note> {
    logger.info('Updating note', { userId, noteId });
    this.validateUpdateInput(input);

    // Trim fields when provided; maintain existing behavior (content may be empty).
    const sanitized: UpdateNoteInput = {
      title: input.title?.trim(),
      content: input.content?.trim(),
      tags: input.tags,
    };

    const note = await this.repository.update(userId, noteId, sanitized);
    logger.info('Note updated', { noteId });

    return note;
  }

  async deleteNote(userId: string, noteId: string): Promise<void> {
    logger.info('Deleting note', { userId, noteId });

    await this.repository.delete(userId, noteId);
    logger.info('Note deleted', { noteId });
  }

  // --- Private helpers -----------------------------------------------------

  private validateCreateInput(input: CreateNoteInput): void {
    if (!input.title || input.title.trim().length === 0) {
      throw new ValidationError('Title is required');
    }
    if (input.title.length > NotesService.TITLE_MAX) {
      throw new ValidationError(`Title must be ${NotesService.TITLE_MAX} characters or less`);
    }

    if (!input.content || input.content.trim().length === 0) {
      throw new ValidationError('Content is required');
    }
    if (input.content.length > NotesService.CONTENT_MAX) {
      throw new ValidationError(`Content must be ${NotesService.CONTENT_MAX} characters or less`);
    }

    if (input.tags && input.tags.length > NotesService.TAGS_MAX) {
      throw new ValidationError(`Maximum ${NotesService.TAGS_MAX} tags allowed`);
    }
  }

  private validateUpdateInput(input: UpdateNoteInput): void {
    if (input.title !== undefined) {
      if (!input.title || input.title.trim().length === 0) {
        throw new ValidationError('Title cannot be empty');
      }
      if (input.title.length > NotesService.TITLE_MAX) {
        throw new ValidationError(`Title must be ${NotesService.TITLE_MAX} characters or less`);
      }
    }

    if (input.content !== undefined) {
      if (input.content.length > NotesService.CONTENT_MAX) {
        throw new ValidationError(`Content must be ${NotesService.CONTENT_MAX} characters or less`);
      }
    }

    if (input.tags !== undefined && input.tags.length > NotesService.TAGS_MAX) {
      throw new ValidationError(`Maximum ${NotesService.TAGS_MAX} tags allowed`);
    }
  }
}