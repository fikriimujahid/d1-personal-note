import { useQuery, useMutation, useQueryClient, useInfiniteQuery } from '@tanstack/react-query';
import { notesApi } from '../services/notes-api';
import type { Note, CreateNoteInput, UpdateNoteInput, NotesFilters } from '../types';
import { toast } from 'sonner';

// Query keys
export const noteKeys = {
  all: ['notes'] as const,
  lists: () => [...noteKeys.all, 'list'] as const,
  list: (filters?: NotesFilters) => [...noteKeys.lists(), filters] as const,
  details: () => [...noteKeys.all, 'detail'] as const,
  detail: (id: string) => [...noteKeys.details(), id] as const,
  tags: () => [...noteKeys.all, 'tags'] as const,
};

// Get all notes (with pagination)
export function useNotes(page: number = 1, limit: number = 10, filters?: NotesFilters) {
  // Backend uses cursor (nextToken) pagination; here we fetch the first page only
  return useQuery({
    queryKey: noteKeys.list({ ...filters, page, limit } as any),
    queryFn: () => notesApi.getNotes(undefined, limit),
    staleTime: 30000, // 30 seconds
  });
}

// Get notes with infinite scroll
export function useInfiniteNotes(filters?: NotesFilters) {
  return useInfiniteQuery({
    queryKey: noteKeys.list(filters),
    queryFn: ({ pageParam }: { pageParam?: string }) => notesApi.getNotes(pageParam, 10),
    getNextPageParam: (lastPage) => lastPage.nextToken ?? undefined,
    initialPageParam: undefined,
    staleTime: 30000,
  });
}

// Get single note
export function useNote(id: string) {
  return useQuery({
    queryKey: noteKeys.detail(id),
    queryFn: () => notesApi.getNote(id),
    enabled: !!id,
    staleTime: 60000, // 1 minute
  });
}

// Get all tags
export function useTags() {
  return useQuery({
    queryKey: noteKeys.tags(),
    queryFn: () => notesApi.getAllTags(),
    staleTime: 300000, // 5 minutes
  });
}

// Create note mutation
export function useCreateNote() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (input: CreateNoteInput) => notesApi.createNote(input),
    onSuccess: (newNote) => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      queryClient.invalidateQueries({ queryKey: noteKeys.tags() });
      toast.success('Note created successfully!');
    },
    onError: (error: Error) => {
      toast.error(error.message || 'Failed to create note');
    },
  });
}

// Update note mutation
export function useUpdateNote() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: ({ id, input }: { id: string; input: UpdateNoteInput }) =>
      notesApi.updateNote(id, input),
    onMutate: async ({ id, input }) => {
      // Cancel outgoing queries
      await queryClient.cancelQueries({ queryKey: noteKeys.detail(id) });
      
      // Snapshot previous value
      const previousNote = queryClient.getQueryData<Note>(noteKeys.detail(id));
      
      // Optimistically update
      if (previousNote) {
        queryClient.setQueryData<Note>(noteKeys.detail(id), {
          ...previousNote,
          ...input,
          updatedAt: new Date().toISOString(),
        });
      }
      
      return { previousNote };
    },
    onError: (error: Error, { id }, context) => {
      // Rollback on error
      if (context?.previousNote) {
        queryClient.setQueryData(noteKeys.detail(id), context.previousNote);
      }
      toast.error(error.message || 'Failed to update note');
    },
    onSuccess: (updatedNote) => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      queryClient.invalidateQueries({ queryKey: noteKeys.tags() });
    },
  });
}

// Delete note mutation
export function useDeleteNote() {
  const queryClient = useQueryClient();
  
  return useMutation({
    mutationFn: (id: string) => notesApi.deleteNote(id),
    onSuccess: (_, id) => {
      queryClient.invalidateQueries({ queryKey: noteKeys.lists() });
      queryClient.invalidateQueries({ queryKey: noteKeys.tags() });
      queryClient.removeQueries({ queryKey: noteKeys.detail(id) });
      toast.success('Note deleted successfully');
    },
    onError: (error: Error) => {
      toast.error(error.message || 'Failed to delete note');
    },
  });
}

// Autosave hook with debouncing
export function useAutosave(noteId: string, debounceMs: number = 1000) {
  const updateNote = useUpdateNote();
  let timeoutId: NodeJS.Timeout;
  
  const autosave = (input: UpdateNoteInput) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => {
      updateNote.mutate({ id: noteId, input });
    }, debounceMs);
  };
  
  return { autosave, isAutosaving: updateNote.isPending };
}
