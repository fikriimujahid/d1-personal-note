// ============================================================================
// IMPORTS
// ============================================================================

// TanStack React Query hooks for managing server state
// - useQuery: Fetches and caches data from the server
// - useMutation: Handles create/update/delete operations
// - useQueryClient: Gives us access to the cache to manually invalidate/update it
// - useInfiniteQuery: Handles paginated data with infinite scroll
import { useQuery, useMutation, useQueryClient, useInfiniteQuery } from '@tanstack/react-query';

// Our API service that makes HTTP requests to the backend
import { notesApi } from '../services/notes-api';

// TypeScript types for type safety
import type { Note, CreateNoteInput, UpdateNoteInput, NotesFilters } from '../types';

// Toast notifications library (sonner) for user feedback
import { toast } from 'sonner';

// ============================================================================
// QUERY KEYS
// ============================================================================
// React Query uses "query keys" to identify cached data.
// Think of these as unique IDs for each piece of data in the cache.
//
// Why we need this:
// - When data changes (create/update/delete), we need to tell React Query
//   which cached data is now stale and needs to be refetched.
// - Query keys let us target specific cached data precisely.
//
// Key structure hierarchy:
// ['notes']                           -> All notes-related data
// ['notes', 'list']                   -> All note lists
// ['notes', 'list', { filters }]      -> Specific filtered list
// ['notes', 'detail']                 -> All individual notes
// ['notes', 'detail', 'note-123']     -> Specific note by ID
// ['notes', 'tags']                   -> All tags
//
// The 'as const' makes TypeScript treat these as literal types, not just strings.
export const noteKeys = {
  // Base key for all notes data
  all: ['notes'] as const,
  
  // Keys for note lists (multiple notes)
  lists: () => [...noteKeys.all, 'list'] as const,
  list: (filters?: NotesFilters) => [...noteKeys.lists(), filters] as const,
  
  // Keys for individual note details
  details: () => [...noteKeys.all, 'detail'] as const,
  detail: (id: string) => [...noteKeys.details(), id] as const,
  
  // Keys for tags (used for filtering/organizing notes)
  tags: () => [...noteKeys.all, 'tags'] as const,
};

// ============================================================================
// FETCH NOTES (Basic Pagination)
// ============================================================================
/**
 * Hook to fetch a list of notes from the server.
 * 
 * What this does:
 * - Fetches notes from the backend API
 * - Caches the result so we don't re-fetch unnecessarily
 * - Returns loading/error states automatically
 * 
 * Why we use React Query here:
 * - Automatic caching: If you navigate away and come back, data is instant
 * - Background refetching: Keeps data fresh without manual reload
 * - Loading/error states: No need to manage these manually with useState
 * 
 * Parameters:
 * @param page - Which page of results to fetch (default: 1)
 * @param limit - How many notes per page (default: 10)
 * @param filters - Optional filters (tags, search terms, etc.)
 * 
 * Returns:
 * - data: Array of notes (or undefined while loading)
 * - isLoading: true while fetching for the first time
 * - error: Error object if request failed
 * - refetch: Function to manually re-fetch data
 */
export function useNotes(page: number = 1, limit: number = 10, filters?: NotesFilters) {
  return useQuery({
    // Query key uniquely identifies this cached data
    // If filters/page/limit change, React Query treats it as a different query
    queryKey: noteKeys.list({ ...filters, page, limit } as any),
    
    // Query function: The actual async function that fetches data
    // Note: Backend uses cursor-based pagination (nextToken), but here we
    // only fetch the first page. For infinite scroll, see useInfiniteNotes.
    queryFn: () => notesApi.getNotes(undefined, limit),
    
    // Stale time: How long data is considered "fresh" (30 seconds)
    // Within this window, React Query won't refetch even if component remounts
    staleTime: 30000,
  });
}

