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

// Create a client
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 30000,
    },
  },
});

// Simple router
type Route = {
  path: string;
  component: React.ComponentType<any>;
  requiresAuth?: boolean;
};

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

function Router() {
  const [currentPath, setCurrentPath] = useState(window.location.pathname);
  const [noteId, setNoteId] = useState<string | null>(null);
  const { isAuthenticated, isLoading } = useAuth();

  const extractNoteId = useCallback(() => {
    const match = window.location.pathname.match(/\/notes\/([^/]+)/);
    setNoteId(match ? match[1] : null);
  }, []);

  React.useEffect(() => {
    const handlePopState = () => {
      setCurrentPath(window.location.pathname);
      extractNoteId();
    };

    window.addEventListener('popstate', handlePopState);

    // Override link clicks
    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      const link = target.closest('a');

      if (link && link.href.startsWith(window.location.origin)) {
        e.preventDefault();
        const newPath = new URL(link.href).pathname;
        window.history.pushState({}, '', newPath);
        setCurrentPath(newPath);
        extractNoteId();
      }
    };

    document.addEventListener('click', handleClick);
    extractNoteId();

    return () => {
      window.removeEventListener('popstate', handlePopState);
      document.removeEventListener('click', handleClick);
    };
  }, [extractNoteId]);

  const navigate = useCallback((path: string) => {
    window.history.pushState({}, '', path);
    setCurrentPath(path);
    extractNoteId();
  }, [extractNoteId]);

  // Redirect authenticated users from auth pages
  React.useEffect(() => {
    if (!isLoading && isAuthenticated && ['/', '/signin', '/signup', '/forgot-password'].includes(currentPath)) {
      navigate('/notes');
    }
  }, [isLoading, isAuthenticated, currentPath, navigate]);

  // Find matching route
  let matchedRoute: Route | null = null;

  if (noteId) {
    matchedRoute = routes.find(r => r.path === '/notes/:id') || null;
  } else {
    matchedRoute = routes.find(r => r.path === currentPath) || null;
  }

  // Handle loading state
  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="text-center">
          <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading...</p>
        </div>
      </div>
    );
  }

  // Prevent flash of auth pages when authenticated
  if (isAuthenticated && ['/', '/signin', '/signup', '/forgot-password'].includes(currentPath)) {
    return null;
  }

  // Check authentication
  if (matchedRoute?.requiresAuth && !isAuthenticated) {
    return <SignInPage />;
  }

  if (!matchedRoute) {
    return <NotFoundPage />;
  }

  const Component = matchedRoute.component;

  // Don't show layout for auth pages
  const isAuthPage = ['/', '/signin', '/signup', '/forgot-password'].includes(currentPath);

  if (isAuthPage) {
    return <Component navigate={navigate} />;
  }

  return <AuthenticatedLayout noteId={noteId}><Component noteId={noteId} navigate={navigate} /></AuthenticatedLayout>;
}

function AuthenticatedLayout({ children }: { children: React.ReactNode; noteId?: string | null }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="min-h-screen bg-background">
      <Header onMenuClick={() => setSidebarOpen(true)} />
      <div className="flex">
        <Sidebar
          isOpen={sidebarOpen}
          onClose={() => setSidebarOpen(false)}
        />
        <main className="flex-1 md:ml-64 p-4 md:p-6 lg:p-8">
          {children}
        </main>
      </div>
    </div>
  );
}

// Main App component
export default function App() {
  const [isOnline, setIsOnline] = useState(navigator.onLine);

  React.useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, []);

  if (!isOnline) {
    return <OfflinePage />;
  }

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