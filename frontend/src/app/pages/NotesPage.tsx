/**
 * NotesPage Component
 * 
 * This is the main page for viewing, creating, and managing notes.
 * It demonstrates several key React patterns:
 * 
 * 1. Local state management with useState for UI state (filters, dialogs, form inputs)
 * 2. Server state management with React Query for API data (notes from backend)
 * 3. Client-side filtering and sorting (API returns unfiltered data)
 * 4. Infinite scroll pagination pattern (load more pages on demand)
 * 5. Optimistic UI updates through React Query mutations
 * 
 * Data Flow:
 * User → UI Interaction → Local State Update → React Query → API → Cache → UI Re-render
 */

import React, { useMemo, useState } from 'react';
import { Plus, Search, SlidersHorizontal, Loader2 } from 'lucide-react';

// Custom hooks that wrap React Query for server state management
// These handle API calls, caching, loading states, and error handling
import { useInfiniteNotes, useDeleteNote } from '../../hooks/useNotes';

// UI Components - organized by domain (Notes) and primitives (ui/)
import { NoteCard } from '../components/Notes/NoteCard';
import { EmptyState } from '../components/Notes/EmptyState';

// Radix-based UI primitives styled with Tailwind
// These provide accessible, unstyled components that we customize
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '../components/ui/dialog';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '../components/ui/alert-dialog';
import { Skeleton } from '../components/ui/skeleton';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
import { useCreateNote } from '../../hooks/useNotes';

// TypeScript type for filter state
import type { NotesFilters } from '../../types';

