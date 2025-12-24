import { describe, it, expect, vi, beforeEach } from 'vitest';
import { notesApi } from './notes-api';
import client from './api-client';
import type { Note } from '../types';

vi.mock('./api-client');

const mockNote: Note = {
  id: '123',
  userId: 'user-1',
  title: 'Test Note',
  content: 'Test content',
  tags: [],
  createdAt: '2025-12-24T10:00:00Z',
  updatedAt: '2025-12-24T10:00:00Z',
};

describe('notesApi', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('getNotes', () => {
    it('fetches notes with default limit', async () => {
      const mockResponse = {
        data: {
          items: [mockNote],
          nextToken: 'token123',
        },
      };
      
      vi.mocked(client.get).mockResolvedValue(mockResponse);

      const result = await notesApi.getNotes();

      expect(client.get).toHaveBeenCalledWith('/notes', { params: { limit: 10 } });
      expect(result.data).toEqual([mockNote]);
      expect(result.hasMore).toBe(true);
      expect(result.nextToken).toBe('token123');
    });

    it('fetches notes with cursor pagination', async () => {
      const mockResponse = {
        data: {
          items: [mockNote],
        },
      };
      
      vi.mocked(client.get).mockResolvedValue(mockResponse);

      const result = await notesApi.getNotes('cursor123', 20);

      expect(client.get).toHaveBeenCalledWith('/notes', { 
        params: { limit: 20, nextToken: 'cursor123' } 
      });
      expect(result.hasMore).toBe(false);
    });
  });

  describe('listNotes', () => {
    it('fetches all notes', async () => {
      const mockResponse = {
        data: {
          items: [mockNote],
        },
      };
      
      vi.mocked(client.get).mockResolvedValue(mockResponse);

      const result = await notesApi.listNotes();

      expect(client.get).toHaveBeenCalledWith('/notes');
      expect(result).toEqual([mockNote]);
    });
  });

  describe('getNote', () => {
    it('fetches a single note by id', async () => {
      const mockResponse = { data: mockNote };
      
      vi.mocked(client.get).mockResolvedValue(mockResponse);

      const result = await notesApi.getNote('123');

      expect(client.get).toHaveBeenCalledWith('/notes/123');
      expect(result).toEqual(mockNote);
    });
  });

  describe('createNote', () => {
    it('creates a new note', async () => {
      const payload = { title: 'New Note', content: 'New content' };
      const mockResponse = { data: mockNote };
      
      vi.mocked(client.post).mockResolvedValue(mockResponse);

      const result = await notesApi.createNote(payload);

      expect(client.post).toHaveBeenCalledWith('/notes', payload);
      expect(result).toEqual(mockNote);
    });
  });

  describe('updateNote', () => {
    it('updates an existing note', async () => {
      const payload = { title: 'Updated Title' };
      const mockResponse = { data: { ...mockNote, ...payload } };
      
      vi.mocked(client.put).mockResolvedValue(mockResponse);

      const result = await notesApi.updateNote('123', payload);

      expect(client.put).toHaveBeenCalledWith('/notes/123', payload);
      expect(result.title).toBe('Updated Title');
    });
  });

  describe('deleteNote', () => {
    it('deletes a note', async () => {
      vi.mocked(client.delete).mockResolvedValue({ data: {} });

      await notesApi.deleteNote('123');

      expect(client.delete).toHaveBeenCalledWith('/notes/123');
    });
  });
});
