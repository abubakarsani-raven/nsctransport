import { NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      cache: 'no-store',
    });

    const data = await res.json();
    if (!res.ok) {
      return NextResponse.json({ message: data?.message || 'Login failed' }, { status: res.status });
    }

    const token = data?.access_token as string | undefined;
    if (!token) {
      return NextResponse.json({ message: 'No token in response' }, { status: 500 });
    }

    const response = NextResponse.json({ user: data.user }, { status: 200 });
    response.cookies.set('access_token', token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 7, // 7 days
    });
    return response;
  } catch (err: any) {
    return NextResponse.json({ message: 'Unexpected error' }, { status: 500 });
  }
}


