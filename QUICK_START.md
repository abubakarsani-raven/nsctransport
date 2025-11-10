# Quick Start - Deployment Setup

This is a quick reference for deploying the Transport Management System.

## Prerequisites Checklist

- [ ] GitHub account
- [ ] Railway account (https://railway.app)
- [ ] Vercel account (https://vercel.com)
- [ ] MongoDB database (Railway MongoDB or MongoDB Atlas)
- [ ] Firebase project with service account credentials
- [ ] Google Maps API key

## Step 1: Initialize Git and Push to GitHub

```bash
# Run the setup script
./setup-git.sh

# Or manually:
git init
git add .
git commit -m "Initial commit - ready for deployment"

# Create repository on GitHub, then:
git remote add origin https://github.com/yourusername/nsctranspot.git
git branch -M main
git push -u origin main
```

## Step 2: Deploy Backend to Railway

1. Go to Railway.app → New Project → Deploy from GitHub
2. Select your repository
3. Set **Root Directory** to: `backend`
4. Add MongoDB service (Railway → New → Database → MongoDB)
5. Add environment variables (see DEPLOYMENT.md for full list)
6. Copy Railway URL (e.g., `https://your-app.railway.app`)

### Critical Environment Variables for Railway:

```env
MONGODB_URI=mongodb://mongo:27017/transport_management
JWT_SECRET=your-super-secret-key
JWT_EXPIRES_IN=7d
GOOGLE_MAPS_API_KEY=your-key
FIREBASE_CREDENTIALS={"type":"service_account",...}
NODE_ENV=production
ADMIN_WEB_URL=https://your-vercel-app.vercel.app
```

## Step 3: Deploy Admin Web to Vercel

1. Go to Vercel.com → New Project → Import Git Repository
2. Select your repository
3. Set **Root Directory** to: `admin_web`
4. Add environment variables:
   - `NEXT_PUBLIC_API_BASE_URL` = Your Railway URL
   - `NEXT_PUBLIC_GOOGLE_MAPS_API_KEY` = Your Google Maps key
5. Deploy
6. Copy Vercel URL (e.g., `https://your-app.vercel.app`)

## Step 4: Update Railway CORS

1. Go back to Railway
2. Update `ADMIN_WEB_URL` environment variable with your Vercel URL
3. Railway will automatically redeploy

## Step 5: Verify Deployment

### Backend (Railway)
- Test: `https://your-railway-app.railway.app`
- Check logs in Railway dashboard

### Admin Web (Vercel)
- Test: `https://your-vercel-app.vercel.app`
- Try logging in
- Check browser console for errors

## Important Notes

⚠️ **Never commit:**
- `.env` files
- `firebase-service-account.json` files
- `node_modules/`
- `dist/` or `build/` folders

✅ **Always set in platform:**
- Environment variables in Railway and Vercel
- Firebase credentials as `FIREBASE_CREDENTIALS` JSON string in Railway
- CORS URLs in Railway

## Troubleshooting

- **Build fails**: Check logs in Railway/Vercel dashboard
- **CORS errors**: Verify `ADMIN_WEB_URL` in Railway matches Vercel URL
- **API errors**: Verify `NEXT_PUBLIC_API_BASE_URL` in Vercel matches Railway URL
- **Database errors**: Verify `MONGODB_URI` is correct in Railway

## Full Documentation

For detailed instructions, see [DEPLOYMENT.md](./DEPLOYMENT.md)

