import React, { useState, useCallback } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ReactQueryDevtools } from '@tanstack/react-query-devtools';
import { ThemeProvider } from 'next-themes';
import { Toaster } from './components/ui/sonner';
import { AuthProvider, useAuth } from '../contexts/AuthContext';
import { Header } from './components/Layout/Header';
import { Sidebar } from './components/Layout/Sidebar';
import { NotesPage } from './pages/NotesPage';
import { NoteDetailPage } from './pages/NoteDetailPage';
import { SignInPage } from './pages/Auth/SignInPage';
import { SignUpPage } from './pages/Auth/SignUpPage';
import { ForgotPasswordPage } from './pages/Auth/ForgotPasswordPage';
import { ProfilePage } from './pages/ProfilePage';
import { NotFoundPage } from './pages/ErrorPages/NotFoundPage';
import { OfflinePage } from './pages/ErrorPages/OfflinePage';

/**
 * React Query Client Configuration
 * 
 * TanStack React Query manages all server state (API data) in this app.
 * This configuration affects how ALL queries behave globally.
 * 
 * Why React Query?
 * - Automatic caching: Fetch once, reuse everywhere
 * - Background refetching: Keep data fresh without manual effort
 * - Loading/error states: Handled automatically per query
 * 
 * Configuration explained:
 * - refetchOnWindowFocus: false → Don't refetch when user switches browser tabs
 * - retry: 1 → If API fails, try once more before showing error
 * - staleTime: 30000 → Data is "fresh" for 30 seconds (30,000ms)
 *   After 30s, React Query will refetch in the background when component mounts
 */
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 30000,
    },
  },
});

/**
 * Route Type Definition
 * 
 * Defines the shape of each route in our simple client-side router.
 * 
 * Properties:
 * - path: URL path that triggers this route (e.g., '/notes')
 * - component: React component to render when path matches
 * - requiresAuth: If true, user must be logged in to access this route
 *   Unauthenticated users will be redirected to sign-in
 */
type Route = {
  path: string;
  component: React.ComponentType<any>;
  requiresAuth?: boolean;
};

/**
 * Application Routes Configuration
 * 
 * This is a simple client-side routing system (not using React Router).
 * Each entry maps a URL path to a component.
 * 
 * Why simple routing?
 * - This is a small app with few routes
 * - Avoids external routing library complexity
 * - Full control over auth redirects
 * 
 * Auth pages (requiresAuth: false):
 * - Accessible when logged out
 * - Redirect to /notes if already logged in
 * 
 * Protected pages (requiresAuth: true):
 * - Require authentication
 * - Redirect to sign-in if not authenticated
 * 
 * Note: '/notes/:id' uses dynamic parameter matching
 * The :id part is extracted separately in the Router component
 */
const routes: Route[] = [
  { path: '/', component: SignInPage, requiresAuth: false },
  { path: '/app', component: NotesPage, requiresAuth: true },
  { path: '/notes', component: NotesPage, requiresAuth: true },
  { path: '/notes/:id', component: NoteDetailPage, requiresAuth: true },
  { path: '/profile', component: ProfilePage, requiresAuth: true },
  { path: '/settings', component: ProfilePage, requiresAuth: true },
  { path: '/signin', component: SignInPage, requiresAuth: false },
  { path: '/signup', component: SignUpPage, requiresAuth: false },
  { path: '/forgot-password', component: ForgotPasswordPage, requiresAuth: false },
  { path: '/offline', component: OfflinePage, requiresAuth: false },
];

/**
 * Router Component
 * 
 * Custom client-side router that handles:
 * 1. URL path matching
 * 2. Authentication guards
 * 3. Dynamic route parameters (like /notes/:id)
 * 4. Browser back/forward navigation
 * 5. Link click interception
 * 
 * State Management:
 * - currentPath: Tracks the active URL path
 * - noteId: Extracted ID from /notes/:id routes
 * - Auth state comes from AuthContext (isAuthenticated, isLoading)
 * 
 * Why local state for routing?
 * - Simple app doesn't need React Router complexity
 * - Full control over navigation and redirects
 * - Easy to understand for beginners
 */
