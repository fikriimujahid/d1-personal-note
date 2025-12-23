import { ulid } from 'ulid';

export const generateId = (): string => {
  return `n_${ulid()}`;
};