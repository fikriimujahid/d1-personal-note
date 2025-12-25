/**
 * Authentication Service — AWS Amplify Auth Integration
 * 
 * This file provides authentication functions using AWS Amplify (AWS Cognito).
 * 
 * What is AWS Amplify?
 * It's a library that simplifies using AWS services like Cognito (user authentication).
 * Instead of manually calling AWS APIs, Amplify provides easy-to-use functions.
 * 
 * What is AWS Cognito?
 * It's AWS's managed authentication service that handles:
 * - User sign up and sign in
 * - Password management and resets
 * - Email verification codes
 * - JWT token generation
 * 
 * Why this file exists:
 * - Wraps Amplify auth functions with our app's types
 * - Provides consistent error handling
 * - Returns data in a format our React components expect
 */

import type {
  SignInCredentials,
  SignUpCredentials,
  ResetPasswordRequest,
  ConfirmCodeRequest,
  User,
  ApiResponse
} from '../types';

/**
 * Import AWS Amplify auth functions
 * 
 * These are the building blocks from AWS that handle authentication.
 * We import them from 'aws-amplify/auth' (the Auth module of Amplify).
 */
import {
  signIn,           // Log a user in with email/password
  signUp,           // Create a new user account
  signOut,          // Log a user out
  resetPassword,    // Request password reset (sends code to email)
  confirmResetPassword, // Confirm password reset with code
  getCurrentUser,   // Get the currently logged in user's basic info
  fetchUserAttributes, // Get user details (email, name, etc.)
  fetchAuthSession, // Get the current auth session (includes JWT tokens)
  confirmSignUp     // Verify email with confirmation code
} from 'aws-amplify/auth';

/**
 * HELPER FUNCTION: Get User Details from Cognito
 * 
 * Why is this a separate function?
 * Multiple auth operations need to fetch user details after a successful action.
 * Instead of repeating this code, we extract it into a reusable helper.
 * 
 * What does it do?
 * 1. Gets basic user info (user ID)
 * 2. Gets extended attributes (email, name)
 * 3. Combines them into our app's User type
 * 
 * How Cognito stores user data:
 * - Basic info: userId (unique identifier)
 * - Attributes: key-value pairs like email, name, phone_number
 * 
 * @returns Promise<User> - Our app's User object
 */
async function getUserDetails(): Promise<User> {
  // Step 1: Get basic user info from Cognito
  // This returns: { userId: "abc123...", username: "user@example.com" }
  const currentUser = await getCurrentUser();

  // Step 2: Fetch user attributes (the extra profile data)
  // This returns: { email: "user@example.com", name: "John Doe", ... }
  const attributes = await fetchUserAttributes();

  // Step 3: Transform Cognito data into our app's User type
  return {
    id: currentUser.userId,
    // Use || '' to provide empty string if attribute is undefined
    // This prevents null/undefined values in our User object
    email: attributes.email || '',
    name: attributes.name || '',
    // createdAt: We don't get this from Cognito attributes, so generate current time
    // In a real app, you might store this in a custom attribute or database
    createdAt: new Date().toISOString()
  };
}

/**
 * AUTH API OBJECT
 * 
 * This object exports all authentication functions our app needs.
 * Each function is async and returns a Promise with ApiResponse<T>.
 * 
 * Why use an object instead of separate exports?
 * - Groups related functions together
 * - Easy to import: import { authApi } from './auth'
 * - Clear namespace: authApi.signIn(), authApi.signUp(), etc.
 */
