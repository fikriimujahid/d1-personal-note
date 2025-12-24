import React, { useState, useEffect, useCallback } from 'react';
import { ArrowLeft, Save, Trash2, Tag as TagIcon, Clock, MoreHorizontal, X } from 'lucide-react';
import { useNote, useUpdateNote, useDeleteNote, useTags } from '../../hooks/useNotes';
import { Button } from '../components/ui/button';
import { Input } from '../components/ui/input';
import { Textarea } from '../components/ui/textarea';
import { Badge } from '../components/ui/badge';
import { Skeleton } from '../components/ui/skeleton';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '../components/ui/alert-dialog';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../components/ui/card';
import { Breadcrumb, BreadcrumbList, BreadcrumbItem, BreadcrumbLink, BreadcrumbSeparator, BreadcrumbPage } from '../components/ui/breadcrumb';
import { DropdownMenu, DropdownMenuTrigger, DropdownMenuContent, DropdownMenuItem, DropdownMenuSeparator } from '../components/ui/dropdown-menu';
import { Popover, PopoverTrigger, PopoverContent } from '../components/ui/popover';
import { Command, CommandInput, CommandList, CommandEmpty, CommandGroup, CommandItem } from '../components/ui/command';
import { formatDistanceToNow } from 'date-fns';
import { toast } from 'sonner';

interface NoteDetailPageProps {
  noteId?: string | null;
}

