import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function GET(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value;
  if (!token) return NextResponse.json(0);
  const res = await fetch(`${API_BASE}/requests`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  if (!res.ok) return NextResponse.json(0);
  const data = await res.json();
  const count = Array.isArray(data)
    ? data.filter((r: any) => r.status === 'pending').length
    : 0;
  return NextResponse.json(count);
}


