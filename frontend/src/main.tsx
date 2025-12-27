
/**
 * ENTRY POINT - This is where the entire React application starts
 * 
 * What happens in this file:
 * 1. Import React and necessary libraries
 * 2. Configure AWS Amplify for user authentication
 * 3. Mount the React app to the HTML DOM
 * 
 * This file runs ONCE when the browser loads index.html
 */

// ============================================================================
// IMPORTS - Bring in code from other files
// ============================================================================

// React 18's createRoot - modern way to initialize a React app
// Why: React 18 introduced concurrent rendering for better performance
// Old way: ReactDOM.render() (deprecated)
// New way: createRoot() (what we use here)
import { createRoot } from "react-dom/client";

// AWS Amplify - authentication library from Amazon
// Why: We use AWS Cognito for secure user login/signup
// Amplify connects our frontend to AWS services
import { Amplify } from "aws-amplify";

// Our main App component - the root of our component tree
// This contains all pages, routing, and UI logic
import App from "./app/App.tsx";

// Global CSS styles - loaded once for the entire app
// Includes: Tailwind utility classes, custom theme, fonts
// Why import CSS in JS: Vite bundles it into the build
import "./styles/index.css";

// ============================================================================
// AWS AMPLIFY CONFIGURATION - Run BEFORE React renders
// ============================================================================

// Configure Amplify to connect to our AWS Cognito user pool
// This MUST happen before <App /> renders, otherwise auth won't work
// 
// What is Cognito?
// - AWS's user management service (like Firebase Auth)
// - Handles signup, login, password reset, tokens, etc.
// 
// Environment Variables (from .env file):
// - VITE_COGNITO_USER_POOL_ID: Identifies which user database to use
// - VITE_COGNITO_USER_POOL_CLIENT_ID: Identifies THIS specific app
Amplify.configure({
  Auth: {
    Cognito: {
      // User Pool ID - think of it as the "database" of all users
      // Format: us-east-1_ABC123XYZ
      userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID,

      // Client ID - think of it as "app credentials" to access the user pool
      // Why separate from pool ID: One pool can have multiple apps
      userPoolClientId: import.meta.env.VITE_COGNITO_USER_POOL_CLIENT_ID,
    },
  }, 
});

// ============================================================================
// REACT MOUNTING - Attach React to the HTML DOM
// ============================================================================

// Step 1: Find the HTML element where React will live
// In index.html there's: <div id="root"></div>
// This is where ALL React components will be inserted
// 
// The "!" (non-null assertion) tells TypeScript:
// "I guarantee this element exists, don't warn me"
// If it doesn't exist, the app will crash (which is correct behavior)
const rootElement = document.getElementById("root")!;

// Step 2: Create a React 18 "root" and render our app
// createRoot(): Initializes React's concurrent rendering engine
// .render(): Tells React to mount <App /> inside rootElement
// 
// What happens next:
// 1. React creates a virtual DOM representation of <App />
// 2. React figures out what HTML to generate
// 3. React inserts that HTML into <div id="root">
// 4. User sees the app!
// 
// Why <App /> is the only component here:
// - <App /> contains all routing, pages, layouts, etc.
// - This keeps main.tsx simple and focused on initialization
createRoot(rootElement).render(<App />);
