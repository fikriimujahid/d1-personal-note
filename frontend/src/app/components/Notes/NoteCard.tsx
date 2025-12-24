import React from 'react';
import { Clock, Tag as TagIcon, Trash2, Edit } from 'lucide-react';
import { Card, CardHeader, CardContent, CardFooter } from '../ui/card';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import type { Note } from '../../../types';
import { formatDistanceToNow } from 'date-fns';
import { motion } from 'motion/react';

interface NoteCardProps {
  note: Note;
  onClick?: () => void;
  onDelete?: () => void;
  onEdit?: () => void;
}

export function NoteCard({ note, onClick, onDelete, onEdit }: NoteCardProps) {
  const timeAgo = formatDistanceToNow(new Date(note.updatedAt), { addSuffix: true });

  const truncateContent = (content: string, maxLength: number = 150) => {
    if (content.length <= maxLength) return content;
    return content.slice(0, maxLength) + '...';
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ duration: 0.2 }}
    >
      <Card 
        className="group cursor-pointer transition-all hover:shadow-md hover:border-primary/50"
        onClick={onClick}
      >
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between gap-2">
            <h3 className="text-lg line-clamp-2 group-hover:text-primary transition-colors">
              {note.title}
            </h3>
            <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8"
                onClick={(e) => {
                  e.stopPropagation();
                  onEdit?.();
                }}
                aria-label="Edit note"
              >
                <Edit className="h-4 w-4" />
              </Button>
              <Button
                variant="ghost"
                size="icon"
                className="h-8 w-8 text-destructive hover:text-destructive"
                onClick={(e) => {
                  e.stopPropagation();
                  onDelete?.();
                }}
                aria-label="Delete note"
              >
                <Trash2 className="h-4 w-4" />
              </Button>
            </div>
          </div>
        </CardHeader>

        <CardContent className="pb-3">
          <p className="text-sm text-muted-foreground line-clamp-3">
            {truncateContent(note.content)}
          </p>
        </CardContent>

        <CardFooter className="flex items-center justify-between flex-wrap gap-2 pt-3 border-t">
          <div className="flex items-center gap-1 text-xs text-muted-foreground">
            <Clock className="h-3 w-3" />
            <span>{timeAgo}</span>
          </div>

          {note.tags.length > 0 && (
            <div className="flex items-center gap-1 flex-wrap">
              <TagIcon className="h-3 w-3 text-muted-foreground" />
              {note.tags.slice(0, 3).map((tag) => (
                <Badge
                  key={tag}
                  variant="secondary"
                  className="text-xs"
                  onClick={(e) => e.stopPropagation()}
                >
                  {tag}
                </Badge>
              ))}
              {note.tags.length > 3 && (
                <Badge variant="secondary" className="text-xs">
                  +{note.tags.length - 3}
                </Badge>
              )}
            </div>
          )}
        </CardFooter>
      </Card>
    </motion.div>
  );
}
