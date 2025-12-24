import client from './api-client';
import type { Note } from '../types';
import type { CreateNoteRequest, UpdateNoteRequest } from '../types/note';

// Shape returned by the backend list endpoint
type ListNotesResponse = {
  items: Note[];
  nextToken?: string;
};

type PaginatedNotes = {
  data: Note[];
  nextToken?: string;
  hasMore: boolean;
  page: number;
  limit: number;
  total: number;
};

export const notesApi = {
  // Cursor-based pagination using nextToken from the backend
  getNotes: async (cursor?: string, limit: number = 10): Promise<PaginatedNotes> => {
    const params: Record<string, string | number> = { limit };
    if (cursor) params.nextToken = cursor;

    const response = await client.get<ListNotesResponse>('/notes', { params });
    const items = response.data.items ?? [];
    const nextToken = response.data.nextToken;

    return {
      data: items,
      nextToken,
      hasMore: Boolean(nextToken),
      page: cursor ? 2 : 1, // page number is approximate; consumers should rely on nextToken/hasMore
      limit,
      total: items.length,
    };
  },

  listNotes: async (): Promise<Note[]> => {
    const response = await client.get<{ items: Note[]; nextToken?: string }>('/notes');
    return response.data.items;
  },

  getNote: async (id: string): Promise<Note> => {
    const response = await client.get<Note>(`/notes/${id}`);
    return response.data;
  },

  createNote: async (payload: CreateNoteRequest): Promise<Note> => {
    const response = await client.post<Note>('/notes', payload);
    return response.data;
  },

  updateNote: async (id: string, payload: UpdateNoteRequest): Promise<Note> => {
    const response = await client.put<Note>(`/notes/${id}`, payload);
    return response.data;
  },

  deleteNote: async (id: string): Promise<void> => {
    await client.delete(`/notes/${id}`);
  },
};