// ============================================================================
// INFINITE SCROLL NOTES
// ============================================================================
/**
 * Hook for infinite scroll pagination (load more as you scroll).
 * 
 * What this does:
 * - Fetches notes in pages (10 at a time)
 * - Keeps all previous pages in memory as you load more
 * - Perfect for "Load More" buttons or infinite scroll UI
 * 
 * How cursor-based pagination works:
 * 1. First request: No cursor → backend returns first 10 notes + a "nextToken"
 * 2. Second request: Send nextToken → backend returns next 10 notes + new nextToken
 * 3. Repeat until nextToken is null (no more data)
 * 
 * Why use this instead of useNotes:
 * - useNotes is for traditional page 1, 2, 3 navigation
 * - useInfiniteNotes is for seamless "load more" experiences
 * 
 * @param filters - Optional filters to apply to the query
 * 
 * Returns:
 * - data.pages: Array of page results, each containing notes
 * - fetchNextPage: Function to load the next page
 * - hasNextPage: Boolean indicating if more data exists
 * - isFetchingNextPage: true while loading more data
 */
export function useInfiniteNotes(filters?: NotesFilters) {
  return useInfiniteQuery({
    // Query key for caching (same structure as useNotes)
    queryKey: noteKeys.list(filters),
    
    // Query function receives pageParam (the cursor/token for pagination)
    // First call: pageParam is undefined
    // Subsequent calls: pageParam is the nextToken from previous response
    queryFn: ({ pageParam }: { pageParam?: string }) => notesApi.getNotes(pageParam, 10),
    
    // This function tells React Query how to get the next page's cursor
    // It receives the last page's response and extracts the nextToken
    // If nextToken is null/undefined, React Query knows there are no more pages
    getNextPageParam: (lastPage) => lastPage.nextToken ?? undefined,
    
    // The initial cursor value (undefined = start from beginning)
    initialPageParam: undefined,
    
    // Keep data fresh for 30 seconds
    staleTime: 30000,
  });
}

// ============================================================================
// FETCH SINGLE NOTE
// ============================================================================
/**
 * Hook to fetch a single note by its ID.
 * 
 * What this does:
 * - Fetches one specific note from the backend
 * - Caches it separately from the notes list
 * - Used on note detail pages
 * 
 * Why cache individual notes separately:
 * - A note list might not have all the details (just title/preview)
 * - The full note (with content) is cached independently
 * - This prevents unnecessary re-fetching when viewing note details
 * 
 * @param id - The unique identifier of the note to fetch
 * 
 * Returns:
 * - data: The full note object (or undefined while loading)
 * - isLoading: true while fetching
 * - error: Error object if request failed
 */
export function useNote(id: string) {
  return useQuery({
    // Unique query key for this specific note
    // Example: ['notes', 'detail', 'abc-123']
    queryKey: noteKeys.detail(id),
    
    // Fetch function: Gets the note from the API
    queryFn: () => notesApi.getNote(id),
    
    // Enabled option: Only run this query if we have a valid ID
    // The !! converts the string to a boolean (empty string = false)
    // This prevents the query from running if id is undefined/null/empty
    enabled: !!id,
    
    // Individual notes stay fresh for 1 minute (longer than lists)
    // Rationale: A single note's content changes less frequently than the list
    staleTime: 60000,
  });
}

// ============================================================================
// FETCH ALL TAGS
// ============================================================================
/**
 * Hook to fetch all available tags from the backend.
 * 
 * What this does:
 * - Fetches a list of all unique tags used across all notes
 * - Used for filter dropdowns and tag suggestions
 * 
 * Why this is a separate query:
 * - Tags change rarely (only when notes are created/updated with new tags)
 * - We can cache them for a long time (5 minutes)
 * - Many components might need tags (filter UI, autocomplete, etc.)
 * 
 * Returns:
 * - data: Array of tag strings (or undefined while loading)
 * - isLoading: true while fetching
 * - error: Error object if request failed
 */
export function useTags() {
  return useQuery({
    // Query key for tags cache
    queryKey: noteKeys.tags(),
    
    // Fetch function: Gets all tags from the API
    queryFn: () => notesApi.getAllTags(),
    
    // Tags are cached for 5 minutes (longest of all our queries)
    // Why? Tags don't change often, so we can avoid unnecessary refetches
    staleTime: 300000,
  });
}

