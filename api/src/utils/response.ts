import { APIGatewayProxyResult } from 'aws-lambda';

const corsHeaders = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
};

export const responseFormatter = {
  success: (body: any, statusCode: number = 200): APIGatewayProxyResult => ({
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body),
  }),

  error: (message: string, statusCode: number = 500): APIGatewayProxyResult => ({
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify({ message }),
  }),
};