export function NotesPage() {
  // ============================================================================
  // LOCAL STATE MANAGEMENT
  // ============================================================================
  // This component uses local state for UI-only concerns (dialog visibility,
  // form inputs, filters). Server data (notes) is managed by React Query below.
  
  /**
   * Filters State
   * Stores user preferences for searching, filtering, and sorting notes.
   * Lives in this component because it's specific to this page's UI.
   * When filters change, we re-compute the filtered list client-side.
   */
  const [filters, setFilters] = useState<NotesFilters>({
    search: '',      // Search term for title/content
    tags: [],        // Array of tags to filter by
    sortBy: 'updatedAt',  // Field to sort by
    sortOrder: 'desc',    // 'asc' or 'desc'
  });

  /**
   * Dialog Visibility States
   * Controls whether the create note dialog is open/closed.
   * Boolean state is perfect for simple show/hide logic.
   */
  const [createDialogOpen, setCreateDialogOpen] = useState(false);

  /**
   * Delete Confirmation State
   * Stores the ID of the note pending deletion (or null if no deletion pending).
   * We use this to show a confirmation dialog and know which note to delete.
   */
  const [deleteNoteId, setDeleteNoteId] = useState<string | null>(null);

  /**
   * New Note Form State
   * Stores the temporary form inputs while creating a new note.
   * Lives here (not in React Hook Form) for simplicity - this is a simple form.
   * Gets reset after successful creation.
   */
  const [newNote, setNewNote] = useState({ title: '', content: '', tags: '' });

  // ============================================================================
  // SERVER STATE MANAGEMENT (React Query)
  // ============================================================================
  // React Query manages server data: fetching, caching, refetching, mutations.
  // It automatically handles loading states, error states, and cache invalidation.
  
  /**
   * useInfiniteNotes Hook
   * 
   * Why React Query: We need to fetch paginated notes from the API, cache them,
   * and automatically refetch when they change (after create/delete/update).
   * 
   * How it works:
   * - Fetches notes from API in pages (infinite scroll pattern)
   * - Caches results so we don't re-fetch unnecessarily
   * - Provides loading states (isLoading, isFetchingNextPage)
   * - Returns a data structure with pages array
   * - Automatically refetches when cache is invalidated (by mutations)
   * 
   * Query Key: The 'filters' are part of the query key, so changing filters
   * creates a separate cache entry (we then filter client-side, but this allows
   * future server-side filtering without changing this code).
   */
  const { data, isLoading, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteNotes(filters);

  /**
   * useCreateNote Mutation
   * 
   * Mutations are React Query's way of handling write operations (POST/PUT/DELETE).
   * When you call createNote.mutateAsync(), it:
   * 1. Sends POST request to API
   * 2. Shows loading state via createNote.isPending
   * 3. Invalidates the notes cache on success (triggers refetch)
   * 4. Updates UI automatically when cache updates
   */
  const createNote = useCreateNote();

  /**
   * useDeleteNote Mutation
   * 
   * Similar to create, but sends DELETE request.
   * On success, removes the note from cache and UI updates automatically.
   */
  const deleteNote = useDeleteNote();

  // ============================================================================
  // DERIVED STATE & MEMOIZATION
  // ============================================================================
  // useMemo prevents expensive computations from re-running on every render.
  // Only use when computation is actually expensive or creates new object references.
  
  /**
   * Flatten Paginated Data
   * 
   * Why useMemo: React Query's infinite query returns data as pages:
   * { pages: [{ data: [...notes] }, { data: [...notes] }] }
   * 
   * We flatten this into a single array of notes. We memoize because:
   * 1. flatMap creates a new array on every call
   * 2. This new array would cause child components to re-render unnecessarily
   * 3. We only need to recompute when 'data' changes (new page fetched)
   * 
   * Dependencies: [data] - recompute only when React Query data changes
   */
  const allNotes = useMemo(() => data?.pages.flatMap(page => page.data) || [], [data]);

  /**
   * Client-Side Filtering & Sorting
   * 
   * Why Client-Side: The API currently returns all notes without filtering.
   * We apply search, tag filters, and sorting here in the browser.
   * 
   * Why useMemo: This is computationally expensive for large note lists:
   * - Lowercasing strings for search
   * - Filtering by multiple criteria
   * - Sorting entire array
   * 
   * Without memoization, this would run on EVERY render (typing, mouse move, etc).
   * With memoization, it only runs when allNotes or filters change.
   * 
   * Dependencies: [allNotes, filters] - recompute when notes or filters change
   * 
   * Future Enhancement: Move this to the API (server-side filtering) for better
   * performance with large datasets. This would just pass filters to useInfiniteNotes.
   */
  const filteredNotes = useMemo(() => {
    // Normalize search term: trim whitespace, lowercase for case-insensitive search
    const searchTerm = filters.search?.trim().toLowerCase() || '';
    const tagFilters = filters.tags ?? [];

    /**
     * Search Matching Logic
     * Checks if note title OR content contains the search term.
     * If no search term, all notes match.
     */
    const matchesSearch = (note: typeof allNotes[number]) =>
      !searchTerm ||
      note.title.toLowerCase().includes(searchTerm) ||
      note.content.toLowerCase().includes(searchTerm);

    /**
     * Tag Filtering Logic
     * If no tag filters selected, all notes match.
     * Otherwise, note must have at least one of the selected tags.
     */
    const matchesTags = (note: typeof allNotes[number]) =>
      tagFilters.length === 0 || tagFilters.some(tag => note.tags.includes(tag));

    /**
     * Filter + Sort Pipeline
     * 1. Create a copy of allNotes (don't mutate original)
     * 2. Filter by search AND tags
     * 3. Sort by the selected field and order
     */
    const sorted = [...allNotes]
      .filter((note) => matchesSearch(note) && matchesTags(note))
      .sort((a, b) => {
        const sortBy = filters.sortBy || 'updatedAt';
        const sortOrder = filters.sortOrder || 'desc';

        // Get the values to compare (could be strings or dates)
        const aVal = a[sortBy];
        const bVal = b[sortBy];
        
        // Handle equal values
        if (aVal === bVal) return 0;
        
        // Determine sort direction: -1 means a comes first, 1 means b comes first
        const cmp = aVal < bVal ? -1 : 1;
        
        // Reverse the comparison for descending order
        return sortOrder === 'asc' ? cmp : -cmp;
      });

    return sorted;
  }, [allNotes, filters]);

  // ============================================================================
  // EVENT HANDLERS
  // ============================================================================
  // These functions handle user interactions. They're defined here (not inline)
  // for readability and because they contain multi-step logic.
  
  /**
   * Handle Create Note
   * 
   * Flow:
   * 1. Validate: Ensure title is not empty
   * 2. Call React Query mutation with note data
   * 3. Parse tags: Convert comma-separated string to array
   * 4. On success: Reset form and close dialog
   * 5. React Query automatically invalidates cache and refetches notes
   * 
   * Why async/await: mutateAsync returns a Promise that resolves when the API
   * call completes. We await it so we only reset form after successful creation.
   */
  const handleCreateNote = async () => {
    // Validation: title is required
    if (!newNote.title.trim()) return;

    // Mutate: Send POST request to API via React Query
    await createNote.mutateAsync({
      title: newNote.title,
      content: newNote.content,
      // Parse tags: "work, personal" → ["work", "personal"]
      // - split by comma
      // - trim whitespace from each tag
      // - filter out empty strings
      tags: newNote.tags.split(',').map(t => t.trim()).filter(Boolean),
    });

    // Reset form state to initial empty values
    setNewNote({ title: '', content: '', tags: '' });
    
    // Close the dialog - note list will automatically update via React Query
    setCreateDialogOpen(false);
  };

  /**
   * Handle Delete Note
   * 
   * Flow:
   * 1. Guard: Ensure we have a note ID to delete
   * 2. Call React Query mutation to DELETE from API
   * 3. On success: Close confirmation dialog
   * 4. React Query automatically removes note from cache and UI updates
   * 
   * Why async/await: We wait for deletion to complete before closing dialog.
   */
  const handleDeleteNote = async () => {
    // Guard: if no note selected for deletion, do nothing
    if (!deleteNoteId) return;
    
    // Mutate: Send DELETE request to API
    await deleteNote.mutateAsync(deleteNoteId);
    
    // Close confirmation dialog (null = no note pending deletion)
    setDeleteNoteId(null);
  };

  /**
   * Handle Note Click - Navigate to Detail Page
   * 
   * Why this approach: We're using client-side routing without a router library.
   * This manually updates the browser URL and triggers a navigation event.
   * 
   * How it works:
   * 1. pushState: Change URL without page reload
   * 2. dispatchEvent: Trigger 'popstate' event so app router detects navigation
   * 
   * Note: In a production app, use React Router or similar for cleaner routing.
   */
  const handleNoteClick = (noteId: string) => {
    // Update browser URL to /notes/:id
    window.history.pushState({}, '', `/notes/${noteId}`);
    
    // Dispatch event to notify app router of navigation
    window.dispatchEvent(new PopStateEvent('popstate'));
  };

  // ============================================================================
  // RENDER (JSX)
  // ============================================================================
  
  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* 
        Tailwind Classes Explained:
        - max-w-7xl: Maximum width of 80rem (1280px) for readable content
        - mx-auto: Horizontally center the container
        - space-y-6: Add 1.5rem vertical spacing between child elements
      */}
      
      {/* ============================================================
          HEADER SECTION
          Shows page title, note count, and create button
          ============================================================ */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        {/*
          Responsive Layout:
          - Mobile: Stacked vertically (flex-col) with 1rem gap
          - Desktop (sm+): Horizontal row with space-between
          
          Why flex-col then sm:flex-row: Mobile-first responsive design.
          Start with mobile layout, then override for larger screens.
        */}
        <div>
          <h1 className="text-3xl mb-1">My Notes</h1>
          <p className="text-muted-foreground">
            {filteredNotes.length} {filteredNotes.length === 1 ? 'note' : 'notes'}
          </p>
        </div>
        <Button size="lg" onClick={() => setCreateDialogOpen(true)}>
          <Plus className="mr-2 h-5 w-5" />
          New Note
        </Button>
      </div>

      {/* Search and Filters */}
      <div className="flex flex-col gap-3 sm:flex-row">
        <div className="relative flex-1">
          {/*
            Search Input with Icon
            Why relative: Allows absolute positioning of icon inside input
            Why flex-1: Takes remaining horizontal space (filter button gets fixed width)
          */}
          
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          {/*
            Icon Positioning Explained:
            - absolute: Remove from document flow
            - left-3: 0.75rem from left edge
            - top-1/2: 50% from top
            - -translate-y-1/2: Shift up by 50% of own height (perfect vertical center)
            - text-muted-foreground: Subtle color from theme
          */}
          
          <Input
            placeholder="Search notes..."
            value={filters.search}
            onChange={(e) => setFilters(f => ({ ...f, search: e.target.value }))}
            className="pl-9"
          />
          {/*
            Controlled Input Pattern:
            - value={filters.search}: React controls the value (single source of truth)
            - onChange: Update state on every keystroke
            - setFilters(f => ({...f, search: ...})): Spread syntax to update one property
            
            Why pl-9: Padding-left 2.25rem to make room for search icon
            
            Why Controlled: Allows us to:
            - Clear input programmatically
            - Validate input
            - Synchronize with other state (filters object)
          */}
        </div>
        
        <Button variant="outline" size="icon">
          {/*
            Filter Button (Currently Placeholder)
            - variant="outline": Ghost style (defined in button.tsx)
            - size="icon": Square button for icon-only display
            
            Note: This doesn't do anything yet - placeholder for future filter UI
          */}
          <SlidersHorizontal className="h-4 w-4" />
        </Button>
      </div>

      {/* ============================================================
          NOTES DISPLAY SECTION
          Conditional rendering based on loading state and note count
          ============================================================ */}
      {isLoading ? (
        /*
          LOADING STATE
          Shows skeleton placeholders while initial data loads.
          Why skeletons: Better UX than spinners - shows content structure.
        */
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-48 rounded-lg" />
          ))}
        </div>
      ) : filteredNotes.length === 0 ? (
        <EmptyState onAction={() => setCreateDialogOpen(true)} />
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {/*
              Notes Grid - Same responsive layout as skeleton grid
              Each note gets its own card component
            */}
            
            {filteredNotes.map((note) => (
              <NoteCard
                key={note.id}
                note={note}
                onClick={() => handleNoteClick(note.id)}
                onDelete={() => setDeleteNoteId(note.id)}
              />
              /*
                NoteCard Component
                - key={note.id}: Required for React list rendering (helps with efficient updates)
                - note: Pass entire note object as prop
                - onClick: Navigate to detail page
                - onDelete: Open confirmation dialog with this note's ID
                
                Why separate component: 
                - Encapsulates card layout and styling
                - Reusable in other contexts
                - Easier to test in isolation
              */
            ))}
          </div>

          {/* ============================================================
              INFINITE SCROLL - LOAD MORE
              Shows button to fetch next page of notes
              ============================================================ */}
          {hasNextPage && (
            /*
              Conditional Render: Only show if more pages exist
              hasNextPage comes from React Query - it checks if API returned nextToken
            */
            <div className="flex justify-center pt-4">
              <Button
                variant="outline"
                onClick={() => fetchNextPage()}
                disabled={isFetchingNextPage}
              >
                {isFetchingNextPage ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Loading...
                  </>
                ) : (
                  'Load More'
                )}
              </Button>
            </div>
          )}
        </>
      )}

      {/* Create Note Dialog */}
      <Dialog open={createDialogOpen} onOpenChange={setCreateDialogOpen}>
        <DialogContent>
          {/* Dialog content - styled container for form */}
          
          <DialogHeader>
            {/* Semantic header section with title and description */}
            <DialogTitle>Create New Note</DialogTitle>
            <DialogDescription>
              Add a new note to your collection
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            {/*
              Form Fields Container
              - space-y-4: Vertical spacing between fields
              - py-4: Padding top and bottom for visual breathing room
            */}
            
            <div className="space-y-2">
              {/* Title Field - Required */}
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                value={newNote.title}
                onChange={(e) => setNewNote(n => ({ ...n, title: e.target.value }))}
                placeholder="Enter note title..."
                autoFocus
              />
              {/*
                Controlled Input Pattern:
                - value: Bound to newNote.title state
                - onChange: Updates only title property, spreads rest of object
                - setNewNote(n => ({...n, title: ...})): Function form of setState
                  ensures we get the latest state even if updates are batched
                - autoFocus: Cursor starts here when dialog opens (UX convenience)
              */}
            </div>
            
            <div className="space-y-2">
              {/* Content Field - Optional */}
              <Label htmlFor="content">Content</Label>
              <Textarea
                id="content"
                value={newNote.content}
                onChange={(e) => setNewNote(n => ({ ...n, content: e.target.value }))}
                placeholder="Write your note..."
                rows={6}
              />
              {/*
                Textarea for Multi-line Content
                - rows={6}: Initial height (approximately 6 lines of text)
                - Same controlled pattern as title input
                - User can resize vertically (browser default behavior)
              */}
            </div>
            
            <div className="space-y-2">
              {/* Tags Field - Comma-separated string */}
              <Label htmlFor="tags">Tags (comma-separated)</Label>
              <Input
                id="tags"
                value={newNote.tags}
                onChange={(e) => setNewNote(n => ({ ...n, tags: e.target.value }))}
                placeholder="work, personal, ideas..."
              />
              {/*
                Simple Tag Input
                Alternative approach: Could use a fancy tag picker component,
                but comma-separated string is simpler and more predictable.
                We parse it into array in handleCreateNote.
              */}
            </div>
          </div>
          
          <DialogFooter>
            {/* Footer with action buttons */}
            <Button variant="outline" onClick={() => setCreateDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              onClick={handleCreateNote}
              disabled={!newNote.title.trim() || createNote.isPending}
            >
              {createNote.isPending ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Creating...
                </>
              ) : (
                'Create Note'
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={!!deleteNoteId} onOpenChange={() => setDeleteNoteId(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Note</AlertDialogTitle>
            <AlertDialogDescription>
              {/*
                Clear Warning Message
                Explains what will happen and that it's permanent.
                Important for destructive actions to be explicit.
              */}
              Are you sure you want to delete this note? This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          
          <AlertDialogFooter>
            {/* Action buttons - typically Cancel + Destructive action */}
            
            <AlertDialogCancel>
              {/*
                Cancel Button
                Radix automatically wires this to close the dialog.
                Sets deleteNoteId back to null via onOpenChange.
              */}
              Cancel
            </AlertDialogCancel>
            
            <AlertDialogAction
              onClick={handleDeleteNote}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              {/*
                Delete Button (Destructive Action)
                - onClick: Performs the actual deletion
                - Custom Tailwind classes for destructive styling:
                  - bg-destructive: Red background (defined in theme)
                  - text-destructive-foreground: White text (contrast)
                  - hover:bg-destructive/90: Slightly darker red on hover
                  
                Why custom classes: Override default AlertDialogAction styling
                to clearly indicate this is a destructive, irreversible action.
                Red is universally understood as "danger/delete".
              */}
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}

/*
  ============================================================================
  KEY LEARNINGS FROM THIS COMPONENT
  ============================================================================
  
  1. State Management Strategy:
     - Local state (useState) for UI concerns: dialogs, filters, form inputs
     - Server state (React Query) for API data: fetching, caching, mutations
     - Never mix the two - clear separation of concerns
  
  2. Performance Optimization:
     - useMemo for expensive computations (filtering, sorting large lists)
     - Only optimize when there's actual cost (don't over-optimize)
     - Dependencies array is critical - must include all used values
  
  3. React Query Pattern:
     - Queries: Read operations (useInfiniteNotes)
     - Mutations: Write operations (useCreateNote, useDeleteNote)
     - Automatic cache invalidation keeps UI in sync
     - Loading states come for free
  
  4. Conditional Rendering:
     - Show loading skeletons during initial load
     - Show empty state when no data
     - Show success state with data
     - Always consider all states: loading, error, empty, success
  
  5. Form Patterns:
     - Controlled inputs for predictable state management
     - Function form of setState when updating object properties
     - Validation before submission
     - Reset form after successful submission
  
  6. Radix UI Pattern:
     - Provides behavior (accessibility, keyboard nav, focus management)
     - We provide styling with Tailwind
     - Best of both worlds: accessible + customizable
  
  7. Responsive Design:
     - Mobile-first: Default to mobile layout
     - Progressive enhancement: Add complexity for larger screens
     - Grid for layout: CSS Grid handles responsive reflow automatically
  
  Next Steps to Learn:
  - How React Query caching works (see useNotes.ts)
  - How Radix Dialog provides accessibility (check DOM with devtools)
  - How to add server-side filtering (modify API + pass filters to hook)
  - How to add proper routing (React Router instead of pushState hack)
*/
