"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, useEffect } from "react";
import { ThemeProvider } from "@/components/theme-provider";
import { ToastProvider, useToastInternal } from "@/components/ui/toast";

// Global toast callback - set by ToastContextSetter
let globalToastCallback: ((message: string) => void) | null = null;

export function setGlobalToastCallback(callback: (message: string) => void) {
  globalToastCallback = callback;
}

// Component that configures QueryClient with toast error handling
function QueryClientWithToast({ children }: { children: React.ReactNode }) {
  const [client] = useState(() => {
    return new QueryClient({
      defaultOptions: {
        queries: {
          retry: 1,
          // Note: onError removed in React Query v5 - handle errors at query level
        },
        mutations: {
          // Note: onError removed in React Query v5 - handle errors at mutation level
        },
      },
    });
  });

  return (
    <ToastProvider>
      <ToastContextSetter />
      <QueryClientProvider client={client}>{children}</QueryClientProvider>
    </ToastProvider>
  );
}

// Component to set the toast callback from context
function ToastContextSetter() {
  const toast = useToastInternal();
  
  useEffect(() => {
    setGlobalToastCallback((message: string) => {
      toast.show({
        variant: "error",
        title: "Error",
        description: message,
      });
    });
  }, [toast]);

  return null;
}

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="light" enableSystem={false}>
      <QueryClientWithToast>{children}</QueryClientWithToast>
    </ThemeProvider>
  );
}


