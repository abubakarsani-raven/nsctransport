import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function GET(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value;
  if (!token) return NextResponse.json([], { status: 401 });
  const res = await fetch(`${API_BASE}/users`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  
  if (!res.ok) {
    console.error('Failed to fetch users:', res.status, res.statusText);
    const errorData = await res.json().catch(() => ({ message: 'Unknown error' }));
    console.error('Error details:', errorData);
    return NextResponse.json({ error: errorData.message || 'Failed to fetch users' }, { status: res.status });
  }
  
  const data = await res.json().catch(() => []);
  console.log('Users fetched:', data.length);
  return NextResponse.json(data);
}

