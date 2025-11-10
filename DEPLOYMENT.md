# Deployment Guide

This guide covers deploying the Transport Management System to Railway (backend) and Vercel (admin web).

## Prerequisites

- GitHub account
- Railway account (sign up at https://railway.app)
- Vercel account (sign up at https://vercel.com)
- MongoDB database (Railway MongoDB or MongoDB Atlas)
- Firebase project with service account credentials
- Google Maps API key

## Repository Structure

```
nsctranspot/
├── backend/          # NestJS backend (Railway)
├── admin_web/        # Next.js admin web (Vercel)
├── driver_app/       # Flutter driver app
└── staff_app/        # Flutter staff app
```

## Step 1: Push to GitHub

1. Initialize git (if not already done):
```bash
git init
git add .
git commit -m "Initial commit - ready for deployment"
```

2. Create a new repository on GitHub (don't initialize with README)

3. Push to GitHub:
```bash
git remote add origin https://github.com/yourusername/nsctranspot.git
git branch -M main
git push -u origin main
```

## Step 2: Deploy Backend to Railway

### 2.1 Create Railway Project

1. Go to [Railway.app](https://railway.app) and sign in
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Select your `nsctranspot` repository
5. Railway will detect the backend folder automatically

### 2.2 Configure Root Directory

1. In Railway project settings, go to **Settings** → **Service**
2. Set **Root Directory** to: `backend`
3. Save changes

### 2.3 Add MongoDB Database

1. In your Railway project, click **"+ New"**
2. Select **"Database"** → **"Add MongoDB"**
3. Railway will create a MongoDB instance
4. Copy the **MONGODB_URI** connection string (you'll need it in the next step)

### 2.4 Configure Environment Variables

In Railway project settings, go to **Variables** and add:

#### Required Variables:

```env
# Database
MONGODB_URI=mongodb://mongo:27017/transport_management
# Or use the connection string from Railway MongoDB service

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
JWT_EXPIRES_IN=7d

# Google Maps API
GOOGLE_MAPS_API_KEY=your-google-maps-api-key

# Firebase Configuration (use JSON string, not file path)
FIREBASE_CREDENTIALS={"type":"service_account","project_id":"your-project-id",...}
# Copy the entire JSON from Firebase service account file

# Environment
NODE_ENV=production
PORT=3000

# CORS (will be set after Vercel deployment)
ADMIN_WEB_URL=https://your-vercel-app.vercel.app
```

#### Getting Firebase Credentials:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Project Settings** → **Service Accounts**
4. Click **"Generate new private key"**
5. Download the JSON file
6. Copy the entire JSON content
7. In Railway, add it as `FIREBASE_CREDENTIALS` environment variable (paste as single line)

#### Optional Variables (if using email):

```env
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASS=your-app-password
EMAIL_FROM=noreply@transportmanagement.com
```

### 2.5 Configure Build Settings

Railway should auto-detect the build settings from `nixpacks.toml`, but verify:

- **Build Command**: `npm install && npm run build`
- **Start Command**: `npm run start:prod`

### 2.6 Deploy

1. Railway will automatically deploy when you push to the main branch
2. Wait for deployment to complete
3. Copy the **Railway URL** (e.g., `https://your-app.railway.app`)
4. Test the API: `https://your-app.railway.app` (should return API info)

## Step 3: Deploy Admin Web to Vercel

### 3.1 Create Vercel Project

1. Go to [Vercel.com](https://vercel.com) and sign in
2. Click **"Add New..."** → **"Project"**
3. Import your GitHub repository
4. Select the `nsctranspot` repository

### 3.2 Configure Project Settings

1. **Framework Preset**: Next.js (auto-detected)
2. **Root Directory**: `admin_web` (click "Edit" and set to `admin_web`)
3. **Build Command**: `npm run build` (auto-detected)
4. **Output Directory**: `.next` (auto-detected)
5. **Install Command**: `npm install` (auto-detected)

### 3.3 Configure Environment Variables

In Vercel project settings, go to **Environment Variables** and add:

```env
# Backend API URL (your Railway URL)
NEXT_PUBLIC_API_BASE_URL=https://your-railway-app.railway.app

# Google Maps API Key
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your-google-maps-api-key
```

### 3.4 Deploy

1. Click **"Deploy"**
2. Wait for deployment to complete
3. Copy your **Vercel URL** (e.g., `https://your-app.vercel.app`)

### 3.5 Update Railway CORS

After getting your Vercel URL, go back to Railway:

1. Update the `ADMIN_WEB_URL` environment variable with your Vercel URL
2. Railway will automatically redeploy with the new CORS settings

## Step 4: Verify Deployment

### Backend (Railway)

1. Test API health: `https://your-railway-app.railway.app`
2. Test API endpoint: `https://your-railway-app.railway.app/auth/login`
3. Check Railway logs for any errors

### Admin Web (Vercel)

1. Visit your Vercel URL: `https://your-app.vercel.app`
2. Try logging in with admin credentials
3. Check browser console for any errors
4. Verify API calls are working

## Step 5: Custom Domains (Optional)

### Railway Custom Domain

1. In Railway project, go to **Settings** → **Domains**
2. Click **"Generate Domain"** or add your custom domain
3. Update DNS records as instructed

### Vercel Custom Domain

1. In Vercel project, go to **Settings** → **Domains**
2. Add your custom domain
3. Update DNS records as instructed
4. Update `ADMIN_WEB_URL` in Railway with your custom domain

## Environment Variables Summary

### Railway (Backend)

| Variable | Description | Required |
|----------|-------------|----------|
| `MONGODB_URI` | MongoDB connection string | Yes |
| `JWT_SECRET` | Secret key for JWT tokens | Yes |
| `JWT_EXPIRES_IN` | JWT token expiration | Yes |
| `GOOGLE_MAPS_API_KEY` | Google Maps API key | Yes |
| `FIREBASE_CREDENTIALS` | Firebase service account JSON | Yes |
| `NODE_ENV` | Environment (production) | Yes |
| `PORT` | Server port | No (Railway sets this) |
| `ADMIN_WEB_URL` | Vercel admin web URL | Yes (for CORS) |
| `EMAIL_*` | Email configuration | No |

### Vercel (Admin Web)

| Variable | Description | Required |
|----------|-------------|----------|
| `NEXT_PUBLIC_API_BASE_URL` | Railway backend URL | Yes |
| `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` | Google Maps API key | Yes |

## Troubleshooting

### Backend Issues

1. **Build fails**: Check Railway logs for errors
2. **Database connection fails**: Verify `MONGODB_URI` is correct
3. **Firebase errors**: Verify `FIREBASE_CREDENTIALS` JSON is valid
4. **CORS errors**: Verify `ADMIN_WEB_URL` is set correctly

### Admin Web Issues

1. **Build fails**: Check Vercel build logs
2. **API calls fail**: Verify `NEXT_PUBLIC_API_BASE_URL` is correct
3. **CORS errors**: Verify Railway `ADMIN_WEB_URL` includes your Vercel URL

### Common Solutions

- **Clear cache**: Redeploy both services
- **Check logs**: Railway and Vercel provide detailed logs
- **Verify environment variables**: Double-check all variables are set
- **Test locally**: Ensure code works locally before deploying

## Continuous Deployment

Both Railway and Vercel automatically deploy when you push to the main branch:

1. Make changes to your code
2. Commit and push to GitHub
3. Railway and Vercel will automatically rebuild and deploy

## Monitoring

### Railway

- View logs in Railway dashboard
- Set up alerts for errors
- Monitor resource usage

### Vercel

- View build logs in Vercel dashboard
- Set up analytics
- Monitor performance

## Security Notes

1. **Never commit** `.env` files or Firebase service account JSON
2. **Use strong** `JWT_SECRET` in production
3. **Restrict CORS** to only allowed origins
4. **Use HTTPS** (Railway and Vercel provide this automatically)
5. **Rotate secrets** periodically
6. **Monitor** for security vulnerabilities

## Support

- Railway Docs: https://docs.railway.app
- Vercel Docs: https://vercel.com/docs
- NestJS Docs: https://docs.nestjs.com
- Next.js Docs: https://nextjs.org/docs

