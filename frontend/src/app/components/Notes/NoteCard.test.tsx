/**
 * NoteCard Component Tests
 * 
 * Purpose:
 * - Tests the UI behavior of the NoteCard component
 * - Verifies user interactions (clicking, editing, deleting)
 * - Ensures content rendering and formatting work correctly
 * 
 * Testing Strategy:
 * - Use Vitest as the test runner (Vite-compatible alternative to Jest)
 * - Use React Testing Library to render and query components
 * - Focus on user-visible behavior, not implementation details
 */

// === Testing Framework Imports ===
// 'describe': Groups related tests together
// 'it': Defines an individual test case
// 'expect': Makes assertions about test results
// 'vi': Vitest's mock function utility (like Jest's 'jest')
import { describe, it, expect, vi } from 'vitest';

// === React Testing Library Imports ===
// 'render': Renders a React component into a test DOM
// 'screen': Queries the rendered DOM (e.g., getByText, getByRole)
// 'fireEvent': Simulates user interactions (clicks, typing, etc.)
import { render, screen, fireEvent } from '@testing-library/react';

// === Component Under Test ===
import { NoteCard } from './NoteCard';

// === Type Imports ===
// Import the Note type to ensure our mock data matches the real structure
import type { Note } from '../../../types';

/**
 * Mock Note Data
 * 
 * Why we need this:
 * - Tests should be isolated and not depend on real API data
 * - Provides a consistent, predictable data structure
 * - Makes tests reliable and repeatable
 * 
 * Structure:
 * - All required fields for a Note object
 * - Uses realistic but simple test data
 * - ISO 8601 date strings for consistency
 */
const mockNote: Note = {
  id: '123',
  userId: 'user-1',
  title: 'Test Note',
  content: 'This is a test note content',
  tags: ['test', 'demo'],
  createdAt: '2025-12-20T10:00:00Z',
  updatedAt: '2025-12-24T10:00:00Z',
};

/**
 * NoteCard Test Suite
 * 
 * What we're testing:
 * 1. Basic rendering of title and content
 * 2. Content truncation for long text
 * 3. User interaction handlers (click, edit, delete)
 * 4. Time formatting display
 * 5. Event propagation behavior
 */
