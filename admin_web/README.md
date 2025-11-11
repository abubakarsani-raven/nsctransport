# Transport Management System - Admin Web Dashboard

A modern Next.js 15 admin dashboard for managing transport requests, vehicles, drivers, and tracking.

## Features

- **Authentication**: JWT-based authentication with HTTP-only cookies
- **Dashboard**: Real-time statistics (active trips, pending requests, available vehicles)
- **Requests Management**: Approve, reject, and assign drivers/vehicles to requests
- **Vehicles Management**: Create and manage vehicles with status updates
- **Users Management**: View staff and drivers, convert staff to drivers, create new drivers
- **Offices Management**: Manage office locations
- **Live Tracking**: View real-time vehicle and driver locations

## Tech Stack

- **Framework**: Next.js 15 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: shadcn/ui
- **Data Fetching**: React Query (TanStack Query)
- **Forms**: React Hook Form + Zod
- **HTTP Client**: Axios
- **Real-time**: Socket.IO Client

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Backend API running on `http://localhost:3000`

### Installation

1. Install dependencies:
```bash
npm install
```

2. Create `.env.local` file:
```env
# For local development - use localhost
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000

# For production (Vercel) - use Railway URL
# NEXT_PUBLIC_API_BASE_URL=https://nsctransport-production.up.railway.app

NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

**Note**: See `env.example` file or `ENVIRONMENT_SETUP.md` in the root directory for detailed configuration.

3. Run the development server:
```bash
npm run dev
```

4. Open [http://localhost:3001](http://localhost:3001) in your browser

### Default Admin Credentials

- Email: `admin@transport.com`
- Password: `admin123`

## Project Structure

```
admin_web/
├── src/
│   ├── app/
│   │   ├── (auth)/          # Public routes (login)
│   │   ├── (dashboard)/     # Protected dashboard routes
│   │   └── api/             # API proxy routes
│   ├── components/          # Reusable components
│   ├── hooks/               # Custom React hooks
│   ├── lib/                 # Utilities and API client
│   └── types/               # TypeScript type definitions
├── public/                  # Static assets
└── README.md
```

## API Integration

The app communicates with the NestJS backend through Next.js API routes that act as proxies. All authentication is handled via HTTP-only cookies for security.

## Development

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run lint` - Run ESLint

## Environment Variables

- `NEXT_PUBLIC_API_BASE_URL` - Backend API base URL (default: http://localhost:3000)
- `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` - Google Maps API key for tracking map

## Notes

- The app uses HTTP-only cookies for JWT storage (more secure than localStorage)
- All API calls go through Next.js API routes for cookie handling
- Responsive design works on mobile, tablet, and desktop
- Real-time tracking uses Socket.IO for live updates
