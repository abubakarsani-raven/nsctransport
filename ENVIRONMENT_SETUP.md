# Environment Configuration Guide

This guide explains how to configure environment variables for both local development and production deployments.

## Overview

- **Local Development**: Uses `localhost` URLs
- **Production**: Uses Railway (backend) and Vercel (admin web) URLs

## Backend Configuration

### Local Development

1. Copy the example file:
   ```bash
   cd backend
   cp .env.example .env
   ```

2. Edit `.env` with your local values:
   ```env
   MONGODB_URI=mongodb://localhost:27017/transport_management
   JWT_SECRET=your-local-secret-key
   JWT_EXPIRES_IN=7d
   GOOGLE_MAPS_API_KEY=your-google-maps-api-key
   FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json
   PORT=3000
   NODE_ENV=development
   ```

3. Start the backend:
   ```bash
   npm run start:dev
   ```

### Production (Railway)

Set these environment variables in Railway Dashboard → Your Service → Variables:

```env
# Database
MONGODB_URI=mongodb://mongo:27017/transport_management
# Or use Railway MongoDB connection string

# JWT
JWT_SECRET=your-super-secret-production-key
JWT_EXPIRES_IN=7d

# Google Maps
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# Firebase (REQUIRED - use JSON string, not file path)
FIREBASE_CREDENTIALS={"type":"service_account","project_id":"...",...}

# Environment
NODE_ENV=production
PORT=3000

# CORS (set after deploying admin web to Vercel)
ADMIN_WEB_URL=https://your-vercel-app.vercel.app

# Optional: Railway automatically sets this
RAILWAY_PUBLIC_DOMAIN=nsctransport-production.up.railway.app
```

**Important**: 
- Your Railway URL is: `https://nsctransport-production.up.railway.app`
- Do NOT set `FIREBASE_SERVICE_ACCOUNT_PATH` in Railway (only use `FIREBASE_CREDENTIALS`)

## Admin Web Configuration

### Local Development

1. Copy the example file:
   ```bash
   cd admin_web
   cp .env.example .env.local
   ```

2. Edit `.env.local`:
   ```env
   NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
   NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
   ```

3. Start the admin web:
   ```bash
   npm run dev
   ```

4. Access at: `http://localhost:3001`

### Production (Vercel)

Set these environment variables in Vercel Dashboard → Your Project → Settings → Environment Variables:

```env
# Backend API URL (your Railway URL)
NEXT_PUBLIC_API_BASE_URL=https://nsctransport-production.up.railway.app

# Google Maps
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

**Important**: 
- Use `https://` (not `http://`) for the Railway URL
- The Railway URL is: `https://nsctransport-production.up.railway.app`

## Environment Variable Summary

### Backend (Railway)

| Variable | Local Development | Production (Railway) |
|----------|------------------|---------------------|
| `MONGODB_URI` | `mongodb://localhost:27017/...` | Railway MongoDB connection string |
| `JWT_SECRET` | Any secret key | Strong production secret |
| `FIREBASE_*` | `FIREBASE_SERVICE_ACCOUNT_PATH` (file) | `FIREBASE_CREDENTIALS` (JSON string) |
| `NODE_ENV` | `development` | `production` |
| `ADMIN_WEB_URL` | Not needed | Your Vercel URL |

### Admin Web (Vercel)

| Variable | Local Development | Production (Vercel) |
|----------|------------------|-------------------|
| `NEXT_PUBLIC_API_BASE_URL` | `http://localhost:3000` | `https://nsctransport-production.up.railway.app` |
| `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | Your key | Your key |

## Quick Setup Checklist

### Local Development Setup

- [ ] Backend `.env` file created with local values
- [ ] Admin web `.env.local` file created with `http://localhost:3000`
- [ ] Backend running on `http://localhost:3000`
- [ ] Admin web running on `http://localhost:3001`
- [ ] Can access admin web and login works

### Production Setup

- [ ] Railway backend deployed
- [ ] Railway environment variables set (especially `FIREBASE_CREDENTIALS`)
- [ ] Railway URL: `https://nsctransport-production.up.railway.app`
- [ ] Vercel admin web deployed
- [ ] Vercel environment variables set with Railway URL
- [ ] CORS configured in Railway (`ADMIN_WEB_URL` set to Vercel URL)
- [ ] Can access admin web on Vercel and login works

## Testing Environment Configuration

### Test Local Development

1. Backend should be accessible at: `http://localhost:3000`
2. Admin web should connect to: `http://localhost:3000`
3. Check browser console for API errors
4. Verify login works

### Test Production

1. Backend should be accessible at: `https://nsctransport-production.up.railway.app`
2. Admin web should connect to: `https://nsctransport-production.up.railway.app`
3. Check browser console for API errors
4. Verify login works
5. Check Railway logs for CORS errors

## Troubleshooting

### Local Development Issues

**Problem**: Admin web can't connect to backend
- **Solution**: Verify backend is running on `http://localhost:3000`
- **Solution**: Check `.env.local` has `NEXT_PUBLIC_API_BASE_URL=http://localhost:3000`

**Problem**: CORS errors
- **Solution**: Backend CORS allows `http://localhost:3001` in development mode

### Production Issues

**Problem**: Admin web can't connect to Railway backend
- **Solution**: Verify `NEXT_PUBLIC_API_BASE_URL` in Vercel is set to `https://nsctransport-production.up.railway.app`
- **Solution**: Check Railway backend is running and accessible

**Problem**: CORS errors in production
- **Solution**: Set `ADMIN_WEB_URL` in Railway to your Vercel URL
- **Solution**: Verify Railway CORS configuration allows your Vercel domain

**Problem**: Firebase not working
- **Solution**: Set `FIREBASE_CREDENTIALS` in Railway (not `FIREBASE_SERVICE_ACCOUNT_PATH`)
- **Solution**: Verify JSON is valid and on a single line

## URLs Reference

### Local Development
- Backend: `http://localhost:3000`
- Admin Web: `http://localhost:3001`

### Production
- Backend (Railway): `https://nsctransport-production.up.railway.app`
- Admin Web (Vercel): `https://your-vercel-app.vercel.app` (your Vercel URL)

## Notes

- **Never commit** `.env` or `.env.local` files to git
- Always use `https://` for production URLs
- Railway automatically sets `RAILWAY_PUBLIC_DOMAIN` environment variable
- Vercel automatically sets `VERCEL_URL` environment variable
- Environment variables prefixed with `NEXT_PUBLIC_` are exposed to the browser






