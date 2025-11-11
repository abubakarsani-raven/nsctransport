"use client";

import { useEffect } from 'react';

export default function LogoutPage() {
  useEffect(() => {
    fetch('/api/auth/logout', { method: 'POST' }).finally(() => {
      window.location.href = '/login';
    });
  }, []);

  return <div className="p-6">Signing out...</div>;
}


