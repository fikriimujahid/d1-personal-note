import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import React from 'react';
import { useNotes, useNote, useCreateNote, useUpdateNote, useDeleteNote } from './useNotes';
import { notesApi } from '../services/notes-api';
import type { Note } from '../types';

vi.mock('../services/notes-api');
vi.mock('sonner');

const mockNote: Note = {
  id: '123',
  userId: 'user-1',
  title: 'Test Note',
  content: 'Test content',
  tags: [],
  createdAt: '2025-12-24T10:00:00Z',
  updatedAt: '2025-12-24T10:00:00Z',
};

const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false },
      mutations: { retry: false },
    },
  });

  const Wrapper = ({ children }: { children: React.ReactNode }) => {
    return React.createElement(QueryClientProvider, { client: queryClient }, children);
  };

  return Wrapper;
};

describe('useNotes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fetches notes successfully', async () => {
    const mockResponse = {
      data: [mockNote],
      nextToken: undefined,
      hasMore: false,
      page: 1,
      limit: 10,
      total: 1,
    };

    vi.mocked(notesApi.getNotes).mockResolvedValue(mockResponse);

    const { result } = renderHook(() => useNotes(1, 10), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toEqual(mockResponse);
    expect(notesApi.getNotes).toHaveBeenCalledWith(undefined, 10);
  });

  it('handles fetch error', async () => {
    vi.mocked(notesApi.getNotes).mockRejectedValue(new Error('Network error'));

    const { result } = renderHook(() => useNotes(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isError).toBe(true));

    expect(result.current.error).toBeDefined();
  });
});

describe('useNote', () => {
  it('fetches a single note', async () => {
    vi.mocked(notesApi.getNote).mockResolvedValue(mockNote);

    const { result } = renderHook(() => useNote('123'), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toEqual(mockNote);
    expect(notesApi.getNote).toHaveBeenCalledWith('123');
  });

  it('does not fetch when id is falsy', () => {
    const { result } = renderHook(() => useNote(''), {
      wrapper: createWrapper(),
    });

    // With enabled: !!id, the query won't run for empty string
    // So we just check it doesn't throw and status is pending
    expect(result.current.isPending).toBe(true);
  });
});

describe('useCreateNote', () => {
  it('creates a note successfully', async () => {
    const newNote = { title: 'New Note', content: 'New content' };
    vi.mocked(notesApi.createNote).mockResolvedValue(mockNote);

    const { result } = renderHook(() => useCreateNote(), {
      wrapper: createWrapper(),
    });

    result.current.mutate(newNote);

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(notesApi.createNote).toHaveBeenCalledWith(newNote);
  });

  it('handles create error', async () => {
    const newNote = { title: 'New Note', content: 'New content' };
    vi.mocked(notesApi.createNote).mockRejectedValue(new Error('Create failed'));

    const { result } = renderHook(() => useCreateNote(), {
      wrapper: createWrapper(),
    });

    result.current.mutate(newNote);

    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

describe('useUpdateNote', () => {
  it('updates a note successfully', async () => {
    const updates = { title: 'Updated Title' };
    const updatedNote = { ...mockNote, ...updates };
    vi.mocked(notesApi.updateNote).mockResolvedValue(updatedNote);

    const { result } = renderHook(() => useUpdateNote(), {
      wrapper: createWrapper(),
    });

    result.current.mutate({ id: '123', input: updates });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(notesApi.updateNote).toHaveBeenCalledWith('123', updates);
  });
});

describe('useDeleteNote', () => {
  it('deletes a note successfully', async () => {
    vi.mocked(notesApi.deleteNote).mockResolvedValue();

    const { result } = renderHook(() => useDeleteNote(), {
      wrapper: createWrapper(),
    });

    result.current.mutate('123');

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(notesApi.deleteNote).toHaveBeenCalledWith('123');
  });
});