function Router() {
  // Track the current URL path in state
  // When this changes, component re-renders with new route
  const [currentPath, setCurrentPath] = useState(window.location.pathname);
  
  // Store extracted note ID from dynamic routes like /notes/abc123
  const [noteId, setNoteId] = useState<string | null>(null);
  
  // Get authentication state from AuthContext
  // isLoading: true while checking if user is logged in (prevents flash of wrong page)
  // isAuthenticated: true if user is logged in
  const { isAuthenticated, isLoading } = useAuth();

  /**
   * Extract Note ID from URL
   * 
   * For routes like /notes/abc123, this function:
   * 1. Uses regex to match the pattern /notes/[anything]
   * 2. Extracts the "anything" part as the note ID
   * 3. Stores it in state so NoteDetailPage can use it
   * 
   * Why useCallback?
   * - This function is used in useEffect dependencies
   * - Prevents infinite re-render loops by keeping function reference stable
   */
  const extractNoteId = useCallback(() => {
    const match = window.location.pathname.match(/\/notes\/([^/]+)/);
    setNoteId(match ? match[1] : null);
  }, []);

  /**
   * Set up browser navigation listeners
   * 
   * This useEffect handles:
   * 1. Browser back/forward buttons (popstate event)
   * 2. Clicking <a> links (click event interception)
   * 
   * Why intercept link clicks?
   * - Prevents full page reload (SPA behavior)
   * - Updates URL without server request
   * - Triggers React re-render with new path
   * 
   * Clean up:
   * - Return function removes event listeners when component unmounts
   * - Prevents memory leaks
   */
  React.useEffect(() => {
    // Handle browser back/forward buttons
    const handlePopState = () => {
      setCurrentPath(window.location.pathname);
      extractNoteId();
    };

    window.addEventListener('popstate', handlePopState);

    // Intercept all link clicks to make them client-side navigation
    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      const link = target.closest('a');

      // Only intercept internal links (same origin)
      if (link && link.href.startsWith(window.location.origin)) {
        e.preventDefault(); // Stop browser from navigating normally
        const newPath = new URL(link.href).pathname;
        window.history.pushState({}, '', newPath); // Update URL without reload
        setCurrentPath(newPath); // Trigger React re-render
        extractNoteId();
      }
    };

    document.addEventListener('click', handleClick);
    
    // Extract note ID on initial mount
    extractNoteId();

    // Clean up: Remove listeners when component unmounts
    return () => {
      window.removeEventListener('popstate', handlePopState);
      document.removeEventListener('click', handleClick);
    };
  }, [extractNoteId]);

  /**
   * Programmatic Navigation Function
   * 
   * Allows components to navigate without <a> tags.
   * Example: navigate('/notes') after creating a note
   * 
   * Updates:
   * 1. Browser URL (pushState)
   * 2. Component state (setCurrentPath)
   * 3. Note ID if applicable (extractNoteId)
   * 
   * Why useCallback?
   * - Passed to child components as prop
   * - Stable reference prevents unnecessary child re-renders
   */
  const navigate = useCallback((path: string) => {
    window.history.pushState({}, '', path);
    setCurrentPath(path);
    extractNoteId();
  }, [extractNoteId]);

  /**
   * Auto-redirect authenticated users from auth pages
   * 
   * Problem: If user is logged in and visits /signin, they should go to /notes
   * Solution: Watch auth state and current path, redirect if needed
   * 
   * Why separate useEffect?
   * - Clear separation of concerns
   * - Easy to understand redirect logic
   * - Runs after auth loading completes
   */
  React.useEffect(() => {
    if (!isLoading && isAuthenticated && ['/', '/signin', '/signup', '/forgot-password'].includes(currentPath)) {
      navigate('/notes');
    }
  }, [isLoading, isAuthenticated, currentPath, navigate]);

  /**
   * Route Matching Logic
   * 
   * Find which route matches the current URL:
   * 1. If noteId exists, match the dynamic /notes/:id route
   * 2. Otherwise, match by exact path
   * 3. If no match, will show 404 page
   */
  let matchedRoute: Route | null = null;

  if (noteId) {
    matchedRoute = routes.find(r => r.path === '/notes/:id') || null;
  } else {
    matchedRoute = routes.find(r => r.path === currentPath) || null;
  }

  /**
   * Loading State UI
   * 
   * Show spinner while:
   * - Checking if user is authenticated (AWS Amplify token validation)
   * - Prevents flash of wrong page (auth vs. non-auth)
   * 
   * Visual: Centered spinner with loading text
   */
  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="text-center">
          {/* Tailwind animation: spin the border, make one side transparent */}
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  /**
   * Prevent Flash of Auth Pages
   * 
   * Edge case: If user is authenticated and URL is an auth page:
   * - Don't render anything (return null)
   * - Previous useEffect will redirect to /notes
   * - Avoids brief flash of sign-in page before redirect
   */
  if (isAuthenticated && ['/', '/signin', '/signup', '/forgot-password'].includes(currentPath)) {
    return null;
  }

  /**
   * Authentication Guard
   * 
   * If route requires auth and user is not authenticated:
   * - Show SignInPage instead of the protected content
   * - User must log in to proceed
   */
  if (matchedRoute?.requiresAuth && !isAuthenticated) {
    return <SignInPage />;
  }

  /**
   * 404 Not Found
   * 
   * If no route matches the current path:
   * - Show NotFoundPage
   * - Handles typos, deleted pages, etc.
   */
  if (!matchedRoute) {
    return <NotFoundPage />;
  }

  const Component = matchedRoute.component;

  /**
   * Layout Decision: Auth Pages vs. App Pages
   * 
   * Auth pages (sign in, sign up, forgot password):
   * - No header or sidebar
   * - Full-screen centered forms
   * 
   * App pages (notes, profile, etc.):
   * - Include Header and Sidebar
   * - Wrapped in AuthenticatedLayout
   * 
   * Why check path?
   * - Different visual design for auth flows
   * - App pages need navigation UI
   */
  const isAuthPage = ['/', '/signin', '/signup', '/forgot-password'].includes(currentPath);

  if (isAuthPage) {
    return <Component navigate={navigate} />;
  }

  return <AuthenticatedLayout noteId={noteId}><Component noteId={noteId} navigate={navigate} /></AuthenticatedLayout>;
}

