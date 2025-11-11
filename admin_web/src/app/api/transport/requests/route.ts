import { NextRequest, NextResponse } from 'next/server';

const API_BASE = process.env.NEXT_PUBLIC_API_BASE_URL || 'http://localhost:3000';

export async function GET(req: NextRequest) {
  const token = req.cookies.get('access_token')?.value;
  if (!token) {
    return NextResponse.json([], { status: 200 });
  }
  
  // Use /requests/vehicle endpoint - returns all vehicle requests based on user role
  // For admin users, this should return all vehicle requests they can see
  const res = await fetch(`${API_BASE}/requests/vehicle`, {
    headers: { 
      Authorization: `Bearer ${token}`,
    },
    cache: 'no-store',
  });
  
  if (!res.ok) {
    // Fallback to old /requests endpoint if /requests/vehicle fails
    const fallbackRes = await fetch(`${API_BASE}/requests`, {
      headers: { 
        Authorization: `Bearer ${token}`,
      },
      cache: 'no-store',
    });
    
    if (!fallbackRes.ok) {
      return NextResponse.json([], { status: 200 });
    }
    
    const fallbackData = await fallbackRes.json();
    return NextResponse.json(Array.isArray(fallbackData) ? fallbackData : [], { status: 200 });
  }
  
  const data = await res.json();
  return NextResponse.json(Array.isArray(data) ? data : [], { status: 200 });
}

