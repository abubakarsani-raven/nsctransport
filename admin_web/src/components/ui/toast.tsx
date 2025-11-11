"use client";

import { createContext, useCallback, useContext, useMemo, useState } from "react";

export type ToastVariant = "default" | "success" | "error" | "warning";

export type Toast = {
  id: number;
  title?: string;
  description?: string;
  variant?: ToastVariant;
  durationMs?: number;
};

type ToastContextValue = {
  toasts: Toast[];
  show: (toast: Omit<Toast, "id">) => void;
  dismiss: (id: number) => void;
};

const ToastContext = createContext<ToastContextValue | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const dismiss = useCallback((id: number) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const show = useCallback((toast: Omit<Toast, "id">) => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    const item: Toast = {
      id,
      title: toast.title,
      description: toast.description,
      variant: toast.variant ?? "default",
      durationMs: toast.durationMs ?? 3500,
    };
    setToasts((prev) => [...prev, item]);
    if (item.durationMs && item.durationMs > 0) {
      setTimeout(() => dismiss(id), item.durationMs);
    }
  }, [dismiss]);

  const value = useMemo(() => ({ toasts, show, dismiss }), [toasts, show, dismiss]);

  return (
    <ToastContext.Provider value={value}>
      {children}
      <Toaster />
    </ToastContext.Provider>
  );
}

export function useToastInternal() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used within ToastProvider");
  return ctx;
}

export function Toaster() {
  const { toasts, dismiss } = useToastInternal();
  return (
    <div
      aria-live="polite"
      aria-atomic="true"
      className="pointer-events-none fixed inset-0 z-50 flex flex-col items-center gap-3 p-4"
    >
      {toasts.map((t) => (
        <div
          key={t.id}
          className={[
            "pointer-events-auto w-full max-w-2xl",
            "min-w-[50%]",
            "rounded-md border p-4 shadow-lg",
            "toast-enter",
            t.variant === "success" && "border-green-300 bg-green-50 text-green-900",
            t.variant === "error" && "border-red-300 bg-red-50 text-red-900",
            t.variant === "warning" && "border-yellow-300 bg-yellow-50 text-yellow-900",
            t.variant === "default" && "border-gray-200 bg-white text-gray-900",
          ].filter(Boolean).join(" ")}
          style={{ alignSelf: "center" }}
          role="status"
        >
          <div className="flex items-start gap-3">
            <div className="flex-1">
              {t.title ? <div className="font-medium">{t.title}</div> : null}
              {t.description ? (
                <div className="text-sm text-gray-700">{t.description}</div>
              ) : null}
            </div>
            <button
              onClick={() => dismiss(t.id)}
              className="inline-flex h-6 shrink-0 items-center rounded px-2 text-xs text-gray-600 hover:bg-gray-100 transition-colors"
            >
              Close
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}



