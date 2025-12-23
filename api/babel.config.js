/**
 * Babel Configuration
 * 
 * PURPOSE: Transform TypeScript to JavaScript for Jest tests
 * 
 * WHY BABEL?
 * - Jest doesn't understand TypeScript natively
 * - Babel transforms TS → JS during test execution
 * - Fast transformation (no type checking during tests)
 * 
 * NOTE: TypeScript compiler (tsc) handles production builds
 */

module.exports = {
  presets: [
    // Transform modern JavaScript to Node.js compatible code
    ['@babel/preset-env', { targets: { node: 'current' } }],
    
    // Transform TypeScript syntax
    '@babel/preset-typescript',
  ],
};