/**
 * Authenticated Layout Component
 * 
 * Wraps all protected pages (notes, profile, etc.) with:
 * 1. Header (top navigation bar with menu button)
 * 2. Sidebar (left navigation panel)
 * 3. Main content area
 * 
 * State Management:
 * - sidebarOpen: Controls mobile sidebar visibility
 *   Desktop: Sidebar always visible
 *   Mobile: Sidebar hidden by default, toggle with menu button
 * 
 * Layout Structure:
 * - min-h-screen: Ensure layout fills viewport height
 * - bg-background: Tailwind theme-aware background color
 * - Flexbox: Sidebar and main content sit side-by-side
 * 
 * Why separate layout component?
 * - Reusable: All app pages share this layout
 * - Clean separation: Auth pages don't need it
 * - Single source of truth for sidebar state
 */
function AuthenticatedLayout({ children }: { children: React.ReactNode; noteId?: string | null }) {
  // Control sidebar open/closed state
  // false = closed (mobile default), true = open
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background">
      {/* 
        Header Component:
        - Always visible at top
        - Contains menu button (mobile) and user actions
        - onMenuClick opens sidebar on mobile
      */}
      <Header onMenuClick={() => setSidebarOpen(true)} />
      
      {/* 
        Main Layout Container:
        - Flexbox to position sidebar and content side-by-side
      */}
      <div className="flex">
        {/* 
          Sidebar Component:
          - Navigation links (Notes, Profile, etc.)
          - isOpen: Controls visibility (mobile only, desktop always visible)
          - onClose: Callback to close sidebar (when user clicks outside or link)
        */}
        <Sidebar
          isOpen={sidebarOpen}
          onClose={() => setSidebarOpen(false)}
        />
        
        {/* 
          Main Content Area:
          - flex-1: Takes remaining space after sidebar
          - md:ml-64: On medium+ screens, add left margin for fixed sidebar
            (64 = 16rem = sidebar width)
          - p-4/p-6/p-8: Responsive padding (grows with screen size)
            Mobile: 1rem, Tablet: 1.5rem, Desktop: 2rem
          
          Why responsive padding?
          - More breathing room on larger screens
          - Conserve space on mobile
        */}
        <main className="flex-1 md:ml-64 p-4 md:p-6 lg:p-8">
          {children}
        </main>
      </div>
    </div>
  );
}