// ============================================================================
// CREATE NOTE MUTATION
// ============================================================================
/**
 * Hook to create a new note.
 * 
 * What this does:
 * - Sends a request to create a new note on the backend
 * - After success, invalidates related cached data so it refetches
 * - Shows success/error toast notifications to the user
 * 
 * Why we use useMutation (not useQuery):
 * - useQuery is for fetching data (GET requests)
 * - useMutation is for changing data (POST/PUT/DELETE requests)
 * 
 * Cache invalidation flow:
 * 1. User creates a note
 * 2. Backend saves it and returns the new note
 * 3. We tell React Query "the notes list is now stale, please refetch"
 * 4. We also invalidate tags (in case the new note has new tags)
 * 5. React Query automatically refetches any active queries with those keys
 * 
 * Returns:
 * - mutate: Function to call with CreateNoteInput to create a note
 * - mutateAsync: Async version that returns a promise
 * - isPending: true while the request is in flight
 * - error: Error object if request failed
 */
export function useCreateNote() {
  // Get access to the React Query cache
  // We need this to invalidate (mark as stale) cached data after creating a note
  const queryClient = useQueryClient();
  
  return useMutation({
    // Mutation function: The actual async operation that creates the note
    mutationFn: (input: CreateNoteInput) => notesApi.createNote(input),
    
    // onSuccess runs after the mutation succeeds
    // We receive the newly created note from the backend
    onSuccess: (newNote) => {
      // Invalidate all note lists so they refetch and include the new note
      // This affects ALL cached queries with keys starting with ['notes', 'list']
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      
      // Invalidate tags cache in case the new note introduced new tags
      queryClient.invalidateQueries({ queryKey: noteKeys.tags() });
      
      // Show success notification to the user (using sonner toast library)
      toast.success('Note created successfully!');
    },
    
    // onError runs if the mutation fails
    // We receive an Error object explaining what went wrong
    onError: (error: Error) => {
      // Show error notification to the user
      // Falls back to generic message if error.message is undefined
      toast.error(error.message || 'Failed to create note');
    },
  });
}

// ============================================================================
// UPDATE NOTE MUTATION (with Optimistic Updates)
// ============================================================================
/**
 * Hook to update an existing note.
 * 
 * What this does:
 * - Sends a request to update a note on the backend
 * - Uses "optimistic updates" to make the UI feel instant
 * - Rolls back if the request fails
 * 
 * What are optimistic updates?
 * Instead of waiting for the server response, we:
 * 1. Immediately update the UI with the new data
 * 2. Send the request to the backend in the background
 * 3. If it succeeds: Great! UI was already updated
 * 4. If it fails: Roll back the UI to the previous state
 * 
 * This makes the app feel fast and responsive even on slow connections.
 * 
 * Returns:
 * - mutate: Function to call with {id, input} to update a note
 * - isPending: true while the request is in flight
 * - error: Error object if request failed
 */
export function useUpdateNote() {
  // Get access to the React Query cache for manual updates
  const queryClient = useQueryClient();
  
  return useMutation({
    // Mutation function: Updates the note on the backend
    mutationFn: ({ id, input }: { id: string; input: UpdateNoteInput }) =>
      notesApi.updateNote(id, input),
    
    // onMutate runs BEFORE the request is sent (for optimistic updates)
    // This is where we immediately update the UI
    onMutate: async ({ id, input }) => {
      // Step 1: Cancel any in-progress queries for this note
      // Why? If there's a refetch happening, it might overwrite our optimistic update
      await queryClient.cancelQueries({ queryKey: noteKeys.detail(id) });
      
      // Step 2: Save the current note data (in case we need to roll back)
      const previousNote = queryClient.getQueryData<Note>(noteKeys.detail(id));
      
      // Step 3: Optimistically update the cache with the new data
      // We merge the old note data with the new input and update the timestamp
      if (previousNote) {
        queryClient.setQueryData<Note>(noteKeys.detail(id), {
          ...previousNote,      // Keep existing fields
          ...input,              // Override with new values
          updatedAt: new Date().toISOString(), // Update timestamp
        });
      }
      
      // Return context object (accessible in onError and onSuccess)
      // We'll use this to roll back if the update fails
      return { previousNote };
    },
    
    // onError runs if the mutation fails
    // This is where we roll back the optimistic update
    onError: (error: Error, { id }, context) => {
      // Roll back: Restore the previous note data from context
      if (context?.previousNote) {
        queryClient.setQueryData(noteKeys.detail(id), context.previousNote);
      }
      
      // Show error notification
      toast.error(error.message || 'Failed to update note');
    },
    
    // onSuccess runs after the mutation succeeds
    onSuccess: (updatedNote) => {
      // Invalidate note lists (in case title/preview changed)
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      
      // Invalidate tags (in case tags were added/removed)
      queryClient.invalidateQueries({ queryKey: noteKeys.tags() });
      
      // Note: We don't show a success toast here because the update felt instant
      // (due to optimistic updates). A toast would feel redundant.
    },
  });
}

