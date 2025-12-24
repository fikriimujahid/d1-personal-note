import React, { useMemo, useState } from 'react';
import { Plus, Search, SlidersHorizontal, Loader2 } from 'lucide-react';
import { useInfiniteNotes, useDeleteNote } from '../../hooks/useNotes';
import { NoteCard } from '../components/Notes/NoteCard';
import { EmptyState } from '../components/Notes/EmptyState';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '../components/ui/dialog';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '../components/ui/alert-dialog';
import { Skeleton } from '../components/ui/skeleton';
import { Label } from '../components/ui/label';
import { Textarea } from '../components/ui/textarea';
import { useCreateNote } from '../../hooks/useNotes';
import type { NotesFilters } from '../../types';

export function NotesPage() {
  const [filters, setFilters] = useState<NotesFilters>({
    search: '',
    tags: [],
    sortBy: 'updatedAt',
    sortOrder: 'desc',
  });
  const [createDialogOpen, setCreateDialogOpen] = useState(false);
  const [deleteNoteId, setDeleteNoteId] = useState<string | null>(null);
  const [newNote, setNewNote] = useState({ title: '', content: '', tags: '' });

  const { data, isLoading, fetchNextPage, hasNextPage, isFetchingNextPage } = useInfiniteNotes(filters);
  const createNote = useCreateNote();
  const deleteNote = useDeleteNote();

  const allNotes = useMemo(() => data?.pages.flatMap(page => page.data) || [], [data]);

  // Apply client-side filters/sort since the API currently returns unfiltered pages
  const filteredNotes = useMemo(() => {
    const searchTerm = filters.search?.trim().toLowerCase() || '';
    const tagFilters = filters.tags ?? [];

    const matchesSearch = (note: typeof allNotes[number]) =>
      !searchTerm ||
      note.title.toLowerCase().includes(searchTerm) ||
      note.content.toLowerCase().includes(searchTerm);

    const matchesTags = (note: typeof allNotes[number]) =>
      tagFilters.length === 0 || tagFilters.some(tag => note.tags.includes(tag));

    const sorted = [...allNotes]
      .filter((note) => matchesSearch(note) && matchesTags(note))
      .sort((a, b) => {
        const sortBy = filters.sortBy || 'updatedAt';
        const sortOrder = filters.sortOrder || 'desc';

        const aVal = a[sortBy];
        const bVal = b[sortBy];
        if (aVal === bVal) return 0;
        const cmp = aVal < bVal ? -1 : 1;
        return sortOrder === 'asc' ? cmp : -cmp;
      });

    return sorted;
  }, [allNotes, filters]);

  const handleCreateNote = async () => {
    if (!newNote.title.trim()) return;

    await createNote.mutateAsync({
      title: newNote.title,
      content: newNote.content,
      tags: newNote.tags.split(',').map(t => t.trim()).filter(Boolean),
    });

    setNewNote({ title: '', content: '', tags: '' });
    setCreateDialogOpen(false);
  };

  const handleDeleteNote = async () => {
    if (!deleteNoteId) return;
    await deleteNote.mutateAsync(deleteNoteId);
    setDeleteNoteId(null);
  };

  const handleNoteClick = (noteId: string) => {
    window.history.pushState({}, '', `/notes/${noteId}`);
    window.dispatchEvent(new PopStateEvent('popstate'));
  };

  return (
    <div className="max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
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
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            placeholder="Search notes..."
            value={filters.search}
            onChange={(e) => setFilters(f => ({ ...f, search: e.target.value }))}
            className="pl-9"
          />
        </div>
        <Button variant="outline" size="icon">
          <SlidersHorizontal className="h-4 w-4" />
        </Button>
      </div>

      {/* Notes Grid */}
      {isLoading ? (
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
            {filteredNotes.map((note) => (
              <NoteCard
                key={note.id}
                note={note}
                onClick={() => handleNoteClick(note.id)}
                onDelete={() => setDeleteNoteId(note.id)}
              />
            ))}
          </div>

          {/* Load More */}
          {hasNextPage && (
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
          <DialogHeader>
            <DialogTitle>Create New Note</DialogTitle>
            <DialogDescription>
              Add a new note to your collection
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="title">Title</Label>
              <Input
                id="title"
                value={newNote.title}
                onChange={(e) => setNewNote(n => ({ ...n, title: e.target.value }))}
                placeholder="Enter note title..."
                autoFocus
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="content">Content</Label>
              <Textarea
                id="content"
                value={newNote.content}
                onChange={(e) => setNewNote(n => ({ ...n, content: e.target.value }))}
                placeholder="Write your note..."
                rows={6}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="tags">Tags (comma-separated)</Label>
              <Input
                id="tags"
                value={newNote.tags}
                onChange={(e) => setNewNote(n => ({ ...n, tags: e.target.value }))}
                placeholder="work, personal, ideas..."
              />
            </div>
          </div>
          <DialogFooter>
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
              Are you sure you want to delete this note? This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDeleteNote}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
