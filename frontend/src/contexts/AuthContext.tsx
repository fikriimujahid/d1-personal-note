import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import type { User, SignInCredentials, SignUpCredentials } from '../types';
import { authApi } from '../services/auth';
import { toast } from 'sonner'; // Toast notifications library for user feedback

/**
 * AuthContext: Global Authentication State
 * 
 * This context provides authentication state and methods to all components in the app.
 * Using React Context prevents "prop drilling" - passing auth data through every component.
 * 
 * Why Context here?
 * - Authentication state needs to be accessible everywhere (nav bar, protected routes, etc.)
 * - Multiple components need to trigger auth actions (sign in form, sign out button, etc.)
 * - Centralizes auth logic in one place instead of duplicating across components
 */

/**
 * AuthContextType: The shape of data provided by this context
 * 
 * This interface defines what any component can access when using useAuth()
 */
interface AuthContextType {
  // Current user object (null if not logged in)
  user: User | null;
  
  // Derived state - true if we have a user object
  // Useful for conditional rendering: {isAuthenticated ? <Dashboard /> : <Login />}
  isAuthenticated: boolean;
  
  // Loading state while checking if user is already logged in on app start
  // Prevents flash of login screen before we verify existing session
  isLoading: boolean;
  
  // Auth actions - all async because they make API calls
  signIn: (credentials: SignInCredentials) => Promise<void>;
  signUp: (credentials: SignUpCredentials) => Promise<void>;
  confirmSignUp: (email: string, code: string) => Promise<void>;
  signOut: () => Promise<void>;
  
  // Manually refresh user data (useful after profile updates)
  refreshUser: () => Promise<void>;
}

/**
 * Create the context with undefined as initial value
 * undefined = "context not yet provided" (helps catch usage outside provider)
 */
const AuthContext = createContext<AuthContextType | undefined>(undefined);

/**
 * AuthProvider: The component that wraps your app and provides auth state
 * 
 * Usage in main.tsx or App.tsx:
 *   <AuthProvider>
 *     <YourApp />
 *   </AuthProvider>
 * 
 * This makes auth state available to all child components via useAuth() hook
 */
