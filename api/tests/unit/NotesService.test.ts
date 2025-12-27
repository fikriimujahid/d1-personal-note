/**
 * Unit Tests for NotesService
 * 
 * PURPOSE: Test the business logic layer of our notes application
 * 
 * WHY UNIT TESTS?
 * - Verify business logic in isolation (without AWS dependencies)
 * - Ensure validation rules work correctly
 * - Fast execution (no network calls)
 * - Catch bugs before deployment to Lambda
 * 
 * TESTING STRATEGY:
 * - Mock the repository layer (no real DynamoDB calls)
 * - Focus on service logic and validation
 * - Test both success and error scenarios
 */

import { NotesService } from '../../src/services/NotesService';
import { NotesRepository } from '../../src/repositories/NotesRepository';
import { ValidationError, NotFoundError } from '../../src/types/errors';
import { Note } from '../../src/types/note';

/**
 * MOCKING EXPLAINED:
 * jest.mock() replaces the real NotesRepository with a fake version.
 * This prevents actual DynamoDB calls during tests.
 * 
 * Why mock?
 * - Tests run faster (no network I/O)
 * - Tests are isolated (no external dependencies)
 * - No AWS costs during testing
 * - Predictable test results
 */
jest.mock('../../src/repositories/NotesRepository');

/**
 * TEST SUITE: NotesService
 * 
 * This groups all tests for the NotesService class.
 * Each test verifies a specific behavior or validation rule.
 */
