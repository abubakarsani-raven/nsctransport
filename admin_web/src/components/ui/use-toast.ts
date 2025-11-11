"use client";

import { useToastInternal } from "./toast";

export function useToast() {
  const { show } = useToastInternal();
  return {
    toast: show,
    success: (message: string, title = "Success") => show({ variant: "success", title, description: message }),
    error: (message: string, title = "Error") => show({ variant: "error", title, description: message }),
    warn: (message: string, title = "Warning") => show({ variant: "warning", title, description: message }),
  };
}



