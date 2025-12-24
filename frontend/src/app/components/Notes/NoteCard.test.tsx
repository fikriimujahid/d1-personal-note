import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { NoteCard } from './NoteCard';
import type { Note } from '../../../types';

const mockNote: Note = {
  id: '123',
  userId: 'user-1',
  title: 'Test Note',
  content: 'This is a test note content',
  tags: ['test', 'demo'],
  createdAt: '2025-12-20T10:00:00Z',
  updatedAt: '2025-12-24T10:00:00Z',
};

describe('NoteCard', () => {
  it('renders note title and content', () => {
    render(<NoteCard note={mockNote} />);
    
    expect(screen.getByText('Test Note')).toBeInTheDocument();
    expect(screen.getByText('This is a test note content')).toBeInTheDocument();
  });

  it('truncates long content', () => {
    const longNote: Note = {
      ...mockNote,
      content: 'a'.repeat(200),
    };
    
    render(<NoteCard note={longNote} />);
    const content = screen.getByText(/a+\.\.\./);
    expect(content.textContent?.length).toBeLessThan(200);
  });

  it('calls onClick handler when card is clicked', () => {
    const onClick = vi.fn();
    render(<NoteCard note={mockNote} onClick={onClick} />);
    
    const card = screen.getByText('Test Note').closest('.group');
    fireEvent.click(card!);
    
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  it('calls onEdit handler when edit button is clicked', () => {
    const onEdit = vi.fn();
    render(<NoteCard note={mockNote} onEdit={onEdit} />);
    
    const editButton = screen.getByLabelText('Edit note');
    fireEvent.click(editButton);
    
    expect(onEdit).toHaveBeenCalledTimes(1);
  });

  it('calls onDelete handler when delete button is clicked', () => {
    const onDelete = vi.fn();
    render(<NoteCard note={mockNote} onDelete={onDelete} />);
    
    const deleteButton = screen.getByLabelText('Delete note');
    fireEvent.click(deleteButton);
    
    expect(onDelete).toHaveBeenCalledTimes(1);
  });

  it('displays relative time for updatedAt', () => {
    render(<NoteCard note={mockNote} />);
    
    // The date-fns formatDistanceToNow renders relative time
    // Since the test runs after the updatedAt date, it will show "in about..."
    expect(screen.getByText(/in about|ago/i)).toBeInTheDocument();
  });

  it('stops event propagation when clicking edit/delete buttons', () => {
    const onClick = vi.fn();
    const onEdit = vi.fn();
    
    render(<NoteCard note={mockNote} onClick={onClick} onEdit={onEdit} />);
    
    const editButton = screen.getByLabelText('Edit note');
    fireEvent.click(editButton);
    
    // onClick should not be called when edit button is clicked
    expect(onEdit).toHaveBeenCalledTimes(1);
    expect(onClick).not.toHaveBeenCalled();
  });
});
