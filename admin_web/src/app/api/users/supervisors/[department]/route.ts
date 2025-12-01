import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function GET(req: NextRequest, context: { params: Promise<{ department: string }> }) {
  const token = req.cookies.get('access_token')?.value;
  if (!token) return NextResponse.json([], { status: 401 });
  const { department } = await context.params;
  const res = await fetch(`${API_BASE}/users/supervisors/${encodeURIComponent(department)}`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  const data = await res.json().catch(() => []);
  return NextResponse.json(res.ok ? data : []);
}












