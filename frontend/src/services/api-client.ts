/**
 * API Client — Centralized HTTP Client for Backend Communication
 * 
 * This file creates a single, configured axios instance that all API calls use.
 * Why? To avoid repeating configuration (base URL, auth headers) everywhere.
 * 
 * What this file does:
 * 1. Creates an axios client with base configuration
 * 2. Automatically adds JWT auth tokens to every request
 * 3. Handles authentication failures (401 errors) globally
 * 
 * Libraries used:
 * - axios: HTTP client for making API requests (alternative to fetch API)
 */

import axios, { AxiosError, AxiosResponse } from 'axios';

/**
 * Create the axios client instance
 * 
 * axios.create() returns a new axios instance with custom defaults.
 * This is better than using axios directly because we can configure
 * base settings once and reuse them across all API calls.
 */
const client = axios.create({
  // baseURL: The root URL for all API requests
  // Example: If baseURL is "https://api.example.com" and you call client.get('/notes'),
  // the full URL becomes "https://api.example.com/notes"
  // import.meta.env.VITE_API_URL comes from .env file (Vite environment variable)
  baseURL: import.meta.env.VITE_API_URL,

  // headers: Default HTTP headers sent with every request
  headers: {
    // Tell the server we're sending JSON data
    'Content-Type': 'application/json',
  },
});

/**
 * REQUEST INTERCEPTOR: Automatically Add JWT Token to Every Request
 * 
 * What is an interceptor?
 * It's a function that runs BEFORE every HTTP request is sent.
 * Think of it as middleware that can modify requests.
 * 
 * Why do we need this?
 * Most backend APIs require authentication. Instead of manually adding
 * the auth token to every single API call, we do it once here.
 * 
 * How it works:
 * 1. User logs in → JWT token is saved to localStorage
 * 2. Before each API request → this interceptor runs
 * 3. It reads the token from localStorage
 * 4. It adds the token to the Authorization header
 * 5. The request continues with the auth token attached
 */
client.interceptors.request.use((config) => {
  // Retrieve the JWT token from browser's localStorage
  // localStorage is a simple key-value storage in the browser
  // The key 'idToken' was set when the user logged in
  const token = localStorage.getItem('idToken');

  // Only add the Authorization header if a token exists
  // This prevents sending "Authorization: Bearer null" when logged out
  if (token) {
    // Authorization header format: "Bearer <token>"
    // This is the standard way to send JWT tokens
    // The backend will read this header to verify the user's identity
    config.headers.Authorization = `Bearer ${token}`;
  }

  // Return the modified config so the request continues
  return config;
});

/**
 * RESPONSE INTERCEPTOR: Handle Authentication Failures Globally
 * 
 * What is a response interceptor?
 * It runs AFTER the server responds to a request.
 * It can handle both successful responses and errors.
 * 
 * Why do we need this?
 * When a JWT token expires or becomes invalid, the backend returns
 * a 401 (Unauthorized) status code. Instead of handling this in every
 * component, we handle it once here.
 * 
 * How it works:
 * - Success path: Just return the response unchanged
 * - Error path: Check if error is 401, then log out the user
 */
client.interceptors.response.use(
  // Success handler: Request succeeded (status 200-299)
  // We don't need to do anything special, just pass the response through
  (response: AxiosResponse) => response,

  // Error handler: Request failed (status 400+, network error, etc.)
  (error: AxiosError) => {
    // Check if the error is a 401 Unauthorized error
    // error.response?.status uses optional chaining (?.) because
    // error.response might not exist (e.g., network failure)
    if (error.response?.status === 401) {
      // 401 means: "Your token is expired or invalid"
      // What we do:
      // 1. Remove the invalid token from localStorage (clean up)
      localStorage.removeItem('idToken');

      // 2. Redirect user back to login page
      // window.location.href forces a full page reload to '/'
      // This ensures all app state is cleared and user must log in again
      window.location.href = '/';
    }

    // Re-throw the error so calling code can still handle it
    // This allows components to show error messages if needed
    return Promise.reject(error);
  }
);

/**
 * Export the configured client
 * 
 * Other files import this client to make API calls:
 * 
 * Example usage:
 * import client from './api-client';
 * const response = await client.get('/notes');
 * const notes = response.data;
 * 
 * The client automatically:
 * - Uses the correct base URL
 * - Adds the auth token
 * - Handles 401 errors
 */
export default client;