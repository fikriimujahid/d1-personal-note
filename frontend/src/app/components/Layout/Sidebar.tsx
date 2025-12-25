import React from 'react';
// lucide-react: Icon library for clean SVG icons (Home, Menu, Close, etc)
import { Home, FileText, Tag, Settings, X } from 'lucide-react';
// Button component: Reusable button from our UI library (Radix + Tailwind)
import { Button } from '../ui/button';
// ScrollArea: Radix-based scrollable container with smooth scrolling behavior
import { ScrollArea } from '../ui/scroll-area';
// Separator: Simple visual line divider component
import { Separator } from '../ui/separator';
// Badge: Small label component, used to show counts or tags
import { Badge } from '../ui/badge';
// useTags hook: Custom React hook that fetches all tags using TanStack React Query
// Returns: { data: tags[], isLoading, error } - we destructure 'data' as 'tags'
import { useTags } from '../../../hooks/useNotes';

/**
 * SidebarProps: Configuration for the Sidebar component
 * 
 * isOpen: Whether the sidebar is currently visible (mobile/desktop)
 * onClose: Callback when user wants to close the sidebar (mobile menu button)
 * selectedTag: Currently selected tag (for highlighting in the UI)
 * onTagSelect: Callback when user clicks a tag (receives the tag string)
 */
interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  selectedTag?: string;
  onTagSelect?: (tag: string) => void;
}