export function NoteDetailPage({ noteId }: NoteDetailPageProps) {
  const { data: note, isLoading } = useNote(noteId || '');
  const updateNote = useUpdateNote();
  const deleteNote = useDeleteNote();
  const { data: availableTags = [] } = useTags();

  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [tags, setTags] = useState('');
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [unsavedDialogOpen, setUnsavedDialogOpen] = useState(false);
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false);
  const [lastSaved, setLastSaved] = useState<Date | null>(null);
  const [tagPickerOpen, setTagPickerOpen] = useState(false);

  useEffect(() => {
    if (note) {
      setTitle(note.title);
      setContent(note.content);
      setTags(note.tags.join(', '));
      setLastSaved(new Date(note.updatedAt));
      setHasUnsavedChanges(false);
    }
  }, [note]);

  const handleSave = useCallback(async () => {
    if (!noteId || !note) return;

    try {
      await updateNote.mutateAsync({
        id: noteId,
        input: {
          title,
          content,
          tags: tags.split(',').map(t => t.trim()).filter(Boolean),
        },
      });
      setLastSaved(new Date());
      setHasUnsavedChanges(false);
    } catch (error) {
      toast.error('Failed to save note');
    }
  }, [noteId, note, title, content, tags, updateNote]);

  // Autosave effect
  useEffect(() => {
    if (!note || !hasUnsavedChanges) return;

    const timeoutId = setTimeout(() => {
      handleSave();
    }, 2000); // Autosave after 2 seconds of inactivity

    return () => clearTimeout(timeoutId);
  }, [note, hasUnsavedChanges, handleSave]);

  const handleDelete = async () => {
    if (!noteId) return;
    
    await deleteNote.mutateAsync(noteId);
    setDeleteDialogOpen(false);
    
    // Navigate back
    window.history.pushState({}, '', '/notes');
    window.dispatchEvent(new PopStateEvent('popstate'));
  };

  const navigateBack = () => {
    window.history.pushState({}, '', '/notes');
    window.dispatchEvent(new PopStateEvent('popstate'));
  };

  const handleBack = () => {
    if (hasUnsavedChanges) {
      setUnsavedDialogOpen(true);
    } else {
      navigateBack();
    }
  };

  if (isLoading) {
    return (
      <div className="max-w-4xl mx-auto space-y-6">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-96 w-full" />
      </div>
    );
  }

  if (!note) {
    return (
      <div className="max-w-4xl mx-auto text-center py-12">
        <h2 className="text-2xl mb-2">Note not found</h2>
        <p className="text-muted-foreground mb-4">
          The note you're looking for doesn't exist or has been deleted.
        </p>
        <Button onClick={handleBack}>
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to Notes
        </Button>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* Breadcrumb */}
      <Breadcrumb>
        <BreadcrumbList>
          <BreadcrumbItem>
            <BreadcrumbLink onClick={handleBack} href="#">Notes</BreadcrumbLink>
          </BreadcrumbItem>
          <BreadcrumbSeparator />
          <BreadcrumbItem>
            <BreadcrumbPage>{title || 'Untitled Note'}</BreadcrumbPage>
          </BreadcrumbItem>
        </BreadcrumbList>
      </Breadcrumb>

      {/* Header actions */}
      <div className="flex items-center justify-between gap-4">
        <Button variant="ghost" size="sm" onClick={handleBack}>
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back
        </Button>
        <div className="flex items-center gap-2">
          {updateNote.isPending && (
            <span className="text-sm text-muted-foreground">Saving...</span>
          )}
          {!updateNote.isPending && lastSaved && (
            <span className="text-sm text-muted-foreground flex items-center gap-1">
              <Clock className="h-3 w-3" />
              Saved {formatDistanceToNow(lastSaved, { addSuffix: true })}
            </span>
          )}

          <Button
            variant="outline"
            size="sm"
            onClick={handleSave}
            disabled={!hasUnsavedChanges || updateNote.isPending}
          >
            <Save className="mr-2 h-4 w-4" />
            Save
          </Button>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="icon" aria-label="More actions">
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={() => setDeleteDialogOpen(true)} className="text-destructive">
                <Trash2 className="h-4 w-4" /> Delete note
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={navigateBack}>
                <ArrowLeft className="h-4 w-4" /> Back to list
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      {/* Editor Card */}
      <Card>
        <CardHeader className="border-b">
          <CardTitle>
            <Input
              value={title}
              onChange={(e) => {
                setTitle(e.target.value);
                setHasUnsavedChanges(true);
              }}
              placeholder="Untitled note"
            />
          </CardTitle>
          <CardDescription>
            {lastSaved ? (
              <span className="text-sm text-muted-foreground flex items-center gap-1">
                <Clock className="h-3 w-3" />
                Updated {formatDistanceToNow(lastSaved, { addSuffix: true })}
              </span>
            ) : null}
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Tags */}
          <div className="flex items-center gap-2">
            <TagIcon className="h-4 w-4 text-muted-foreground" />
            <div className="flex flex-wrap gap-2">
              {tags
                .split(',')
                .map((t) => t.trim())
                .filter(Boolean)
                .map((tag, i) => (
                  <Badge key={`${tag}-${i}`} variant="secondary" className="flex items-center gap-1">
                    {tag}
                    <X
                      className="h-3 w-3 cursor-pointer"
                      onClick={() => {
                        const current = tags
                          .split(',')
                          .map((tt) => tt.trim())
                          .filter(Boolean)
                          .filter((tt) => tt !== tag);
                        setTags(current.join(', '));
                        setHasUnsavedChanges(true);
                      }}
                    />
                  </Badge>
                ))}
            </div>
            <Popover open={tagPickerOpen} onOpenChange={setTagPickerOpen}>
              <PopoverTrigger asChild>
                <Button variant="outline" size="sm">Add tag</Button>
              </PopoverTrigger>
              <PopoverContent className="p-0 w-64">
                <Command>
                  <CommandInput placeholder="Search tags..." />
                  <CommandList>
                    <CommandEmpty>No tags found.</CommandEmpty>
                    <CommandGroup heading="Available tags">
                      {availableTags.map((t) => (
                        <CommandItem
                          key={t}
                          onSelect={() => {
                            const setArr = new Set(
                              tags
                                .split(',')
                                .map((tt) => tt.trim())
                                .filter(Boolean)
                            );
                            setArr.add(t);
                            setTags(Array.from(setArr).join(', '));
                            setHasUnsavedChanges(true);
                            setTagPickerOpen(false);
                          }}
                        >
                          {t}
                        </CommandItem>
                      ))}
                    </CommandGroup>
                  </CommandList>
                </Command>
              </PopoverContent>
            </Popover>
          </div>

          {/* Content */}
          <Textarea
            value={content}
            onChange={(e) => {
              setContent(e.target.value);
              setHasUnsavedChanges(true);
            }}
            placeholder="Start writing..."
            className="min-h-[500px]"
          />
        </CardContent>
      </Card>

      {/* Delete Confirmation Dialog */}
      <AlertDialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Delete Note</AlertDialogTitle>
            <AlertDialogDescription>
              Are you sure you want to delete "{note.title}"? This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Cancel</AlertDialogCancel>
            <AlertDialogAction
              onClick={handleDelete}
              className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
            >
              Delete
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      {/* Unsaved Changes Confirmation Dialog */}
      <AlertDialog open={unsavedDialogOpen} onOpenChange={setUnsavedDialogOpen}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Unsaved Changes</AlertDialogTitle>
            <AlertDialogDescription>
              You have unsaved changes. Do you really want to leave?
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Stay</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                setUnsavedDialogOpen(false);
                navigateBack();
              }}
            >
              Leave without saving
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
  );
}