export function AuthProvider({ children }: { children: ReactNode }) {
  // ===== STATE MANAGEMENT =====
  // Local state for current user (null = not logged in)
  const [user, setUser] = useState<User | null>(null);
  
  // Loading state - true while checking for existing session on mount
  // Starts as true because we need to check localStorage for existing token
  const [isLoading, setIsLoading] = useState(true);

  /**
   * useEffect: Check for existing auth session when app loads
   * 
   * Why: User might already be logged in (token in localStorage)
   * When: Runs once on component mount (empty dependency array [])
   * 
   * Flow:
   * 1. App loads
   * 2. This effect runs immediately
   * 3. checkAuth() looks for stored token
   * 4. If found, fetches user data from API
   * 5. Sets isLoading to false (show app content)
   */
  useEffect(() => {
    checkAuth();
  }, []); // Empty array = run once on mount, never again

  /**
   * checkAuth: Verify if user is already logged in
   * 
   * Called automatically on app load to restore session
   * 
   * Authentication Flow:
   * 1. Check localStorage for saved token (persists across page refreshes)
   * 2. If token exists, ask API "who is this token for?"
   * 3. API validates token and returns user data
   * 4. Store user data in state -> user is logged in
   * 
   * Error Handling:
   * - If token is invalid/expired, API throws error
   * - Catch block removes bad token from storage
   * - User stays logged out (user = null)
   * 
   * Finally Block:
   * - Always runs, success or fail
   * - Sets isLoading = false so app can render
   * - Prevents infinite loading spinner
   */
  async function checkAuth() {
    try {
      // Check localStorage for JWT token saved from previous login
      // localStorage persists even after browser closes
      const token = localStorage.getItem('idToken');
      
      if (token) {
        // Token exists - verify it's still valid by fetching user data
        // authApi automatically includes token in request headers
        const response = await authApi.getCurrentUser();
        
        // If API confirms token is valid, restore user session
        if (response.success && response.data) {
          setUser(response.data); // This makes isAuthenticated = true
        }
      }
      // If no token found, user stays null (logged out state)
      
    } catch (error) {
      // Token was invalid or API request failed
      // Clean up by removing the bad token
      localStorage.removeItem('idToken');
      // user remains null = logged out
      
    } finally {
      // Always execute, regardless of success/failure
      // Stop showing loading spinner, let app render
      setIsLoading(false);
    }
  }

  /**
   * signIn: Authenticate user with email and password
   * 
   * Called by: Login form when user submits credentials
   * 
   * User Flow:
   * 1. User types email/password, clicks "Sign In"
   * 2. Form calls signIn(credentials)
   * 3. API validates credentials against user database
   * 4. If valid, API returns JWT token + user data
   * 5. We save token to localStorage (for auto-login next time)
   * 6. We save user to state (app switches to logged-in view)
   * 7. Toast shows success message
   * 
   * Why pre-sign-out?
   * - Clears any stale session from backend
   * - Ensures clean slate for new login
   * - Prevents "already logged in" errors
   * 
   * Error Handling:
   * - Wrong password? API throws error
   * - Network down? Fetch throws error
   * - Show error to user via toast
   * - Re-throw so calling component knows it failed
   */
  async function signIn(credentials: SignInCredentials) {
    try {
      // Clean up any existing session on the backend first
      // We wrap this in its own try-catch because:
      // - It might fail if no session exists (that's fine, we ignore it)
      // - We don't want this failure to stop the sign-in process
      try {
        await authApi.signOut();
      } catch {
        // Silently ignore - no existing session to clear is OK
      }
      
      // Make API call with user's email and password
      // API checks credentials against database
      const response = await authApi.signIn(credentials);
      
      if (response.success && response.data) {
        // Authentication successful! We have a valid JWT token
        
        // Save token to localStorage for persistence
        // Next time user opens app, checkAuth() will find this token
        localStorage.setItem('idToken', response.data.token);
        
        // Update state with user data
        // This triggers re-render, app shows logged-in UI
        setUser(response.data.user);
        
        // Show success notification to user
        toast.success('Welcome back!');
      }
      
    } catch (error) {
      // Login failed - show error to user
      // Could be: wrong password, network error, server down, etc.
      toast.error((error as Error).message || 'Sign in failed');
      
      // Re-throw error so calling component knows login failed
      // Component can show error state, stay on login form, etc.
      throw error;
    }
  }

  /**
   * signUp: Create a new user account
   * 
   * Called by: Registration form when user wants to create account
   * 
   * User Flow:
   * 1. User fills out registration form (email, password, name)
   * 2. Form calls signUp(credentials)
   * 3. API creates new user in database
   * 4. API sends verification email with confirmation code
   * 5. User must confirm email before they can sign in
   * 
   * Note: signUp does NOT log the user in
   * - User must verify email first (confirmSignUp)
   * - Then user must sign in (signIn)
   * - This is a security best practice
   * 
   * Why not set user state here?
   * - Account is created but not verified yet
   * - User stays logged out until they verify + sign in
   */
  async function signUp(credentials: SignUpCredentials) {
    try {
      // Create new user account via API
      // API will send verification email to user
      const response = await authApi.signUp(credentials);
      
      if (response.success) {
        // Account created successfully
        // User needs to check email for verification code
        toast.success('Account created! Please check your email for the verification code.');
        // Note: user is still null (not logged in)
      }
      
    } catch (error) {
      // Account creation failed
      // Common reasons: email already exists, weak password, invalid email
      toast.error((error as Error).message || 'Sign up failed');
      throw error; // Let calling component handle the error state
    }
  }

  /**
   * confirmSignUp: Verify email with confirmation code
   * 
   * Called by: Verification form after user signs up
   * 
   * User Flow:
   * 1. User signs up (signUp function)
   * 2. User receives email with 6-digit code
   * 3. User enters code in verification form
   * 4. Form calls confirmSignUp(email, code)
   * 5. API verifies code matches what was sent
   * 6. Account is now verified and can sign in
   * 
   * Why separate from signUp?
   * - Email verification is a security measure
   * - Confirms user owns the email address
   * - Prevents spam accounts
   * 
   * Next Step:
   * - User must still sign in (we don't auto-login after verification)
   * - This keeps the flow simple and secure
   */
  async function confirmSignUp(email: string, code: string) {
    try {
      // Send verification code to API for validation
      // API checks if code matches what was sent to this email
      const response = await authApi.confirmSignUp(email, code);
      
      if (response.success) {
        // Email verified successfully!
        // Account is now active and can be used to sign in
        toast.success('Account verified! Please sign in.');
        // Note: user is still null - they need to sign in now
      }
      
    } catch (error) {
      // Verification failed
      // Common reasons: wrong code, expired code, already verified
      toast.error((error as Error).message || 'Verification failed');
      throw error; // Let form component show error state
    }
  }

  /**
   * signOut: Log out current user
   * 
   * Called by: Sign out button in nav bar or settings
   * 
   * User Flow:
   * 1. User clicks "Sign Out" button
   * 2. Component calls signOut()
   * 3. API invalidates session on server
   * 4. We remove token from localStorage (no auto-login next time)
   * 5. We clear user state (app switches to logged-out view)
   * 6. User redirected to login page (usually by router logic)
   * 
   * Why 3 steps?
   * 1. authApi.signOut() - tell server to invalidate session
   * 2. localStorage.removeItem() - clear local token
   * 3. setUser(null) - update React state
   * 
   * If we only did #3:
   * - User would be "logged out" in UI
   * - But token still works for API calls
   * - Security risk!
   */
  async function signOut() {
    try {
      // Tell API to invalidate the session on server side
      // This prevents the token from being used again
      await authApi.signOut();
      
      // Remove token from localStorage
      // Prevents automatic login on next app load
      localStorage.removeItem('idToken');
      
      // Clear user from state
      // This triggers re-render, app shows logged-out UI (login page)
      setUser(null);
      
      // Notify user
      toast.success('Signed out successfully');
      
    } catch (error) {
      // Sign out failed (maybe network error)
      // Even if API call fails, we should still clear local state
      // We don't re-throw because sign out should always "succeed" locally
      toast.error('Sign out failed');
    }
  }

  /**
   * refreshUser: Manually fetch latest user data from API
   * 
   * Called by: Profile page after user updates their info
   * 
   * Use Case:
   * - User updates profile (name, email, avatar, etc.)
   * - Profile update succeeds on server
   * - Call refreshUser() to sync local state with server
   * - UI updates to show new data
   * 
   * Why needed?
   * - User state in context might be stale
   * - Server has the source of truth
   * - This pulls latest data from server
   * 
   * Alternative approach:
   * - We could manually update user state locally
   * - But fetching from server ensures we have correct data
   * - Handles edge cases (concurrent updates, etc.)
   */
  async function refreshUser() {
    try {
      // Fetch current user data from API
      // Uses existing token, same as checkAuth()
      const response = await authApi.getCurrentUser();
      
      if (response.success && response.data) {
        // Update state with fresh user data from server
        setUser(response.data);
      }
      
    } catch (error) {
      // Silently fail - this is a "nice to have" refresh
      // If it fails, user sees slightly stale data (not critical)
      // We don't show error toast to avoid annoying user
      // We don't throw because this is background operation
    }
  }

  // ===== CONTEXT PROVIDER =====
  /**
   * Return the provider component that makes auth state available to children
   * 
   * value prop: Object with all state and functions we want to share
   * 
   * Breakdown:
   * - user: Current user object (null if not logged in)
   * - isAuthenticated: Computed boolean (true if user exists)
   *   Why compute? More readable than checking `user !== null` everywhere
   *   !! converts truthy/falsy to boolean: !!user means "is user truthy?"
   * - isLoading: Still checking for existing session?
   * - All the auth functions: signIn, signUp, etc.
   * 
   * How children access this:
   *   In any child component: const { user, signIn } = useAuth();
   */
  return (
    <AuthContext.Provider
      value={{
        user,                      // Current user object or null
        isAuthenticated: !!user,   // Convert user to boolean (true if user exists)
        isLoading,                 // Still checking for existing session
        signIn,                    // Login function
        signUp,                    // Registration function
        confirmSignUp,             // Email verification function
        signOut,                   // Logout function
        refreshUser,               // Refresh user data function
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

/**
 * useAuth: Custom hook to access auth context
 * 
 * Usage in any component:
 *   const { user, signIn, signOut } = useAuth();
 * 
 * Why a custom hook?
 * - Simpler than useContext(AuthContext) everywhere
 * - Provides helpful error if used outside provider
 * - Single source of truth for accessing auth
 * 
 * Error Handling:
 * - If context is undefined, hook is used outside AuthProvider
 * - This is a developer mistake, not runtime issue
 * - Throw error immediately to help debug
 * 
 * Example error scenario:
 *   Bad: Using useAuth() outside AuthProvider will crash with helpful error
 *   function MyComponent() {
 *     const { user } = useAuth(); // Error: useAuth must be used within an AuthProvider
 *   }
 * 
 *   Good: Wrap components in AuthProvider first
 *   AuthProvider wraps MyComponent, then useAuth() works correctly
 */
export function useAuth() {
  // Get the context value provided by <AuthProvider>
  const context = useContext(AuthContext);
  
  // Safety check: ensure we're inside a provider
  // context === undefined means no provider in component tree above us
  if (context === undefined) {
    // Throw error with helpful message
    // This helps developers catch mistakes early
    throw new Error('useAuth must be used within an AuthProvider');
  }
  
  // Return the context value (all auth state and functions)
  return context;
}
