import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function POST(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value;
  if (!token) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const res = await fetch(`${API_BASE}/trips/admin/cancel-all-active`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    cache: 'no-store',
  });

  if (!res.ok) {
    const errorText = await res.text().catch(() => 'Failed to cancel active trips');
    return NextResponse.json({ error: errorText || 'Failed to cancel active trips' }, { status: 500 });
  }

  const data = await res.json().catch(() => ({ cancelledTrips: 0 }));
  return NextResponse.json(data);
}









