import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import type { User, SignInCredentials, SignUpCredentials } from '../types';
import { authApi } from '../services/auth';
import { toast } from 'sonner';

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  signIn: (credentials: SignInCredentials) => Promise<void>;
  signUp: (credentials: SignUpCredentials) => Promise<void>;
  confirmSignUp: (email: string, code: string) => Promise<void>;
  signOut: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    checkAuth();
  }, []);

  async function checkAuth() {
    try {
      const token = localStorage.getItem('idToken');
      if (token) {
        const response = await authApi.getCurrentUser();
        if (response.success && response.data) {
          setUser(response.data);
        }
      }
    } catch (error) {
      localStorage.removeItem('idToken');
    } finally {
      setIsLoading(false);
    }
  }

  async function signIn(credentials: SignInCredentials) {
    try {
      // Sign out any existing session first
      try {
        await authApi.signOut();
      } catch {
        // Ignore errors if no session exists
      }
      
      const response = await authApi.signIn(credentials);
      if (response.success && response.data) {
        localStorage.setItem('idToken', response.data.token);
        setUser(response.data.user);
        toast.success('Welcome back!');
      }
    } catch (error) {
      toast.error((error as Error).message || 'Sign in failed');
      throw error;
    }
  }

  async function signUp(credentials: SignUpCredentials) {
    try {
      const response = await authApi.signUp(credentials);
      if (response.success) {
        toast.success('Account created! Please check your email for the verification code.');
      }
    } catch (error) {
      toast.error((error as Error).message || 'Sign up failed');
      throw error;
    }
  }

  async function confirmSignUp(email: string, code: string) {
    try {
      const response = await authApi.confirmSignUp(email, code);
      if (response.success) {
        toast.success('Account verified! Please sign in.');
      }
    } catch (error) {
      toast.error((error as Error).message || 'Verification failed');
      throw error;
    }
  }

  async function signOut() {
    try {
      await authApi.signOut();
      localStorage.removeItem('idToken');
      setUser(null);
      toast.success('Signed out successfully');
    } catch (error) {
      toast.error('Sign out failed');
    }
  }

  async function refreshUser() {
    try {
      const response = await authApi.getCurrentUser();
      if (response.success && response.data) {
        setUser(response.data);
      }
    } catch (error) {
    }
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        isAuthenticated: !!user,
        isLoading,
        signIn,
        signUp,
        confirmSignUp,
        signOut,
        refreshUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