export const authApi = {
  /**
   * SIGN IN — Authenticate a User with Email and Password
   * 
   * Authentication flow:
   * 1. User submits email + password
   * 2. Amplify sends credentials to AWS Cognito
   * 3. Cognito verifies credentials
   * 4. If valid: Returns JWT tokens and user info
   * 5. If invalid: Throws error (wrong password, user not found, etc.)
   * 
   * What is a JWT token?
   * JSON Web Token - a secure string that proves the user is authenticated.
   * The backend API validates this token on each request.
   * 
   * @param credentials - { email: string, password: string }
   * @returns ApiResponse with user data and JWT token
   */
  async signIn(credentials: SignInCredentials): Promise<ApiResponse<{ user: User; token: string }>> {
    try {
      // Call AWS Amplify signIn function
      // Cognito uses "username" field, but we're using email as username
      const { isSignedIn, nextStep } = await signIn({
        username: credentials.email, // Cognito requires 'username' field
        password: credentials.password,
      });

      // Check if sign in was successful
      // isSignedIn = true means authentication is complete
      // Sometimes Cognito requires additional steps (MFA, password change, etc.)
      if (isSignedIn) {
        // Step 1: Get the authentication session (contains JWT tokens)
        // The session includes:
        // - idToken: Identifies who the user is (used in API calls)
        // - accessToken: Grants access to resources
        // - refreshToken: Used to get new tokens when they expire
        const session = await fetchAuthSession();

        // Step 2: Extract the ID token as a string
        // session.tokens?.idToken?.toString() uses optional chaining
        // because tokens might not exist in rare edge cases
        const token = session.tokens?.idToken?.toString() || '';

        // Step 3: Get user details from Cognito
        const user = await getUserDetails();

        // Step 4: Return success response with user and token
        // The calling component will:
        // - Store token in localStorage (for api-client.ts to use)
        // - Store user in React state/context
        return {
          success: true,
          data: { user, token }
        };
      } else {
        // Sign in requires additional steps (MFA, password change, etc.)
        // For this app, we don't handle multi-step auth, so throw error
        throw new Error(`Sign in not complete. Step: ${nextStep.signInStep}`);
      }
    } catch (error: any) {
      // Re-throw the error so calling component can handle it
      // Error might be: "User does not exist", "Incorrect password", etc.
      // The calling component will display this error to the user
      throw error;
    }
  },

  /**
   * SIGN UP — Create a New User Account
   * 
   * Registration flow:
   * 1. User submits email, password, and name
   * 2. Amplify sends registration request to Cognito
   * 3. Cognito creates the user account
   * 4. Cognito sends verification code to user's email
   * 5. User must verify email before they can sign in (see confirmSignUp)
   * 
   * Why email verification?
   * - Prevents fake accounts
   * - Ensures the email address is valid and owned by the user
   * 
   * @param credentials - { email, password, name }
   * @returns ApiResponse with new user data
   */
  async signUp(credentials: SignUpCredentials): Promise<ApiResponse<{ user: User }>> {
    try {
      // Call AWS Amplify signUp function
      const { userId } = await signUp({
        username: credentials.email, // Email is used as username in Cognito
        password: credentials.password,
        
        // options.userAttributes: Additional profile data to store
        // These are Cognito user attributes that can be retrieved later
        options: {
          userAttributes: {
            email: credentials.email, // Store email as an attribute
            name: credentials.name,   // Store name as an attribute
          }
        }
      });

      // Create our app's User object
      // We manually construct this because the user isn't fully signed in yet
      // (they still need to verify their email)
      const user: User = {
        id: userId || '', // Cognito assigns a unique user ID
        email: credentials.email,
        name: credentials.name,
        createdAt: new Date().toISOString()
      };

      // Return the user data
      // Note: User is NOT authenticated yet - they must verify email first
      return {
        success: true,
        data: { user }
      };
    } catch (error: any) {
      // Common errors:
      // - "User already exists"
      // - "Password does not meet requirements"
      // - "Invalid email format"
      throw error;
    }
  },

  /**
   * CONFIRM SIGN UP — Verify Email with Confirmation Code
   * 
   * This function completes the registration process.
   * 
   * Flow after signUp:
   * 1. User signs up → Cognito sends 6-digit code to their email
   * 2. User enters the code in the app
   * 3. This function sends the code to Cognito for verification
   * 4. If code is correct: Account is verified, user can now sign in
   * 5. If code is wrong: Error is thrown
   * 
   * @param email - The user's email address
   * @param code - The 6-digit verification code from email
   * @returns ApiResponse with success message
   */
  async confirmSignUp(email: string, code: string): Promise<ApiResponse<{ message: string }>> {
    try {
      // Send confirmation code to Cognito
      await confirmSignUp({
        username: email, // Email is used as username
        confirmationCode: code // The 6-digit code from the email
      });

      // Success! User's email is now verified
      return {
        success: true,
        data: { message: 'Account verified successfully' }
      };
    } catch (error: any) {
      // Common errors:
      // - "Code mismatch" (wrong code entered)
      // - "Code expired" (code is only valid for a limited time)
      throw error;
    }
  },

  /**
   * FORGOT PASSWORD — Request Password Reset
   * 
   * This is step 1 of password reset (step 2 is confirmCode below).
   * 
   * Password reset flow:
   * 1. User clicks "Forgot password" and enters their email
   * 2. This function sends request to Cognito
   * 3. Cognito sends a verification code to the user's email
   * 4. User enters code + new password (handled by confirmCode function)
   * 
   * Why the two-step process?
   * Security: Ensures only the email owner can reset the password.
   * The verification code proves they have access to the email account.
   * 
   * @param request - { email: string }
   * @returns ApiResponse with confirmation message
   */
  async forgotPassword(request: ResetPasswordRequest): Promise<ApiResponse<{ message: string }>> {
    try {
      // Request password reset from Cognito
      // This triggers Cognito to send an email with a verification code
      await resetPassword({ username: request.email });

      // Return success message
      // The calling component will show this message and prompt for the code
      return {
        success: true,
        data: { message: `Password reset code sent to ${request.email}` }
      };
    } catch (error: any) {
      // Common error: "User does not exist"
      throw error;
    }
  },

  /**
   * CONFIRM CODE — Complete Password Reset with Code
   * 
   * This is step 2 of password reset (after forgotPassword above).
   * 
   * Flow:
   * 1. User received verification code in email (from forgotPassword)
   * 2. User enters: code + new password
   * 3. This function sends them to Cognito
   * 4. Cognito verifies the code and updates the password
   * 5. User can now sign in with their new password
   * 
   * @param request - { email, code, newPassword }
   * @returns ApiResponse with success message
   */
  async confirmCode(request: ConfirmCodeRequest): Promise<ApiResponse<{ message: string }>> {
    try {
      // Send code and new password to Cognito
      await confirmResetPassword({
        username: request.email,
        confirmationCode: request.code, // The code from the email
        newPassword: request.newPassword // The user's chosen new password
      });

      // Success! Password has been changed
      // User can now sign in with the new password
      return {
        success: true,
        data: { message: 'Password reset successful' }
      };
    } catch (error: any) {
      // Common errors:
      // - "Code mismatch" (wrong code)
      // - "Code expired"
      // - "Password does not meet requirements"
      throw error;
    }
  },

  /**
   * SIGN OUT — Log the User Out
   * 
   * What happens during sign out:
   * 1. Amplify clears the user's session (JWT tokens)
   * 2. Cognito invalidates the refresh token
   * 3. User must sign in again to access protected features
   * 
   * Note: We also clear localStorage in the calling component
   * (removes the idToken that api-client.ts uses)
   * 
   * Why we always return success:
   * Even if signOut fails (e.g., network error), we treat it as success.
   * This ensures the app clears local data and redirects to login.
   * Better to force logout locally than leave user in a broken state.
   * 
   * @returns ApiResponse<null> - Always succeeds
   */
  async signOut(): Promise<ApiResponse<null>> {
    try {
      // Call Amplify signOut to clear Cognito session
      await signOut();
      return { success: true, data: null };
    } catch (error: any) {
      // Even if there's an error, return success
      // The calling component will clear local state regardless
      return { success: true, data: null };
    }
  },

  /**
   * GET CURRENT USER — Fetch Currently Authenticated User
   * 
   * This function checks if a user is logged in and returns their info.
   * 
   * When is this used?
   * - On app startup: Check if user is still logged in
   * - After page refresh: Restore user session
   * - Before accessing protected routes: Verify authentication
   * 
   * How it works:
   * 1. Amplify checks if there's a valid session (unexpired JWT tokens)
   * 2. If valid: Returns user details from Cognito
   * 3. If invalid/expired: Throws error
   * 
   * What about token expiration?
   * Amplify automatically refreshes expired tokens using the refresh token.
   * If refresh fails (refresh token also expired), this throws an error.
   * 
   * @returns ApiResponse<User> - The authenticated user's data
   * @throws Error if user is not authenticated
   */
  async getCurrentUser(): Promise<ApiResponse<User>> {
    try {
      // Fetch user details from Cognito
      // This will throw if there's no valid session
      const user = await getUserDetails();

      return {
        success: true,
        data: user
      };
    } catch (error: any) {
      // No valid session found
      // This happens when:
      // - User is not logged in
      // - Session expired and refresh failed
      // - Tokens were manually cleared
      throw new Error('Not authenticated');
    }
  }
};