describe('NoteCard', () => {
  /**
   * Test: Basic Content Rendering
   * 
   * What this proves:
   * - The component displays the note's title
   * - The component displays the note's content
   * - Text is accessible in the DOM for users and screen readers
   * 
   * Why it matters:
   * - Core functionality test - if this fails, the component is broken
   * - Ensures content is actually visible to users
   */
  it('renders note title and content', () => {
    // Render the component with our mock note data
    render(<NoteCard note={mockNote} />);
    
    // Check that the title appears in the document
    // 'getByText' searches for an element containing this exact text
    expect(screen.getByText('Test Note')).toBeInTheDocument();
    
    // Check that the content appears in the document
    expect(screen.getByText('This is a test note content')).toBeInTheDocument();
  });

  /**
   * Test: Long Content Truncation
   * 
   * What this proves:
   * - Long note content is truncated to prevent UI overflow
   * - Truncated content includes an ellipsis (...) indicator
   * - The displayed text is shorter than the original
   * 
   * Why it matters:
   * - Prevents the card from becoming too tall
   * - Maintains clean UI in note lists
   * - Shows user there's more content to read
   * 
   * Implementation note:
   * - We create a note with 200 'a' characters
   * - The component should show fewer than 200 characters
   * - The ellipsis pattern /a+\.\.\./ matches "aaa..." format
   */
  it('truncates long content', () => {
    // Create a test note with very long content (200 characters)
    // The spread operator (...mockNote) copies all fields from mockNote
    // Then we override just the 'content' field
    const longNote: Note = {
      ...mockNote,
      content: 'a'.repeat(200), // Creates "aaaaaaa..." (200 times)
    };
    
    // Render the component with the long content
    render(<NoteCard note={longNote} />);
    
    // Find the element containing truncated content
    // Regex /a+\.\.\./ matches one or more 'a' followed by literal '...'
    const content = screen.getByText(/a+\.\.\./);
    
    // Verify the displayed text is shorter than the original
    // This proves truncation is working
    expect(content.textContent?.length).toBeLessThan(200);
  });

  /**
   * Test: Click Handler on Card
   * 
   * What this proves:
   * - Clicking the card triggers the onClick callback
   * - The callback is invoked exactly once per click
   * 
   * Why it matters:
   * - Users should be able to click a card to view full details
   * - Ensures navigation or detail view opening works
   * 
   * Testing strategy:
   * - Use vi.fn() to create a mock function (spy)
   * - Pass it as the onClick prop
   * - Simulate a click event
   * - Verify the function was called exactly once
   */
  it('calls onClick handler when card is clicked', () => {
    // Create a mock function to track if/when it's called
    // vi.fn() creates a spy that records calls
    const onClick = vi.fn();
    
    // Render with the mock onClick handler
    render(<NoteCard note={mockNote} onClick={onClick} />);
    
    // Find the clickable card element
    // We find the title first, then navigate to the card container
    // '.group' is a Tailwind CSS class used for the card wrapper
    const card = screen.getByText('Test Note').closest('.group');
    
    // Simulate a user clicking on the card
    fireEvent.click(card!);
    
    // Verify the onClick handler was invoked exactly once
    expect(onClick).toHaveBeenCalledTimes(1);
  });

  /**
   * Test: Edit Button Handler
   * 
   * What this proves:
   * - The edit button is accessible (has proper aria-label)
   * - Clicking edit triggers the onEdit callback
   * - The callback is invoked exactly once
   * 
   * Why it matters:
   * - Users need to edit their notes
   * - Accessibility: screen readers can identify the button purpose
   * - Ensures edit flow works correctly
   * 
   * Accessibility note:
   * - We query by 'aria-label' which is what screen readers use
   * - This ensures the button is properly labeled for all users
   */
  it('calls onEdit handler when edit button is clicked', () => {
    // Create a mock function to track edit button clicks
    const onEdit = vi.fn();
    
    // Render with the mock onEdit handler
    render(<NoteCard note={mockNote} onEdit={onEdit} />);
    
    // Find the edit button by its accessible label
    // 'getByLabelText' looks for elements with matching aria-label
    // This is how screen readers identify the button
    const editButton = screen.getByLabelText('Edit note');
    
    // Simulate user clicking the edit button
    fireEvent.click(editButton);
    
    // Verify the onEdit handler was called exactly once
    expect(onEdit).toHaveBeenCalledTimes(1);
  });

  /**
   * Test: Delete Button Handler
   * 
   * What this proves:
   * - The delete button is accessible (has proper aria-label)
   * - Clicking delete triggers the onDelete callback
   * - The callback is invoked exactly once
   * 
   * Why it matters:
   * - Users need to delete unwanted notes
   * - Ensures the delete flow works correctly
   * - Accessibility: button is properly labeled
   */
  it('calls onDelete handler when delete button is clicked', () => {
    // Create a mock function to track delete button clicks
    const onDelete = vi.fn();
    
    // Render with the mock onDelete handler
    render(<NoteCard note={mockNote} onDelete={onDelete} />);
    
    // Find the delete button by its accessible label
    const deleteButton = screen.getByLabelText('Delete note');
    
    // Simulate user clicking the delete button
    fireEvent.click(deleteButton);
    
    // Verify the onDelete handler was called exactly once
    expect(onDelete).toHaveBeenCalledTimes(1);
  });

  /**
   * Test: Relative Time Display
   * 
   * What this proves:
   * - The component displays a human-readable relative time
   * - Uses date-fns library for formatting (e.g., "2 days ago")
   * - Time is based on the note's updatedAt field
   * 
   * Why it matters:
   * - Users need to know when notes were last updated
   * - Relative time is more user-friendly than raw timestamps
   * - Shows the component properly formats dates
   * 
   * Implementation detail:
   * - date-fns formatDistanceToNow() creates relative time strings
   * - Depending on the current date vs updatedAt, it shows:
   *   - "in about X minutes/hours/days" (future dates)
   *   - "X minutes/hours/days ago" (past dates)
   * - Our regex /in about|ago/i matches both patterns (case-insensitive)
   */
  it('displays relative time for updatedAt', () => {
    // Render the component with our mock note
    render(<NoteCard note={mockNote} />);
    
    // Verify that a relative time string is displayed
    // The pattern matches common relative time formats:
    // - "in about 2 hours" (if test runs before updatedAt)
    // - "2 hours ago" (if test runs after updatedAt)
    // The 'i' flag makes it case-insensitive
    expect(screen.getByText(/in about|ago/i)).toBeInTheDocument();
  });

  /**
   * Test: Event Propagation Prevention
   * 
   * What this proves:
   * - Clicking edit/delete buttons does NOT trigger card onClick
   * - Events are properly stopped from bubbling up the DOM tree
   * - Users can edit/delete without accidentally opening the note
   * 
   * Why it matters:
   * - UX Problem: Without event.stopPropagation(), clicking "Edit"
   *   would trigger both onEdit AND onClick (opening the note)
   * - This test ensures buttons work independently of card click
   * - Critical for preventing unintended navigation
   * 
   * Event propagation explained:
   * - DOM events "bubble" up from child to parent elements
   * - Edit button is inside the card, so clicks go: button → card
   * - Without stopPropagation, both handlers would fire
   * - With stopPropagation, only the button handler fires
   */
  it('stops event propagation when clicking edit/delete buttons', () => {
    // Create mock functions for both card and edit button
    const onClick = vi.fn();
    const onEdit = vi.fn();
    
    // Render with both handlers
    render(<NoteCard note={mockNote} onClick={onClick} onEdit={onEdit} />);
    
    // Find and click the edit button
    const editButton = screen.getByLabelText('Edit note');
    fireEvent.click(editButton);
    
    // Verify that ONLY the edit handler was called
    // The card's onClick should NOT have been triggered
    expect(onEdit).toHaveBeenCalledTimes(1);
    expect(onClick).not.toHaveBeenCalled();
  });
});
