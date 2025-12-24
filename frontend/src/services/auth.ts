import type {
  SignInCredentials,
  SignUpCredentials,
  ResetPasswordRequest,
  ConfirmCodeRequest,
  User,
  ApiResponse
} from '../types';
import {
  signIn,
  signUp,
  signOut,
  resetPassword,
  confirmResetPassword,
  getCurrentUser,
  fetchUserAttributes,
  fetchAuthSession,
  confirmSignUp
} from 'aws-amplify/auth';

// Helper to get user details from Cognito
async function getUserDetails(): Promise<User> {
  const currentUser = await getCurrentUser();
  const attributes = await fetchUserAttributes();

  return {
    id: currentUser.userId,
    email: attributes.email || '',
    name: attributes.name || '',
    createdAt: new Date().toISOString()
  };
}

// Auth API
export const authApi = {
  async signIn(credentials: SignInCredentials): Promise<ApiResponse<{ user: User; token: string }>> {
    try {
      const { isSignedIn, nextStep } = await signIn({
        username: credentials.email,
        password: credentials.password,
      });

      if (isSignedIn) {
        const session = await fetchAuthSession();
        const token = session.tokens?.idToken?.toString() || '';
        const user = await getUserDetails();

        return {
          success: true,
          data: { user, token }
        };
      } else {
        throw new Error(`Sign in not complete. Step: ${nextStep.signInStep}`);
      }
    } catch (error: any) {
      throw error;
    }
  },

  async signUp(credentials: SignUpCredentials): Promise<ApiResponse<{ user: User }>> {
    try {
      const { userId } = await signUp({
        username: credentials.email,
        password: credentials.password,
        options: {
          userAttributes: {
            email: credentials.email,
            name: credentials.name,
          }
        }
      });

      const user: User = {
        id: userId || '',
        email: credentials.email,
        name: credentials.name,
        createdAt: new Date().toISOString()
      };

      return {
        success: true,
        data: { user }
      };
    } catch (error: any) {
      throw error;
    }
  },

  async confirmSignUp(email: string, code: string): Promise<ApiResponse<{ message: string }>> {
    try {
      await confirmSignUp({
        username: email,
        confirmationCode: code
      });
      return {
        success: true,
        data: { message: 'Account verified successfully' }
      };
    } catch (error: any) {
      throw error;
    }
  },

  async forgotPassword(request: ResetPasswordRequest): Promise<ApiResponse<{ message: string }>> {
    try {
      await resetPassword({ username: request.email });
      return {
        success: true,
        data: { message: `Password reset code sent to ${request.email}` }
      };
    } catch (error: any) {
      throw error;
    }
  },

  async confirmCode(request: ConfirmCodeRequest): Promise<ApiResponse<{ message: string }>> {
    try {
      await confirmResetPassword({
        username: request.email,
        confirmationCode: request.code,
        newPassword: request.newPassword
      });
      return {
        success: true,
        data: { message: 'Password reset successful' }
      };
    } catch (error: any) {
      throw error;
    }
  },

  async signOut(): Promise<ApiResponse<null>> {
    try {
      await signOut();
      return { success: true, data: null };
    } catch (error: any) {
      return { success: true, data: null };
    }
  },

  async getCurrentUser(): Promise<ApiResponse<User>> {
    try {
      const user = await getUserDetails();
      return {
        success: true,
        data: user
      };
    } catch (error: any) {
      throw new Error('Not authenticated');
    }
  }
};
