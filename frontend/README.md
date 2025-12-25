# Personal Notes App - Frontend

A modern, full-featured note-taking web application built with React 18, Vite, and AWS Amplify. This frontend provides a fast, responsive user interface for creating, organizing, and managing personal notes.

## 📋 Table of Contents

- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Key Features](#key-features)
- [Core Concepts](#core-concepts)
- [Available Scripts](#available-scripts)
- [Environment Configuration](#environment-configuration)
- [Testing](#testing)
- [Code Style & Patterns](#code-style--patterns)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This is a **Single Page Application (SPA)** that provides:
- User authentication (sign up, sign in, password reset)
- CRUD operations for notes (Create, Read, Update, Delete)
- Tag-based organization
- Responsive design for desktop and mobile
- Real-time updates with optimistic UI updates

**What is a SPA?**  
Unlike traditional websites that reload the entire page on navigation, a SPA loads once and dynamically updates content. This provides a faster, more app-like experience.

---

## 🛠 Tech Stack

### Core Framework
- **React 18.3** - UI library for building component-based interfaces
- **TypeScript** - Type-safe JavaScript for better developer experience
- **Vite** - Fast build tool and dev server (ESM-based, replaces Create React App)

### UI & Styling
- **Tailwind CSS** - Utility-first CSS framework (primary styling approach)
- **Material-UI (MUI)** - Pre-built React components for complex UI patterns
- **Radix UI** - Unstyled, accessible component primitives
- **Emotion** - CSS-in-JS library (required by MUI)

### State Management
- **TanStack React Query** - Server state management (data fetching, caching, synchronization)
- **React Context** - Local state management for auth

### API & Backend Integration
- **Axios** - HTTP client for API requests
- **AWS Amplify** - Authentication with AWS Cognito
- **RESTful API** - Backend communication using standard HTTP methods

### Routing
- **React Router v6** - Client-side routing for navigation

### Testing
- **Vitest** - Fast unit test runner (Vite-native alternative to Jest)
- **React Testing Library** - Test React components the way users interact with them

### Development Tools
- **ESLint** - Code linting for JavaScript/TypeScript
- **PostCSS** - CSS processing (used by Tailwind)

---

## ✅ Prerequisites

Before you begin, ensure you have:

1. **Node.js** (v18 or higher)
   ```bash
   node --version  # Should be v18.x or higher
   ```

2. **npm** (v9 or higher) - Comes with Node.js
   ```bash
   npm --version
   ```

3. **Backend API Running** - The frontend needs a backend API to communicate with
   - API should be deployed and accessible
   - You'll need the API URL (e.g., `https://api.example.com`)

4. **AWS Cognito Setup** - Authentication requires AWS Cognito
   - User Pool ID
   - App Client ID
   - Region

---

## 🚀 Getting Started

### 1. Install Dependencies

```bash
cd frontend
npm install
```

This downloads all required packages listed in `package.json` into the `node_modules` folder.

### 2. Configure Environment Variables

Create a `.env` file in the `frontend` directory:

```bash
# Copy the example file
cp .env.example .env
```

Edit `.env` and add your values:

```env
# Backend API URL
VITE_API_URL=https://your-api-gateway-url.amazonaws.com/prod

# AWS Cognito Configuration
VITE_AWS_REGION=us-east-1
VITE_USER_POOL_ID=us-east-1_XXXXXXXXX
VITE_USER_POOL_CLIENT_ID=your-app-client-id
```

**Why VITE_ prefix?**  
Vite only exposes environment variables that start with `VITE_` to the frontend code. This prevents accidentally leaking sensitive server-side variables.

### 3. Start Development Server

```bash
npm run dev
```

The app will start on `http://localhost:5173` (Vite's default port).

**What happens:**
- Vite starts a development server with Hot Module Replacement (HMR)
- Changes to code auto-reload in the browser without full page refresh
- TypeScript is compiled on-the-fly
- Source maps are generated for debugging

### 4. Open in Browser

Navigate to `http://localhost:5173` and you should see the login page.

---

## 📁 Project Structure

```
frontend/
├── public/                   # Static assets (served as-is)
│   └── tokens.json          # Design tokens for theming
├── src/
│   ├── app/                 # Main application code
│   │   ├── App.tsx          # Root component, routing setup
│   │   ├── components/      # Reusable React components
│   │   │   ├── Layout/      # Page layout components (Header, Sidebar)
│   │   │   ├── Notes/       # Note-specific components
│   │   │   └── ui/          # Shared UI primitives (buttons, cards, etc.)
│   │   └── pages/           # Page-level components (full screens)
│   │       ├── NotesPage.tsx
│   │       ├── NoteDetailPage.tsx
│   │       ├── ProfilePage.tsx
│   │       ├── Auth/        # Authentication pages
│   │       └── ErrorPages/  # 404, error boundaries
│   ├── contexts/            # React Context providers
│   │   └── AuthContext.tsx  # Authentication state management
│   ├── hooks/               # Custom React hooks
│   │   └── useNotes.ts      # Notes data fetching with React Query
│   ├── services/            # API communication layer
│   │   ├── api-client.ts    # Configured Axios instance
│   │   ├── auth.ts          # Authentication API calls
│   │   └── notes-api.ts     # Notes CRUD operations
│   ├── types/               # TypeScript type definitions
│   │   ├── index.ts         # Shared types
│   │   └── note.ts          # Note-specific types
│   ├── utils/               # Helper functions
│   │   └── test-utils.tsx   # Testing utilities
│   ├── styles/              # Global styles and CSS
│   │   ├── index.css        # Global styles
│   │   ├── tailwind.css     # Tailwind imports
│   │   └── theme.css        # Custom theme variables
│   ├── main.tsx             # Application entry point
│   └── setupTests.ts        # Test configuration
├── .env                     # Environment variables (not in git)
├── .env.example             # Environment variables template
├── index.html               # HTML entry point
├── package.json             # Dependencies and scripts
├── tsconfig.json            # TypeScript configuration
├── vite.config.ts           # Vite build configuration
├── vitest.config.ts         # Vitest test configuration
├── postcss.config.mjs       # PostCSS configuration (for Tailwind)
└── README.md                # This file
```

### Key Directories Explained

- **`src/services/`** - All backend API communication happens here. Components never directly call axios.
- **`src/hooks/`** - Custom React hooks that encapsulate reusable logic (especially React Query hooks).
- **`src/contexts/`** - Global state using React Context (avoid overusing - prefer local state).
- **`src/app/components/ui/`** - Generic, reusable UI components (buttons, inputs, cards).
- **`src/app/pages/`** - Page-level components that represent full screens/routes.

---

## ✨ Key Features

### Authentication
- **Sign Up** - Create new account with email verification
- **Sign In** - Login with email and password
- **Password Reset** - Forgot password flow with email verification
- **Session Management** - Automatic token refresh, logout on expiration

### Notes Management
- **Create Notes** - Rich text editor for note content
- **Edit Notes** - Update existing notes
- **Delete Notes** - Remove notes with confirmation
- **Tag Organization** - Add tags to categorize notes
- **Search & Filter** - Find notes by title, content, or tags
- **Pagination** - Cursor-based pagination for large note lists

### UI/UX Features
- **Responsive Design** - Works on desktop, tablet, and mobile
- **Dark/Light Theme** - Theme switching (if implemented)
- **Optimistic Updates** - UI updates immediately, reverts on error
- **Loading States** - Skeletons and spinners for better UX
- **Error Handling** - User-friendly error messages

---

## 🧠 Core Concepts

### 1. Component Architecture

We follow a **component-based architecture**:

```tsx
// Page (top-level, route-mapped)
function NotesPage() {
  return (
    <Layout>
      <NotesList />
    </Layout>
  );
}

// Feature component (contains business logic)
function NotesList() {
  const { data, isLoading } = useNotes();
  return <>{data.map(note => <NoteCard note={note} />)}</>;
}

// Presentational component (pure display)
function NoteCard({ note }) {
  return <div>{note.title}</div>;
}
```

### 2. Data Fetching with React Query

We use **TanStack React Query** for all server data:

```tsx
// Custom hook wrapping React Query
function useNotes() {
  return useQuery({
    queryKey: ['notes'],           // Unique identifier for caching
    queryFn: notesApi.getNotes,    // Function that fetches data
    staleTime: 5 * 60 * 1000,      // Data considered fresh for 5 minutes
    retry: 2,                      // Retry failed requests twice
  });
}

// Component usage
function MyComponent() {
  const { data, isLoading, error } = useNotes();
  
  if (isLoading) return <LoadingSpinner />;
  if (error) return <ErrorMessage error={error} />;
  
  return <div>{data.map(...)}</div>;
}
```

**Benefits:**
- Automatic caching and deduplication
- Background refetching
- Optimistic updates
- Parallel queries
- Less boilerplate code

### 3. Authentication Flow

```
1. User enters credentials
   ↓
2. Component calls authApi.signIn()
   ↓
3. authApi sends request to AWS Cognito
   ↓
4. Cognito validates and returns JWT tokens
   ↓
5. Store token in localStorage
   ↓
6. api-client.ts automatically adds token to all requests
   ↓
7. User is redirected to dashboard
```

### 4. API Client Pattern

All API calls go through a centralized client:

```tsx
// api-client.ts - Configured once
const client = axios.create({
  baseURL: VITE_API_URL,
  // Automatically adds auth token to all requests
});

// notes-api.ts - Uses the client
export const notesApi = {
  getNotes: () => client.get('/notes'),
  createNote: (data) => client.post('/notes', data),
  // ...
};

// Component - Calls the API through React Query
const { mutate } = useMutation({
  mutationFn: notesApi.createNote
});
```

### 5. State Management Strategy

- **Server State** (API data) → React Query
- **Auth State** (user, token) → React Context
- **UI State** (modals, forms) → Local `useState`
- **URL State** (search, filters) → React Router params

**Why this approach?**
- Each tool handles what it does best
- No Redux complexity for simple apps
- Server state stays in sync with backend
- UI state stays local to components

---

## 📜 Available Scripts

### Development

```bash
npm run dev              # Start dev server on http://localhost:5173
npm run build            # Build for production (outputs to dist/)
npm run preview          # Preview production build locally
npm run lint             # Run ESLint to check code quality
```

### Testing

```bash
npm run test             # Run all tests with Vitest
npm run test:watch       # Run tests in watch mode (re-runs on file changes)
npm run test:ui          # Open Vitest UI for interactive testing
npm run test:coverage    # Generate test coverage report
```

### Type Checking

```bash
npm run type-check       # Run TypeScript compiler (tsc) to check types
```

---

## 🔧 Environment Configuration

### Environment Variables

All environment variables must be prefixed with `VITE_` to be exposed to the frontend.

#### Required Variables

```env
# Backend API
VITE_API_URL=              # Your API Gateway URL

# AWS Cognito
VITE_AWS_REGION=           # AWS region (e.g., us-east-1)
VITE_USER_POOL_ID=         # Cognito User Pool ID
VITE_USER_POOL_CLIENT_ID=  # Cognito App Client ID
```

#### Optional Variables

```env
# Feature Flags
VITE_ENABLE_ANALYTICS=false
VITE_ENABLE_DEBUG_MODE=false

# API Settings
VITE_API_TIMEOUT=30000     # Request timeout in milliseconds
```

### Accessing Variables in Code

```tsx
const apiUrl = import.meta.env.VITE_API_URL;
const isDev = import.meta.env.DEV;  // Built-in: true in dev mode
const isProd = import.meta.env.PROD; // Built-in: true in production
```

---

## 🧪 Testing

We use **Vitest** + **React Testing Library** for testing.

### Test File Naming

- `*.test.ts` or `*.test.tsx` - Test files
- Place tests next to the files they test

Example:
```
src/hooks/
├── useNotes.ts
└── useNotes.test.ts
```

### Writing Tests

```tsx
import { render, screen } from '@testing-library/react';
import { NoteCard } from './NoteCard';

describe('NoteCard', () => {
  it('displays note title', () => {
    const note = { id: '1', title: 'Test Note', content: 'Content' };
    
    render(<NoteCard note={note} />);
    
    expect(screen.getByText('Test Note')).toBeInTheDocument();
  });
});
```

### Running Tests

```bash
# Run all tests
npm run test

# Watch mode (auto-rerun on changes)
npm run test:watch

# With coverage
npm run test:coverage
```

---

## 📝 Code Style & Patterns

### Component Structure

Follow this order in component files:

```tsx
// 1. Imports
import { useState } from 'react';
import { Button } from './ui/button';

// 2. Types/Interfaces
interface Props {
  title: string;
  onSave: () => void;
}

// 3. Component
export function MyComponent({ title, onSave }: Props) {
  // 3a. Hooks (always at the top)
  const [value, setValue] = useState('');
  const { data } = useQuery(...);
  
  // 3b. Derived state and handlers
  const isValid = value.length > 0;
  const handleSubmit = () => { ... };
  
  // 3c. Effects (if needed)
  useEffect(() => { ... }, []);
  
  // 3d. JSX return
  return <div>...</div>;
}
```

### Naming Conventions

- **Components**: PascalCase (`NoteCard`, `UserProfile`)
- **Files**: PascalCase for components (`NoteCard.tsx`), camelCase for utils (`formatDate.ts`)
- **Hooks**: camelCase starting with `use` (`useNotes`, `useAuth`)
- **Functions**: camelCase (`handleClick`, `fetchData`)
- **Constants**: UPPER_SNAKE_CASE (`API_TIMEOUT`, `MAX_RETRIES`)

### TypeScript Guidelines

- Always define prop types with interfaces
- Use `type` for unions/intersections, `interface` for objects
- Avoid `any` - use `unknown` if type is truly unknown
- Enable strict mode in `tsconfig.json`

### React Query Patterns

```tsx
// Query (fetching data)
const { data, isLoading, error } = useQuery({
  queryKey: ['notes', id],  // Include all variables that affect the query
  queryFn: () => notesApi.getNote(id),
  enabled: !!id,           // Only run if id exists
});

// Mutation (creating/updating/deleting data)
const { mutate, isPending } = useMutation({
  mutationFn: notesApi.createNote,
  onSuccess: () => {
    queryClient.invalidateQueries({ queryKey: ['notes'] });
  },
});
```

### Styling with Tailwind

```tsx
// Good: Logical grouping
<div className="
  flex items-center gap-4
  px-4 py-2
  bg-white dark:bg-gray-800
  rounded-lg shadow-md
">

// Avoid: Long unreadable strings
<div className="flex items-center gap-4 px-4 py-2 bg-white dark:bg-gray-800 rounded-lg shadow-md hover:shadow-lg transition-shadow">
```

For complex styles, extract to a separate class or component.

---

## 🐛 Troubleshooting

### Common Issues

#### 1. "Cannot find module" errors

```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

#### 2. Port 5173 already in use

```bash
# Kill the process using port 5173
npx kill-port 5173

# Or specify a different port
npm run dev -- --port 3000
```

#### 3. Environment variables not working

- Ensure variables are prefixed with `VITE_`
- Restart dev server after changing `.env`
- Check that `.env` is in the `frontend/` directory

#### 4. "401 Unauthorized" errors

- Check that your JWT token is valid
- Clear localStorage: `localStorage.clear()` in browser console
- Sign in again

#### 5. CORS errors

- Backend API must have CORS configured
- Check that `VITE_API_URL` points to correct backend

#### 6. Amplify configuration errors

```bash
# Verify AWS Cognito credentials in .env
VITE_AWS_REGION=us-east-1
VITE_USER_POOL_ID=us-east-1_XXXXXXXXX
VITE_USER_POOL_CLIENT_ID=your-client-id
```

---

## 📚 Learning Resources

### Documentation
- [React Docs](https://react.dev/) - Official React documentation
- [Vite Guide](https://vitejs.dev/guide/) - Vite build tool
- [TanStack Query](https://tanstack.com/query/latest) - Data fetching
- [Tailwind CSS](https://tailwindcss.com/docs) - Styling
- [React Router](https://reactrouter.com/) - Routing
- [AWS Amplify](https://docs.amplify.aws/) - Authentication

---

## 📄 License

This project is private and proprietary.

---

## 📞 Support

For questions or issues:
1. Check this README and inline code comments
2. Review the troubleshooting section
3. Check browser console for errors
4. Review backend API logs

---