/**
 * Main App Component
 * 
 * Root component that sets up the entire application infrastructure:
 * 
 * 1. QueryClientProvider: Makes React Query available to all child components
 *    - Enables data fetching, caching, and synchronization
 *    - All API calls use this for consistent behavior
 * 
 * 2. ThemeProvider: Manages dark/light/system theme preference
 *    - attribute="class": Adds "dark" class to <html> when dark mode active
 *    - defaultTheme="system": Respects user's OS preference
 *    - enableSystem: Auto-switch when OS theme changes
 * 
 * 3. AuthProvider: Makes authentication state available everywhere
 *    - Wraps AWS Amplify auth logic
 *    - Provides isAuthenticated, user info, login/logout functions
 * 
 * 4. Router: Custom routing logic (handles navigation)
 * 
 * 5. Toaster: Toast notifications component (success/error messages)
 *    - position="bottom-right": Where toasts appear on screen
 *    - Uses Sonner library for accessible notifications
 * 
 * 6. ReactQueryDevtools: Developer tools for React Query
 *    - Only shown in development mode
 *    - Inspect queries, mutations, cache
 * 
 * Provider Nesting Order Matters:
 * - QueryClient at top: All children can use React Query
 * - Theme next: All children can read/set theme
 * - Auth inside theme: Auth UI can be themed
 * - Router inside auth: Routes can check auth state
 * 
 * Offline Detection:
 * - Listens to browser online/offline events
 * - Shows OfflinePage when no internet connection
 * - Automatically reconnects when online
 */
export default function App() {
  // Track browser's online/offline state
  // navigator.onLine: Browser API that detects internet connectivity
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  /**
   * Set up online/offline event listeners
   * 
   * Browser fires these events when:
   * - 'online': Internet connection restored
   * - 'offline': Lost internet connection
   * 
   * Why useEffect?
   * - Event listeners must be added after component mounts
   * - Clean up listeners when component unmounts (prevents memory leaks)
   * 
   * Empty dependency array []:
   * - Run once on mount, clean up on unmount
   * - Listeners don't depend on any props or state
   */
  React.useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    // Clean up: Remove listeners when App unmounts
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  /**
   * Offline State Handling
   * 
   * If no internet connection:
   * - Show OfflinePage (user-friendly error message)
   * - Don't try to render app (API calls would fail)
   * - When connection returns, isOnline becomes true, app re-renders normally
   */
  if (!isOnline) {
    return <OfflinePage />;
  }

  /**
   * Main App Provider Tree
   * 
   * Each provider wraps its children and provides context:
   * - QueryClientProvider: React Query for data fetching
   * - ThemeProvider: Dark/light mode management
   * - AuthProvider: User authentication state
   * - Router: Page navigation and routing
   * - Toaster: Toast notification system
   * - ReactQueryDevtools: Debug tool (dev mode only)
   * 
   * Why this structure?
   * - Clear hierarchy: Outer providers available to inner components
   * - Separation of concerns: Each provider has one job
   * - Easy to understand: Read top-to-bottom for app setup
   */
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
        <AuthProvider>
          <Router />
          <Toaster position="bottom-right" />
        </AuthProvider>
      </ThemeProvider>
      <ReactQueryDevtools initialIsOpen={false} />
    </QueryClientProvider>
  );
}