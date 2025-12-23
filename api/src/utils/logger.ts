export const logger = {
  info: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: 'INFO', message, data, timestamp: new Date().toISOString() }));
  },

  error: (message: string, error?: any) => {
    console.error(JSON.stringify({ level: 'ERROR', message, error: error?.message, timestamp: new Date().toISOString() }));
  },

  debug: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: 'DEBUG', message, data, timestamp: new Date().toISOString() }));
  },

  warn: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: 'WARN', message, data, timestamp: new Date().toISOString() }));
  },
};