import React from 'react';
import { FileText, Plus } from 'lucide-react';
import { Button } from '../ui/button';
import { motion } from 'motion/react';

interface EmptyStateProps {
  title?: string;
  description?: string;
  actionLabel?: string;
  onAction?: () => void;
}

export function EmptyState({
  title = 'No notes yet',
  description = 'Create your first note to get started',
  actionLabel = 'Create Note',
  onAction,
}: EmptyStateProps) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="flex flex-col items-center justify-center p-8 md:p-12 text-center"
    >
      <div className="rounded-full bg-muted p-6 mb-4">
        <FileText className="h-12 w-12 text-muted-foreground" />
      </div>
      <h3 className="text-2xl mb-2">{title}</h3>
      <p className="text-muted-foreground mb-6 max-w-sm">
        {description}
      </p>
      {onAction && (
        <Button onClick={onAction} size="lg">
          <Plus className="mr-2 h-5 w-5" />
          {actionLabel}
        </Button>
      )}
    </motion.div>
  );
}
