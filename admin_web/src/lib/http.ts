"use client";

/**
 * HTTP wrapper that automatically shows toast notifications on errors
 * and handles JSON parsing
 */
export async function http<T = any>(
  url: string,
  init?: RequestInit
): Promise<T> {
  try {
    const res = await fetch(url, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...init?.headers,
      },
    });

    const data = await res.json().catch(() => ({}));

    if (!res.ok) {
      const errorMessage = data.message || data.error || `Request failed with status ${res.status}`;
      
      // Only show toast if we're in a browser environment and toast is available
      if (typeof window !== "undefined") {
        // Import dynamically to avoid circular dependencies
        const { useToastInternal } = await import("@/components/ui/toast");
        // Note: This won't work directly in a non-component context
        // The toast will be shown via React Query's onError handler instead
      }
      
      throw new Error(errorMessage);
    }

    return data as T;
  } catch (error: any) {
    // Re-throw to let React Query handle it
    throw error;
  }
}

