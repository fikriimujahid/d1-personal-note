/**
 * Notes API Service — Backend Communication for Notes Feature
 * 
 * This file handles all HTTP requests related to notes (the core feature of our app).
 * 
 * What are notes?
 * The main content users create: text notes with titles, content, tags, etc.
 * 
 * Why this file exists:
 * - Centralizes all notes-related API calls in one place
 * - Provides typed functions that React components can call
 * - Abstracts away HTTP request details (URLs, params, response handling)
 * - Uses the configured axios client (with auth tokens) from api-client.ts
 * 
 * Pattern used:
 * Each function returns a Promise with the data type our components expect.
 * Errors are thrown and caught by the calling component (usually React Query).
 */

import client from './api-client';
import type { Note } from '../types';
import type { CreateNoteRequest, UpdateNoteRequest } from '../types/note';

/**
 * TYPE: Backend Response Shape for List Endpoint
 * 
 * This describes what the backend API returns when we fetch a list of notes.
 * 
 * Why nextToken?
 * The backend uses "cursor-based pagination" for performance.
 * Instead of "page 1, 2, 3", it returns a nextToken that points to the next batch.
 * 
 * Cursor-based pagination benefits:
 * - Handles real-time data changes (new notes added while browsing)
 * - More efficient for large datasets
 * - Doesn't skip or duplicate items if data changes between requests
 * 
 * Example response:
 * {
 *   items: [{ id: '1', title: 'Note 1', ... }, { id: '2', title: 'Note 2', ... }],
 *   nextToken: '' // Used to fetch the next batch
 * }
 */
type ListNotesResponse = {
  items: Note[];           // Array of note objects
  nextToken?: string;      // Token for next page (undefined if last page)
};

/**
 * TYPE: Paginated Notes for Frontend Use
 * 
 * This is what our React components receive from the getNotes function.
 * It wraps the backend response with additional metadata for the UI.
 * 
 * Why this separate type?
 * The backend format (ListNotesResponse) isn't ideal for UI components.
 * We transform it into a more useful shape with extra information.
 * 
 * Fields explained:
 * - data: The actual note objects to display
 * - nextToken: Pass this to the next request to get more notes
 * - hasMore: Boolean to show/hide "Load More" button
 * - page: Approximate page number (mainly for debugging)
 * - limit: How many items were requested
 * - total: How many items were returned in this batch
 */
type PaginatedNotes = {
  data: Note[];           // The notes to display
  nextToken?: string;     // Cursor for next batch
  hasMore: boolean;       // True if more notes exist
  page: number;           // Approximate page number
  limit: number;          // Requested batch size
  total: number;          // Actual items returned
};

/**
 * NOTES API OBJECT
 * 
 * Groups all notes-related API functions together.
 * Similar pattern to authApi in auth.ts.
 * 
 * Import usage:
 * import { notesApi } from './notes-api';
 * const notes = await notesApi.getNotes();
 */
