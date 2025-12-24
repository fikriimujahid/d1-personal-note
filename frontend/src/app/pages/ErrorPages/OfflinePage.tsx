import React from 'react';
import { WifiOff, RefreshCw } from 'lucide-react';
import { Button } from '../../components/ui/button';

export function OfflinePage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <div className="text-center space-y-6 max-w-md">
        <div className="rounded-full bg-muted p-6 inline-block">
          <WifiOff className="h-16 w-16 text-muted-foreground" />
        </div>
        <div className="space-y-2">
          <h2 className="text-3xl">You're Offline</h2>
          <p className="text-muted-foreground">
            It looks like you've lost your internet connection. Please check your network and try again.
          </p>
        </div>
        <Button onClick={() => window.location.reload()} size="lg">
          <RefreshCw className="mr-2 h-5 w-5" />
          Retry
        </Button>
      </div>
    </div>
  );
}
