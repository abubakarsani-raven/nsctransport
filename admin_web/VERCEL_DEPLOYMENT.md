# Vercel Deployment Guide for Admin Web

## Build Status
✅ **Build is now successful!** All TypeScript errors have been fixed.

## Deployment Steps

### 1. In Vercel Root Directory Modal
Since `admin_web` is a nested git repository, it may not appear in the directory list. **Manually type `admin_web`** in the Root Directory field.

### 2. Environment Variables
Set these in Vercel Project Settings → Environment Variables:

```
NEXT_PUBLIC_API_BASE_URL=https://nsctransport-production.up.railway.app
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your_google_maps_api_key
```

### 3. Build Settings
Vercel should auto-detect Next.js, but verify:
- **Framework Preset**: Next.js
- **Build Command**: `npm run build`
- **Output Directory**: `.next`
- **Install Command**: `npm install`
- **Root Directory**: `admin_web`

### 4. Deploy
Click "Deploy" and wait for the build to complete.

## Recent Fixes Applied

1. ✅ Fixed Next.js 16 async params in route handlers:
   - `src/app/api/offices/[id]/route.ts`
   - `src/app/api/requests/[id]/approve/route.ts`
   - `src/app/api/requests/[id]/reject/route.ts`

2. ✅ Fixed TypeScript error in `EditReminderDialog.tsx`

3. ✅ Fixed React Query v5 compatibility in `Providers.tsx`

4. ✅ Fixed calendar component for react-day-picker v9

## Troubleshooting

If deployment fails:
1. Check Vercel build logs for errors
2. Verify environment variables are set correctly
3. Ensure `admin_web` directory is accessible in the repository
4. Check that all dependencies are in `package.json`

## Notes

- The `vercel.json` file is configured for the monorepo setup
- Build command: `npm run build`
- Output directory: `.next`
- Framework: Next.js 16.0.1

