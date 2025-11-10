# Transport Management System

A comprehensive transport management system with mobile apps for staff and drivers, and an admin web dashboard. Built with Flutter and NestJS.

## Project Structure

```
nsctranspot/
├── backend/              # NestJS backend API (deploy to Railway)
├── admin_web/           # Next.js admin web dashboard (deploy to Vercel)
├── staff_app/           # Flutter mobile app for staff
└── driver_app/          # Flutter mobile app for drivers
```

## Features

### Core Functionality
- Multi-level approval workflow (Supervisor → DGS → DDGS → AD Transport → Transport Officer)
- Vehicle and driver assignment
- Real-time GPS tracking
- Automatic trip start at scheduled time
- Automatic return detection (50m radius)
- Distance and time calculation
- Push, in-app, and email notifications

### User Roles
- **Staff**: Create vehicle requests
- **Supervisor**: Approve staff requests
- **DGS**: Director General Services approval
- **DDGS**: Deputy Director GS approval
- **AD Transport**: Assistant Director Transport approval
- **Transport Officer**: Assign drivers and vehicles
- **Driver**: Execute trips with GPS tracking
- **Admin**: Full system access

## Backend Setup

### Prerequisites
- Node.js (v18 or higher)
- MongoDB
- npm or yarn

### Installation

1. Navigate to backend directory:
```bash
cd backend
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env` file:
```env
MONGODB_URI=mongodb://localhost:27017/transport_management
JWT_SECRET=your-secret-key-change-in-production
JWT_EXPIRES_IN=7d
GOOGLE_MAPS_API_KEY=AIzaSyD3apWjzMf9iPAdZTSGR4ln2pU7U6Lo7_I
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-email-password
EMAIL_FROM=noreply@transportmanagement.com
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY=your-firebase-private-key
FIREBASE_CLIENT_EMAIL=your-firebase-client-email
PORT=3000
NODE_ENV=development
```

4. Start the server:
```bash
npm run start:dev
```

The API will be available at `http://localhost:3000`

## Flutter Apps Setup

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / Xcode (for mobile development)
- Chrome (for web development)

### Staff App

1. Navigate to staff app:
```bash
cd staff_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Update `pubspec.yaml` with required dependencies (see below)

4. Run the app:
```bash
flutter run
```

### Driver App

1. Navigate to driver app:
```bash
cd driver_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Update `pubspec.yaml` with required dependencies (see below)

4. Run the app:
```bash
flutter run
```

### Admin Web Dashboard

1. Navigate to admin web directory:
```bash
cd admin_web
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env.local` file:
```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your-google-maps-api-key
```

4. Run the development server:
```bash
npm run dev
```

The admin web will be available at `http://localhost:3001`

## Required Flutter Dependencies

### Staff App & Driver App
```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  provider: ^6.1.1
  google_maps_flutter: ^2.5.0
  location: ^5.0.3
  firebase_messaging: ^14.7.9
  shared_preferences: ^2.2.2
  intl: ^0.18.1
  google_places_flutter: ^2.0.9
```

### Admin Web Dashboard
The admin web dashboard is built with Next.js, React, and TypeScript. See `admin_web/README.md` for details.

## API Endpoints

### Authentication
- `POST /auth/login` - Login
- `POST /auth/register` - Register (Admin only)
- `GET /auth/me` - Get current user

### Vehicle Requests
- `POST /requests` - Create request
- `GET /requests` - Get requests (filtered by role)
- `GET /requests/:id` - Get request details
- `PUT /requests/:id/approve` - Approve request
- `PUT /requests/:id/reject` - Reject request
- `PUT /requests/:id/resubmit` - Resubmit rejected request

### Assignments
- `GET /assignments/available-drivers` - Get available drivers
- `GET /assignments/available-vehicles` - Get available vehicles
- `POST /assignments/assign` - Assign driver and vehicle
- `PUT /assignments/:id/swap-driver` - Swap driver

### Trips
- `POST /trips/start` - Start trip
- `POST /trips/:id/location` - Update GPS location
- `POST /trips/:id/complete` - Complete trip
- `GET /trips/active` - Get active trips
- `GET /trips/:id/tracking` - Get trip tracking data

### Tracking (WebSocket)
- `WS /tracking` - WebSocket connection
- `subscribe:trips` - Subscribe to trip updates
- `subscribe:vehicles` - Subscribe to vehicle locations
- `subscribe:drivers` - Subscribe to driver locations

## Database Schema

### Collections
- **Users**: Staff, drivers, and administrators
- **Vehicles**: Vehicle information and status
- **VehicleRequests**: Request workflow and approvals
- **Trips**: Trip tracking and GPS data
- **Offices**: Office locations
- **Notifications**: In-app notifications

## Workflow

### Non-Supervisor Staff Request
1. Staff creates request → `pending`
2. Supervisor approves → `supervisor_approved`
3. DGS approves → `dgs_approved`
4. DDGS approves → `ddgs_approved`
5. AD Transport approves → `ad_transport_approved`
6. Transport Officer assigns driver/vehicle → `transport_officer_assigned`
7. Driver accepts (automatic) → `driver_accepted`
8. Trip auto-starts at scheduled time → `in_progress`
9. Driver completes trip → `completed`
10. Driver returns (auto-detected) → `returned`

### Supervisor Staff Request
- Skips step 2, goes directly to DGS

## Development Notes

- All dates must be in ISO 8601 format
- GPS coordinates use decimal degrees (lat, lng)
- Distance is calculated in kilometers
- Time is stored in minutes
- Return detection radius: 50 meters
- JWT tokens expire after 7 days (configurable)

## Deployment

For deployment instructions to Railway (backend) and Vercel (admin web), see [DEPLOYMENT.md](./DEPLOYMENT.md).

### Quick Start Deployment

1. Push code to GitHub
2. Deploy backend to Railway (see DEPLOYMENT.md)
3. Deploy admin web to Vercel (see DEPLOYMENT.md)
4. Configure environment variables in both platforms
5. Update CORS settings in Railway with Vercel URL

## License

Private project - All rights reserved

