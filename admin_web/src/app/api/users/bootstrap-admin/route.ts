import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function GET(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value;
  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  
  const res = await fetch(`${API_BASE}/users/bootstrap-admin`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: 'no-store',
  });
  
  const data = await res.json().catch(() => ({ error: 'Failed to parse response' }));
  
  if (!res.ok) {
    return NextResponse.json(data, { status: res.status });
  }
  
  return NextResponse.json(data);
}







