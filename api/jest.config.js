/**
 * Jest Configuration for TypeScript
 * 
 * PURPOSE: Configure Jest to run TypeScript tests
 * 
 * LAMBDA TESTING CONTEXT:
 * - Tests run locally (not in AWS)
 * - TypeScript needs to be transformed to JavaScript
 * - Fast execution for rapid development
 */

module.exports = {
  // Use Babel to transform TypeScript files
  transform: {
    '^.+\\.ts$': 'babel-jest',
  },

  // File extensions Jest will look for
  moduleFileExtensions: ['ts', 'js', 'json'],

  // Test file patterns
  testMatch: [
    '**/tests/**/*.test.ts',
    '**/__tests__/**/*.ts',
  ],

  // Coverage collection (optional but recommended)
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
  ],

  // Test environment (Node.js for Lambda)
  testEnvironment: 'node',

  // Clear mocks between tests (prevents test pollution)
  clearMocks: true,

  // Verbose output for better debugging
  verbose: true,
};