describe('NotesService', () => {
  // TEST FIXTURES: Reusable variables shared across tests
  let service: NotesService;
  let mockRepositoryInstance: jest.Mocked<NotesRepository>;

  /**
   * beforeEach: Runs before EACH test
   * 
   * PURPOSE: Reset test state to prevent tests from affecting each other
   * 
   * BEST PRACTICE: Each test should be independent and isolated
   */
  beforeEach(() => {
    // Clear all mock call history from previous tests
    jest.clearAllMocks();

    /**
     * Create a mock repository with fake methods
     * 
     * jest.fn() creates a "spy" function that:
     * - Tracks how many times it was called
     * - Records what arguments were passed
     * - Can return fake data we control
     */
    mockRepositoryInstance = {
      create: jest.fn(),  // Fake create method
      list: jest.fn(),    // Fake list method
      get: jest.fn(),     // Fake get method
      update: jest.fn(),  // Fake update method
      delete: jest.fn(),  // Fake delete method
    } as jest.Mocked<NotesRepository>;

    /**
     * Replace the real NotesRepository constructor
     * 
     * When NotesService creates a new NotesRepository,
     * it gets our mock instead of the real one.
     * This prevents actual DynamoDB calls.
     */
    (NotesRepository as jest.MockedClass<typeof NotesRepository>).mockImplementation(
      () => mockRepositoryInstance
    );

    // Create the service we're testing
    service = new NotesService();
  });

  /**
   * TEST GROUP: createNote
   * 
   * Tests the core functionality for creating new notes.
   * 
   * VALIDATION RULES TO TEST:
   * - Title: required, max 120 characters
   * - Content: required, max 10,000 characters
   * - Tags: optional, max 10 tags
   * - Data should be trimmed (whitespace removed)
   */
  describe('createNote', () => {
    /**
     * TEST: Happy Path
     * 
     * Verifies that a valid note can be created successfully.
     * This is the "everything works" scenario.
     */
    it('should successfully create a note with valid input', async () => {
      /**
       * ARRANGE: Set up test data
       * 
       * Create a fake note that the repository will return.
       * In a real Lambda, this would come from DynamoDB.
       */
      const mockNote: Note = {
        id: 'n_test123',              // Unique identifier
        title: 'Valid Title',         // User's title
        content: 'Valid content',     // User's content
        tags: [],                     // Empty tags array
        createdAt: new Date().toISOString(),  // Timestamp
        updatedAt: new Date().toISOString(),  // Timestamp
      };

      /**
       * Configure the mock to return our fake note
       * 
       * mockResolvedValue = "when called, return this value as a Promise"
       * This simulates a successful DynamoDB create operation
       */
      mockRepositoryInstance.create.mockResolvedValue(mockNote);

      /**
       * ACT: Execute the function we're testing
       * 
       * Call service.createNote with valid input data.
       * In a Lambda, this would be triggered by API Gateway.
       */
      const result = await service.createNote('user-123', {
        title: 'Valid Title',
        content: 'Valid content',
      });

      /**
       * ASSERT: Verify the results
       * 
       * Check that the returned note has the expected properties.
       * These assertions ensure the service behaves correctly.
       */
      expect(result).toBeDefined();
      expect(result.title).toBe('Valid Title');
      expect(result.content).toBe('Valid content');
    });

    /**
     * TEST: Empty Title Validation
     * 
     * RULE: Title cannot be empty
     * WHY: All notes need a meaningful title for listing/searching
     * 
     * SECURITY NOTE: This prevents garbage data in DynamoDB
     */
    it('should throw ValidationError if title is empty', async () => {
      // Expect the service to reject empty titles
      await expect(
        service.createNote('user-123', {
          title: '',
          content: 'Some content',
        })
      ).rejects.toThrow(ValidationError);
    });

    /**
     * TEST: Whitespace-Only Title
     * 
     * EDGE CASE: Title with only spaces should be invalid
     * 
     * WHY: Whitespace-only is effectively empty after trimming
     * This catches user attempts to bypass validation
     */
    it('should throw ValidationError if title is whitespace only', async () => {
      // "   " should be treated as empty after trimming
      await expect(
        service.createNote('user-123', {
          title: '   ',
          content: 'Some content',
        })
      ).rejects.toThrow('Title is required');
    });

    /**
     * TEST: Title Length Limit
     * 
     * RULE: Maximum 120 characters
     * 
     * WHY: 
     * - Keep titles concise and readable
     * - Prevent DynamoDB attribute size issues
     * - Ensure UI displays properly
     * 
     * LAMBDA CONSIDERATION: Validating early reduces unnecessary DynamoDB writes
     */
    it('should throw ValidationError if title exceeds 120 characters', async () => {
      // Create a title that's too long (121 characters)
      const longTitle = 'a'.repeat(121);
      
      await expect(
        service.createNote('user-123', {
          title: longTitle,
          content: 'Some content',
        })
      ).rejects.toThrow('Title must be 120 characters or less');
    });

    /**
     * TEST: Empty Content Validation
     * 
     * RULE: Content is required (cannot be empty)
     * WHY: A note without content has no value
     */
    it('should throw ValidationError if content is empty', async () => {
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: '',
        })
      ).rejects.toThrow(ValidationError);
    });

    /**
     * TEST: Whitespace-Only Content
     * 
     * Similar to title validation - whitespace isn't real content
     */
    it('should throw ValidationError if content is whitespace only', async () => {
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: '   ',
        })
      ).rejects.toThrow('Content is required');
    });

    /**
     * TEST: Content Length Limit
     * 
     * RULE: Maximum 10,000 characters
     * 
     * WHY:
     * - DynamoDB item size limit is 400KB
     * - Lambda response size should stay reasonable
     * - Prevent abuse/spam
     * 
     * COST CONSIDERATION: Larger items cost more in DynamoDB
     */
    it('should throw ValidationError if content exceeds 10000 characters', async () => {
      // Create content that's too long (10,001 characters)
      const longContent = 'a'.repeat(10001);
      
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: longContent,
        })
      ).rejects.toThrow('Content must be 10000 characters or less');
    });

    /**
     * TEST: Tags Limit
     * 
     * RULE: Maximum 10 tags per note
     * 
     * WHY:
     * - Prevent tag spam
     * - Keep DynamoDB queries efficient
     * - Maintain reasonable UI/UX
     * 
     * DESIGN NOTE: Tags enable filtering/searching in the future
     */
    it('should throw ValidationError if tags exceed 10', async () => {
      // Create 11 tags (exceeds limit)
      const manyTags = new Array(11).fill('tag');
      
      await expect(
        service.createNote('user-123', {
          title: 'Valid Title',
          content: 'Valid content',
          tags: manyTags,
        })
      ).rejects.toThrow('Maximum 10 tags allowed');
    });

    /**
     * TEST: Data Normalization (Trimming)
     * 
     * RULE: Remove leading/trailing whitespace from title and content
     * 
     * WHY:
     * - Consistent data format
     * - Prevent accidental whitespace from API calls
     * - Better user experience
     * 
     * BEST PRACTICE: Always normalize user input before storage
     */
    it('should trim title and content', async () => {
      // Mock the expected trimmed result
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Trimmed Title',
        content: 'Trimmed content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.create.mockResolvedValue(mockNote);

      // Input has extra spaces before and after
      const result = await service.createNote('user-123', {
        title: '  Trimmed Title  ',
        content: '  Trimmed content  ',
      });

      // Output should have spaces removed
      expect(result.title).toBe('Trimmed Title');
      expect(result.content).toBe('Trimmed content');
    });

    /**
     * TEST: Default Tags Array
     * 
     * RULE: If no tags provided, default to empty array
     * 
     * WHY:
     * - Consistent data structure (tags always exists)
     * - Simplifies queries (no null checks needed)
     * - Better TypeScript type safety
     */
    it('should include empty tags array when none provided', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Valid Title',
        content: 'Valid content',
        tags: [],  // Empty array, not undefined/null
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.create.mockResolvedValue(mockNote);

      // No tags provided in input
      const result = await service.createNote('user-123', {
        title: 'Valid Title',
        content: 'Valid content',
      });

      // Result should have empty array (not undefined)
      expect(result.tags).toEqual([]);
    });
  });

  /**
   * TEST GROUP: listNotes
   * 
   * Tests retrieving multiple notes for a user.
   * 
   * LAMBDA CONTEXT:
   * - This would typically be a GET /notes API call
   * - Results are paginated to manage Lambda memory/response size
   * - userId comes from JWT token (Cognito authentication)
   */
  describe('listNotes', () => {
    /**
     * TEST: Basic List Operation
     * 
     * Verifies we can retrieve a list of notes successfully.
     */
    it('should return a list of notes', async () => {
      // Mock a response with one note
      const mockNotes = {
        items: [
          {
            id: 'n_test1',
            title: 'Note 1',
            content: 'Content 1',
            tags: [],
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
          },
        ],
        nextToken: null,  // No more pages
      };

      mockRepositoryInstance.list.mockResolvedValue(mockNotes);

      const result = await service.listNotes('user-123');

      expect(result).toBeDefined();
      expect(result.items).toHaveLength(1);
      expect(result.nextToken).toBeNull();
    });

    /**
     * TEST: Pagination Support
     * 
     * PAGINATION EXPLAINED:
     * - DynamoDB can't return all items at once (1MB limit)
     * - nextToken = cursor to get next page
     * - limit = how many items per page
     * 
     * WHY PAGINATE:
     * - Lambda has memory limits (default 128MB)
     * - API Gateway has 10MB response limit
     * - Better performance for users
     */
    it('should support pagination with limit and nextToken', async () => {
      const mockNotes = {
        items: [],
        nextToken: 'token123',  // pragma: allowlist secret 
      };

      mockRepositoryInstance.list.mockResolvedValue(mockNotes);

      // Request with pagination parameters
      const result = await service.listNotes('user-123', 10, 'token123');

      expect(result.nextToken).toBe('token123');
    });
  });

  /**
   * TEST GROUP: getNote
   * 
   * Tests retrieving a single note by ID.
   * 
   * LAMBDA CONTEXT:
   * - GET /notes/{id} endpoint
   * - Fast single-item retrieval from DynamoDB
   * - userId ensures user can only access their own notes
   * 
   * SECURITY: Always verify userId matches note owner (authorization)
   */
  describe('getNote', () => {
    /**
     * TEST: Successful Retrieval
     * 
     * Happy path: note exists and user has access
     */
    it('should return a note by ID', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Test Note',
        content: 'Test content',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.get.mockResolvedValue(mockNote);

      const result = await service.getNote('user-123', 'n_test123');

      expect(result).toBeDefined();
      expect(result.id).toBe('n_test123');
    });

    /**
     * TEST: Not Found Error
     * 
     * ERROR HANDLING:
     * - Note doesn't exist, or
     * - User doesn't have access (wrong userId)
     * 
     * LAMBDA BEST PRACTICE:
     * - Return 404 Not Found (not 500 Internal Server Error)
     * - Don't reveal if note exists for other users (security)
     */
    it('should throw NotFoundError if note does not exist', async () => {
      mockRepositoryInstance.get.mockRejectedValue(
        new NotFoundError('Note not found')
      );

      await expect(
        service.getNote('user-123', 'nonexistent')
      ).rejects.toThrow(NotFoundError);
    });
  });

  /**
   * TEST GROUP: updateNote
   * 
   * Tests modifying existing notes.
   * 
   * LAMBDA CONTEXT:
   * - PUT/PATCH /notes/{id} endpoint
   * - Updates are partial (only changed fields)
   * - DynamoDB UpdateItem operation
   * 
   * IMPORTANT:
   * - Validate all updates (even partial ones)
   * - Update timestamps (updatedAt)
   * - Preserve data integrity
   */
  describe('updateNote', () => {
    /**
     * TEST: Successful Update
     * 
     * Verifies we can update all fields of a note.
     */
    it('should successfully update a note', async () => {
      // Mock the updated note result
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Updated Title',
        content: 'Updated content',
        tags: ['updated'],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),  // This should change
      };

      mockRepositoryInstance.update.mockResolvedValue(mockNote);

      const result = await service.updateNote('user-123', 'n_test123', {
        title: 'Updated Title',
        content: 'Updated content',
        tags: ['updated'],
      });

      expect(result.title).toBe('Updated Title');
      expect(result.content).toBe('Updated content');
    });

    /**
     * TEST: Update Validation - Empty Title
     * 
     * IMPORTANT: Validation applies to updates too!
     * 
     * If user tries to update title to empty string,
     * reject it (same rules as create)
     */
    it('should throw ValidationError if updated title is empty', async () => {
      await expect(
        service.updateNote('user-123', 'n_test123', {
          title: '',
        })
      ).rejects.toThrow('Title cannot be empty');
    });

    /**
     * TEST: Update Validation - Title Length
     * 
     * Same 120-character limit applies to updates
     */
    it('should throw ValidationError if updated title exceeds 120 characters', async () => {
      const longTitle = 'a'.repeat(121);
      
      await expect(
        service.updateNote('user-123', 'n_test123', {
          title: longTitle,
        })
      ).rejects.toThrow('Title must be 120 characters or less');
    });

    /**
     * TEST: Update Validation - Content Length
     * 
     * Same 10,000-character limit applies to updates
     */
    it('should throw ValidationError if updated content exceeds 10000 characters', async () => {
      const longContent = 'a'.repeat(10001);
      
      await expect(
        service.updateNote('user-123', 'n_test123', {
          content: longContent,
        })
      ).rejects.toThrow('Content must be 10000 characters or less');
    });

    /**
     * TEST: Update Validation - Tags Limit
     * 
     * Same 10-tag limit applies to updates
     */
    it('should throw ValidationError if updated tags exceed 10', async () => {
      const manyTags = new Array(11).fill('tag');
      
      await expect(
        service.updateNote('user-123', 'n_test123', {
          tags: manyTags,
        })
      ).rejects.toThrow('Maximum 10 tags allowed');
    });

    /**
     * TEST: Partial Updates
     * 
     * KEY FEATURE: Users can update just one field
     * 
     * EXAMPLE:
     * - Update only title (keep content/tags unchanged)
     * - Update only content (keep title/tags unchanged)
     * - Update only tags (keep title/content unchanged)
     * 
     * LAMBDA BENEFIT:
     * - Smaller payloads = faster Lambda execution
     * - DynamoDB UpdateItem only changes specified attributes
     * - Less data transferred = lower costs
     */
    it('should allow partial updates', async () => {
      const mockNote: Note = {
        id: 'n_test123',
        title: 'Updated Title',       // Changed
        content: 'Original content',  // Unchanged
        tags: [],                     // Unchanged
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      mockRepositoryInstance.update.mockResolvedValue(mockNote);

      // Only update the title
      const result = await service.updateNote('user-123', 'n_test123', {
        title: 'Updated Title',
        // content and tags not provided = keep existing values
      });

      expect(result.title).toBe('Updated Title');
    });
  });

  /**
   * TEST GROUP: deleteNote
   * 
   * Tests removing notes from the system.
   * 
   * LAMBDA CONTEXT:
   * - DELETE /notes/{id} endpoint
   * - DynamoDB DeleteItem operation
   * - Permanent deletion (no soft delete in this design)
   * 
   * SECURITY CONSIDERATION:
   * - Verify userId before deletion (prevent unauthorized deletes)
   * - Return same response whether note existed or not (prevent enumeration)
   */
  describe('deleteNote', () => {
    /**
     * TEST: Successful Deletion
     * 
     * Verifies delete operation is called with correct parameters.
     * 
     * NOTE: Delete methods typically return void (nothing)
     * Success = no error thrown
     */
    it('should successfully delete a note', async () => {
      // Mock successful deletion (returns nothing)
      mockRepositoryInstance.delete.mockResolvedValue(undefined);

      // Execute the deletion
      await service.deleteNote('user-123', 'n_test123');

      /**
       * ASSERTION: Verify the repository method was called correctly
       * 
       * This ensures:
       * - Correct userId used (authorization)
       * - Correct noteId used (targeting right note)
       * 
       * toHaveBeenCalledWith = "check the arguments passed to the function"
       */
      expect(mockRepositoryInstance.delete).toHaveBeenCalledWith(
        'user-123',
        'n_test123'
      );
    });
  });
});