export function Sidebar({ isOpen, onClose, selectedTag, onTagSelect }: SidebarProps) {
  /**
   * useTags hook: Fetches all available tags from the API using React Query
   * Why React Query: Automatically caches tags, refetches in background, handles errors
   * Destructuring: 'data' is the array of tags, defaults to [] if loading/error
   * This query runs once on mount and reuses the cached result
   */
  const { data: tags = [] } = useTags();

  /**
   * navItems: Static list of main navigation links
   * Each item has:
   *  - icon: Lucide React icon component (displayed as visual indicator)
   *  - label: Text shown to the user
   *  - href: URL to navigate to when clicked
   * 
   * Why static: These navigation items don't change - they're always the same
   * Why array: Makes it easy to loop through and render multiple items
   */
  const navItems = [
    { icon: Home, label: 'All Notes', href: '/notes' },
    { icon: FileText, label: 'Recent', href: '/notes?sort=recent' },
    { icon: Tag, label: 'Tags', href: '#tags' },
    { icon: Settings, label: 'Settings', href: '/settings' },
  ];

  return (
    <>
      {/* 
        MOBILE BACKDROP: Semi-transparent overlay that covers the page when sidebar is open
        Why: Gives visual feedback that sidebar is a modal overlay on mobile
        How it works:
        - Conditional rendering: Only renders if isOpen === true
        - onClick={onClose}: Clicking backdrop closes the menu
        - md:hidden: Only visible on mobile (hidden on medium screens and up)
        - inset-0: Covers entire viewport (top, right, bottom, left = 0)
        - z-40: Sits below sidebar (z-40) but above page content (z-30)
        - bg-background/80: 80% opaque background color
      */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-background/80 backdrop-blur-sm md:hidden"
          onClick={onClose}
        />
      )}

      {/* 
        MAIN SIDEBAR: Navigation menu that slides in from left on mobile
        Stays visible on desktop (always shown)
      */}
      <aside
        className={`
          fixed top-14 left-0 z-40 h-[calc(100vh-3.5rem)] w-64 border-r bg-background transition-transform duration-200 md:translate-x-0
          ${isOpen ? 'translate-x-0' : '-translate-x-full'}
        `}
      >
        {/* 
          Tailwind classes explained:
          - fixed: Positioned relative to viewport (not the page flow)
          - top-14: Positioned 3.5rem (56px) from top (below header)
          - left-0: Aligned to left edge
          - z-40: Stacking order (appears above backdrop and page content)
          - w-64: Width of 256px (16rem)
          - h-[calc(100vh-3.5rem)]: Height = viewport height minus header height
          - border-r: Border on right side (separates from main content)
          - bg-background: Uses theme background color
          - transition-transform duration-200: Smooth slide animation (200ms)
          - md:translate-x-0: On medium+ screens, always visible (no slide needed)
          - Conditional class: translate-x-0 (visible) or -translate-x-full (hidden left)
        */}

        {/* Container for sidebar content: flex column to stack sections vertically */}
        <div className="flex h-full flex-col">
          {/* 
            MOBILE HEADER: Shows "Menu" label and close button
            md:hidden: Only visible on mobile (hidden on medium screens and up)
            Why separate: Desktop doesn't need to close the sidebar
          */}
          <div className="flex items-center justify-between p-4 md:hidden">
            <h2 className="text-lg">Menu</h2>
            <Button
              variant="ghost"
              size="icon"
              onClick={onClose}
              aria-label="Close menu"
            >
              <X className="h-5 w-5" />
            </Button>
          </div>

          {/* 
            SCROLLABLE CONTENT AREA:
            ScrollArea: Radix-based container that adds smooth scrolling behavior
            Why: Sidebar can overflow if there are many tags; provides better UX than browser scrollbar
            flex-1: Takes all remaining vertical space
          */}
          <ScrollArea className="flex-1 px-3">
            {/* Navigation links section */}
            <div className="space-y-1 py-4">
              {/* 
                Loop through nav items and create a link for each
                Why .map(): Renders multiple items from a single template
              */}
              {navItems.map((item) => {
                // Store the icon component in a variable so we can render it as a JSX element
                // Why: JavaScript requires us to store dynamic components in variables
                const Icon = item.icon;
                return (
                  <a
                    key={item.href}
                    href={item.href}
                    className="flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors hover:bg-accent hover:text-accent-foreground"
                  >
                    {/* Render the icon component with consistent size */}
                    <Icon className="h-4 w-4" />
                    {/* Display the navigation label text */}
                    {item.label}
                  </a>
                );
              })}
            </div>

            {/* Visual divider between navigation and tags sections */}
            <Separator className="my-4" />

            {/* TAGS SECTION: List of user's note tags */}
            <div className="pb-4">
              {/* Section title: "Tags" */}
              <h3 className="mb-2 px-3 text-xs text-muted-foreground uppercase tracking-wider">
                Tags
              </h3>
              <div className="space-y-1">
                {/* 
                  Conditional rendering: Show "No tags yet" message OR the tags list
                  Why: Better UX than rendering empty list - teaches user what's happening
                */}
                {tags.length === 0 ? (
                  <p className="px-3 py-2 text-xs text-muted-foreground">
                    No tags yet
                  </p>
                ) : (
                  /* 
                    Render each tag as a clickable button
                    Why loop: One button per tag (user could have many tags)
                  */
                  tags.map((tag) => (
                    <button
                      key={tag}
                      onClick={() => onTagSelect?.(tag)}
                      className={`
                        flex w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition-colors hover:bg-accent hover:text-accent-foreground
                        ${selectedTag === tag ? 'bg-accent' : ''}
                      `}
                    >
                      {/* 
                        Tag name: truncate text if too long (so it doesn't break layout)
                        Using <span> to limit width of text overflow
                      */}
                      <span className="truncate">{tag}</span>
                      {/* 
                        Badge: Shows count of notes with this tag (empty now, but ready for data)
                        variant="secondary": Different color from primary badges
                        ml-2: 8px margin on left to push it away from tag name
                      */}
                      <Badge variant="secondary" className="ml-2 text-xs">
                        {/* TODO: This would show count in real app (e.g., "5 notes") */}
                      </Badge>
                    </button>
                  ))
                )}
              </div>
            </div>
          </ScrollArea>

          {/* 
            FOOTER: Version info
            border-t: Border on top to separate from content
          */}
          <div className="border-t p-4">
            <p className="text-xs text-muted-foreground text-center">
              Version 1.0.0
            </p>
          </div>
        </div>
      </aside>
    </>
  );
}
