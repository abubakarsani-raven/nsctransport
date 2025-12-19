---
name: Next.js Admin Dashboard Migration Plan
overview: ""
todos:
  - id: ea2ebf6c-112a-4e09-b04e-3d212d2dba69
    content: Initialize Next.js 15 app with Tailwind and shadcn/ui
    status: pending
  - id: 694c1ace-f623-4595-8a71-631622bc742e
    content: Create responsive sidebar layout and protected routes middleware
    status: pending
  - id: c05fedfe-d1c9-4857-b971-fc296d8b91fc
    content: Implement login/logout with HTTP-only cookies and profile hydration
    status: pending
  - id: 9562b49e-7d64-42d6-80aa-965624c24915
    content: Set up Axios client, React Query, DTO types
    status: pending
  - id: 129bd13e-6e07-4e6a-a4c2-db4c2af5ceda
    content: Build dashboard stats with React Query
    status: pending
  - id: d21f5c99-f513-440d-b682-286d0f5fba28
    content: Implement requests table, filters, approve/reject, assign dialog
    status: pending
  - id: 1ef08fd6-697c-4ca1-9cc7-73d7c98c1fc4
    content: Implement vehicles table, create/edit vehicle forms
    status: pending
  - id: 0a6a9d99-672f-4eeb-8ab5-f36803d53625
    content: Implement users tabs, convert staff to driver, create driver
    status: pending
  - id: 94fa5d9e-9b2e-4090-9d56-bcd3222c6184
    content: Implement offices CRUD
    status: pending
  - id: 0e651154-3013-4470-a2b4-36b6164282c5
    content: Implement live tracking with Socket.IO and Google Maps JS
    status: pending
  - id: cfd48491-b2df-409e-ab8b-e9b9678df844
    content: Add toasts, error/loading states, responsiveness, README
    status: pending
---

# Next.js Admin Dashboard Migration Plan

## Scope and Decisions

- Replace Flutter admin dashboard entirely with a new Next.js (App Router) app
- UI: shadcn/ui components, responsive sidebar layout
- Auth: JWT in HTTP-only cookies (server-side) 
- Backend: Direct calls to existing NestJS REST endpoints
- Language: TypeScript

## Tech Stack

- Next.js 15 (latest) with App Router
- shadcn/ui + Tailwind CSS + Radix UI
- React Query (TanStack Query) for data fetching and caching
- Zod + React Hook Form for forms and validation
- Socket.IO client for real-time tracking
- Axios for API client
- ESLint + Prettier
- Env via `.env.local`

## Project Structure (key files)

- `app/(auth)/login/page.tsx` — Login screen
- `app/(dashboard)/layout.tsx` — Shell with sidebar (shadcn/ui)
- `app/(dashboard)/page.tsx` — Dashboard cards and stats
- `app/(dashboard)/requests/page.tsx` — Requests management (filters, approve/reject, assign)
- `app/(dashboard)/vehicles/page.tsx` — Vehicles table + create/edit dialogs
- `app/(dashboard)/users/page.tsx` — Staff/Drivers tables + convert staff→driver, create driver
- `app/(dashboard)/offices/page.tsx` — Offices CRUD
- `app/(dashboard)/tracking/page.tsx` — Live map with drivers/vehicles
- `lib/api/client.ts` — Axios instance with cookie handling
- `lib/api/auth.ts` — login/logout, profile fetch
- `lib/api/*` — modules for requests/vehicles/users/offices/tracking
- `lib/auth/cookies.ts` — cookie helpers (set/get/clear)
- `middleware.ts` — route protection; redirect unauthenticated users to `/login`
- `components/ui/*` — shadcn components
- `components/layout/sidebar.tsx` — Responsive sidebar
- `components/common/*` — tables, dialogs, forms
- `hooks/useAuth.ts`, `hooks/useSocket.ts` — auth and realtime
- `types/*.ts` — shared DTOs and enums aligned with NestJS

## Authentication Flow (HTTP-only cookies)

1. Login form posts to NestJS `/auth/login`
2. Next.js server action stores `access_token` in an HTTP-only cookie
3. Client requests include cookie automatically; Axios sends cookie
4. `middleware.ts` checks cookie presence for protected routes; if missing, redirect `/login`
5. `GET /auth/me` used to hydrate user context
6. Logout clears cookie and invalidates queries

## API Integration (direct to NestJS)

- Base URL via `NEXT_PUBLIC_API_BASE_URL`
- Axios instance with:
- `withCredentials: true` (for CORS if needed)
- Interceptors: attach Bearer from cookie on server, or rely on cookie
- 401 handler → redirect to `/login`
- Endpoints mapped 1:1 to existing backend

## Pages and Features

- Dashboard: Active trips, Pending requests, Available vehicles (cards), refresh
- Requests: Data table, filter by status, approve/reject with dialogs, assign driver+vehicle dialog
- Vehicles: List, status badges, create/edit vehicle form, status updates
- Users: Staff/Drivers tabs, convert staff→driver, create driver
- Offices: CRUD list + location fields
- Tracking: Socket.IO live map (Google Maps JS API), list of active trips

## UI/UX

- Responsive sidebar (collapsible on tablet/mobile)
- Data table: shadcn Table with pagination, sorting, status chips
- Toaster notifications (shadcn) — follow project toast width rule
- Forms: React Hook Form + Zod, inline validation messages

## Environment & Config

- `.env.local`
- `NEXT_PUBLIC_API_BASE_URL=http://localhost:3000`
- `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=...`
- Backend CORS must allow credentials (already enabled)

## Implementation Steps

1. Bootstrap Next.js app (latest) + Tailwind + shadcn/ui
2. Add ESLint/Prettier, base layout, sidebar shell
3. Auth: server actions + cookie, middleware protection, login page
4. API client + types; wire `GET /auth/me` hydration
5. Dashboard cards with React Query
6. Requests page: table, filters, approve/reject, assign dialog
7. Vehicles page: table + create/edit forms
8. Users page: staff/drivers tabs, convert/create driver flows
9. Offices page: CRUD forms
10. Tracking page: Socket.IO + Google Maps JS API
11. Polishing: loading, empty states, errors, responsive tuning
12. Deploy scripts and README

## Risks & Mitigations

- CORS with cookies: ensure `credentials: true` and allowed origin
- Token in cookie vs Bearer: prefer cookie; fallback to header for server actions
- Google Maps on web: load Maps JS script key on tracking page only

## Acceptance Criteria

- All listed pages implemented
- Auth protected routes working via cookies
- Real-time tracking visible on map
- CRUD flows for vehicles/users/offices
- Requests workflow actions
- Responsive sidebar and tables