// ============================================================================
// DELETE NOTE MUTATION
// ============================================================================
/**
 * Hook to delete a note.
 * 
 * What this does:
 * - Sends a request to delete a note from the backend
 * - Removes the note from the cache
 * - Invalidates related cached data
 * 
 * Cache cleanup strategy:
 * - We use removeQueries (not invalidateQueries) for the deleted note
 * - Why? The note doesn't exist anymore, so there's nothing to refetch
 * - For lists and tags, we use invalidateQueries to refetch updated data
 * 
 * Returns:
 * - mutate: Function to call with a note ID to delete it
 * - isPending: true while the request is in flight
 * - error: Error object if request failed
 */
export function useDeleteNote() {
  // Get access to the React Query cache
  const queryClient = useQueryClient();
  
  return useMutation({
    // Mutation function: Deletes the note on the backend
    mutationFn: (id: string) => notesApi.deleteNote(id),
    
    // onSuccess runs after successful deletion
    // The second parameter (id) is the input we passed to mutationFn
    onSuccess: (_, id) => {
      // Invalidate all note lists so they refetch without the deleted note
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      
      // Invalidate tags (in case deleted note was the only one with certain tags)
      queryClient.invalidateQueries({ queryKey: noteKeys.tags() });
      
      // Remove the individual note from cache completely
      // We use removeQueries (not invalidate) because the note no longer exists
      queryClient.removeQueries({ queryKey: noteKeys.detail(id) });
      
      // Show success notification
      toast.success('Note deleted successfully');
    },
    
    // onError runs if the deletion fails
    onError: (error: Error) => {
      // Show error notification
      toast.error(error.message || 'Failed to delete note');
    },
  });
}

// ============================================================================
// AUTOSAVE HOOK (with Debouncing)
// ============================================================================
/**
 * Hook for autosaving notes as the user types.
 * 
 * What this does:
 * - Automatically saves note changes after the user stops typing
 * - Uses "debouncing" to avoid saving on every keystroke
 * - Provides loading state to show "Saving..." indicator
 * 
 * What is debouncing?
 * Instead of saving after every keystroke, we wait for a pause in typing:
 * 1. User types "H" → Start timer (1 second)
 * 2. User types "e" → Reset timer
 * 3. User types "l" → Reset timer
 * 4. User types "l" → Reset timer
 * 5. User types "o" → Reset timer
 * 6. User pauses typing for 1 second → SAVE "Hello"
 * 
 * This prevents hundreds of unnecessary API requests while typing.
 * 
 * @param noteId - The ID of the note to autosave
 * @param debounceMs - How long to wait after last keystroke (default: 1000ms = 1 second)
 * 
 * Returns:
 * - autosave: Function to call with new note data
 * - isAutosaving: Boolean indicating if save is in progress
 * 
 */
export function useAutosave(noteId: string, debounceMs: number = 10000) {
  // Get the update mutation hook (handles the actual API request)
  const updateNote = useUpdateNote();
  
  // Timer ID for the debounce timeout
  // We need this outside the function so we can cancel it
  let timeoutId: NodeJS.Timeout;
  
  // The autosave function that components will call
  const autosave = (input: UpdateNoteInput) => {
    // Cancel any existing timer (if user is still typing)
    clearTimeout(timeoutId);
    
    // Start a new timer
    // After debounceMs milliseconds of no activity, save the note
    timeoutId = setTimeout(() => {
      updateNote.mutate({ id: noteId, input });
    }, debounceMs);
  };
  
  // Return the autosave function and loading state
  return { 
    autosave, 
    // isAutosaving is true while the API request is in flight
    isAutosaving: updateNote.isPending 
  };
}