/**
 * ═══════════════════════════════════════════════════════════════
 * TESTING BEST PRACTICES SUMMARY
 * ═══════════════════════════════════════════════════════════════
 * 
 * 1. TEST STRUCTURE (AAA Pattern):
 *    - Arrange: Set up test data
 *    - Act: Execute the function
 *    - Assert: Verify the results
 * 
 * 2. ISOLATION:
 *    - Each test is independent
 *    - Mock external dependencies
 *    - Reset state between tests (beforeEach)
 * 
 * 3. COVERAGE:
 *    - Happy path (success cases)
 *    - Error cases (validation failures)
 *    - Edge cases (empty strings, limits)
 * 
 * 4. LAMBDA-SPECIFIC CONSIDERATIONS:
 *    - Validate early (before DynamoDB calls)
 *    - Consider payload sizes
 *    - Test pagination
 *    - Verify authorization checks
 * 
 * 5. NAMING CONVENTIONS:
 *    - Test names describe behavior
 *    - Use "should" statements
 *    - Be specific about what's tested
 * 
 * ═══════════════════════════════════════════════════════════════
 * WHY TESTING MATTERS FOR SERVERLESS:
 * ═══════════════════════════════════════════════════════════════
 * 
 * - COST: Every Lambda invocation costs money. Tests catch bugs
 *   before they run in production and generate AWS charges.
 * 
 * - SPEED: Unit tests run in milliseconds. Integration tests with
 *   real AWS services take seconds and cost money.
 * 
 * - CONFIDENCE: Deploy fearlessly knowing your business logic is
 *   correct. Lambda cold starts and network issues are separate
 *   concerns.
 * 
 * - DOCUMENTATION: Tests show how the code is meant to be used.
 *   New developers learn from reading tests.
 * 
 * ═══════════════════════════════════════════════════════════════
 */