export const notesApi = {
  /**
   * GET NOTES (with Cursor-Based Pagination)
   * 
   * Fetches a paginated list of notes from the backend.
   * 
   * How pagination works:
   * 1. First request: Call getNotes() with no cursor → Get first batch + nextToken
   * 2. Load more: Call getNotes(nextToken) → Get next batch + new nextToken
   * 3. Repeat until nextToken is undefined (no more notes)
   * 
   * Why cursor instead of page numbers?
   * - Page 1-2-3 can skip items if new notes are added
   * - Cursors point to an exact position in the dataset
   * - More reliable for real-time data
   * 
   * Example usage in React Query:
   * const { data } = useQuery(['notes'], () => notesApi.getNotes());
   * 
   * @param cursor - Optional nextToken from previous request (for "Load More")
   * @param limit - How many notes to fetch (default: 10)
   * @returns Promise<PaginatedNotes> - Notes with pagination metadata
   */
  getNotes: async (cursor?: string, limit: number = 10): Promise<PaginatedNotes> => {
    // Build query parameters object
    // Record<string, string | number> means: keys are strings, values are strings or numbers
    const params: Record<string, string | number> = { limit };
    
    // Only add nextToken if we're fetching a subsequent page
    // This keeps the first request clean: GET /notes?limit=10
    if (cursor) params.nextToken = cursor;

    // Make GET request to /notes endpoint
    // client.get is from api-client.ts (includes auth token automatically)
    // <ListNotesResponse> tells TypeScript what shape to expect in response.data
    // { params } sends query params: ?limit=10&nextToken=abc123
    const response = await client.get<ListNotesResponse>('/notes', { params });
    
    // Extract data from response
    // Use ?? [] (nullish coalescing) to default to empty array if items is null/undefined
    const items = response.data.items ?? [];
    const nextToken = response.data.nextToken;

    // Transform backend response into our PaginatedNotes format
    return {
      data: items,                        // The actual notes
      nextToken,                          // Cursor for next batch
      hasMore: Boolean(nextToken),        // Convert string|undefined to boolean
      page: cursor ? 2 : 1,               // Approximate page (1 for first, 2+ for subsequent)
      limit,                              // Echo back the requested limit
      total: items.length,                // How many items in this batch
    };
  },

  /**
   * LIST ALL NOTES (without pagination)
   * 
   * Simpler version of getNotes that returns just the array of notes.
   * No pagination metadata, just the raw items array.
   * 
   * When to use this vs getNotes:
   * - Use this when you need all notes at once (e.g., for a dropdown, tag filtering)
   * - Use getNotes when displaying a paginated list with "Load More"
   * 
   * Note: This still only returns the first batch from the backend.
   * If there are more notes, they won't be included. For truly "all notes",
   * you'd need to loop through all pages using getNotes with nextToken.
   * 
   * @returns Promise<Note[]> - Array of notes
   */
  listNotes: async (): Promise<Note[]> => {
    // Make GET request to /notes
    // Inline type definition: we expect { items: Note[], nextToken?: string }
    const response = await client.get<{ items: Note[]; nextToken?: string }>('/notes');
    
    // Return only the items array, ignore pagination metadata
    return response.data.items;
  },

  /**
   * GET SINGLE NOTE BY ID
   * 
   * Fetches details for one specific note.
   * 
   * When is this used?
   * - When user clicks on a note to view/edit it
   * - When navigating to a direct URL like /notes/abc123
   * - When you need the full note data (list endpoints might return partial data)
   * 
   * URL pattern:
   * GET /notes/abc123 where abc123 is the note ID
   * 
   * Error handling:
   * - If note doesn't exist: Backend returns 404, axios throws error
   * - If user lacks permission: Backend returns 403, axios throws error
   * - Calling code (React Query) catches these errors and handles them
   * 
   * @param id - The unique identifier of the note
   * @returns Promise<Note> - The complete note object
   */
  getNote: async (id: string): Promise<Note> => {
    // GET request to /notes/:id
    // Template literal: `/notes/${id}` becomes "/notes/abc123"
    // <Note> tells TypeScript the response.data is a Note object
    const response = await client.get<Note>(`/notes/${id}`);
    
    // Return the note data directly
    return response.data;
  },

  /**
   * CREATE NEW NOTE
   * 
   * Sends a request to create a new note in the database.
   * 
   * What happens:
   * 1. User fills out a form (title, content, tags)
   * 2. Form submits and calls this function with the data
   * 3. We POST the data to /notes endpoint
   * 4. Backend validates, generates an ID, saves to DynamoDB
   * 5. Backend returns the complete note object (with ID, timestamps, etc.)
   * 6. We return that note to the calling component
   * 7. React Query updates its cache with the new note
   * 
   * CreateNoteRequest type typically includes:
   * - title: string
   * - content: string
   * - tags?: string[]
   * (No ID needed - backend generates it)
   * 
   * @param payload - The note data to create (without ID)
   * @returns Promise<Note> - The newly created note (with ID)
   */
  createNote: async (payload: CreateNoteRequest): Promise<Note> => {
    // POST request to /notes with the note data as request body
    // client.post automatically:
    // - Sets Content-Type: application/json
    // - Adds Authorization header with JWT token
    // - Converts payload object to JSON string
    const response = await client.post<Note>('/notes', payload);
    
    // Return the created note (includes generated ID, timestamps, etc.)
    return response.data;
  },

  /**
   * UPDATE EXISTING NOTE
   * 
   * Sends a request to update an existing note.
   * 
   * PUT vs PATCH:
   * We use PUT which typically means "replace entire resource".
   * If you only want to update specific fields, PATCH might be more appropriate.
   * Check with your backend API documentation.
   * 
   * What happens:
   * 1. User edits a note in the form
   * 2. Form submits with note ID + updated data
   * 3. We PUT the data to /notes/:id
   * 4. Backend validates, updates DynamoDB
   * 5. Backend returns the updated note
   * 6. React Query updates its cache
   * 
   * UpdateNoteRequest might include:
   * - title?: string (optional - only if changed)
   * - content?: string
   * - tags?: string[]
   * 
   * Security:
   * - Backend verifies the note belongs to the authenticated user
   * - If not: Returns 403 Forbidden
   * 
   * @param id - The note ID to update
   * @param payload - The updated note data
   * @returns Promise<Note> - The updated note object
   */
  updateNote: async (id: string, payload: UpdateNoteRequest): Promise<Note> => {
    // PUT request to /notes/:id with updated data
    // Template literal: `/notes/${id}` becomes "/notes/abc123"
    const response = await client.put<Note>(`/notes/${id}`, payload);
    
    // Return the updated note
    return response.data;
  },

  /**
   * DELETE NOTE
   * 
   * Permanently removes a note from the database.
   * 
   * What happens:
   * 1. User clicks delete button (usually with a confirmation dialog)
   * 2. We send DELETE request to /notes/:id
   * 3. Backend validates ownership and deletes from DynamoDB
   * 4. Backend returns success (usually 204 No Content or 200 OK)
   * 5. React Query removes the note from its cache
   * 6. UI updates to remove the note from the list
   * 
   * Important:
   * - This is PERMANENT - no undo (unless backend implements soft delete)
   * - Always show a confirmation dialog before calling this
   * - Backend ensures users can only delete their own notes
   * 
   * Why Promise<void>?
   * DELETE requests typically don't return data, just a success status.
   * We don't need to return anything from this function.
   * 
   * @param id - The note ID to delete
   * @returns Promise<void> - Resolves when deletion is complete
   */
  deleteNote: async (id: string): Promise<void> => {
    // DELETE request to /notes/:id
    // We don't need to capture the response - just wait for it to complete
    await client.delete(`/notes/${id}`);
    
    // No return needed - function resolves when request completes
  },

  /**
   * GET ALL TAGS
   * 
   * Fetches a list of all unique tags used across all user's notes.
   * 
   * What are tags?
   * Labels/categories users can add to notes for organization.
   * Examples: "work", "personal", "important", "todo"
   * 
   * Why this endpoint?
   * To show a tag filter UI or tag suggestions when creating/editing notes.
   * Instead of letting users type any random tag, we show their existing tags.
   * 
   * How it works:
   * 1. Backend queries all user's notes
   * 2. Extracts all tags and deduplicates them
   * 3. Returns array of unique tag strings
   * 
   * Example response:
   * {
   *   items: ["work", "personal", "todo", "urgent"]
   * }
   * 
   * Performance note:
   * This could be slow if a user has thousands of notes with many tags.
   * Consider caching this in React Query with a longer staleTime.
   * 
   * @returns Promise<string[]> - Array of unique tag strings
   */
  getAllTags: async (): Promise<string[]> => {
    // GET request to /notes/tags
    // This is a special endpoint (not /notes/:id) for aggregated data
    const response = await client.get<{ items: string[] }>(`/notes/tags`);
    
    // Return the tags array
    // Use ?? [] to default to empty array if items is null/undefined
    return response.data.items ?? [];
  },
};