# Quick Environment Variables Reference

## 🚀 Production URLs

- **Backend (Railway)**: `https://nsctransport-production.up.railway.app`
- **Admin Web (Vercel)**: `https://your-vercel-app.vercel.app` (your Vercel URL)

## 📝 Local Development URLs

- **Backend**: `http://localhost:3000`
- **Admin Web**: `http://localhost:3001`

## 🔧 Environment Variables Setup

### Backend - Local Development

Create `backend/.env`:
```env
MONGODB_URI=mongodb://localhost:27017/transport_management
JWT_SECRET=your-local-secret
JWT_EXPIRES_IN=7d
GOOGLE_MAPS_API_KEY=your-key
FIREBASE_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json
PORT=3000
NODE_ENV=development
```

### Backend - Production (Railway)

Set in Railway Dashboard → Variables:
```env
MONGODB_URI=mongodb://mongo:27017/transport_management
JWT_SECRET=your-production-secret
JWT_EXPIRES_IN=7d
GOOGLE_MAPS_API_KEY=your-key
FIREBASE_CREDENTIALS={"type":"service_account",...}
NODE_ENV=production
ADMIN_WEB_URL=https://your-vercel-app.vercel.app
```

### Admin Web - Local Development

Create `admin_web/.env.local`:
```env
NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your-key
```

### Admin Web - Production (Vercel)

Set in Vercel Dashboard → Environment Variables:
```env
NEXT_PUBLIC_API_BASE_URL=https://nsctransport-production.up.railway.app
NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=your-key
```

## ✅ Quick Checklist

### Local Development
- [ ] Backend `.env` created
- [ ] Admin web `.env.local` created with `http://localhost:3000`
- [ ] Backend running on port 3000
- [ ] Admin web running on port 3001

### Production
- [ ] Railway backend deployed
- [ ] Railway `FIREBASE_CREDENTIALS` set
- [ ] Railway `ADMIN_WEB_URL` set to Vercel URL
- [ ] Vercel `NEXT_PUBLIC_API_BASE_URL` set to Railway URL
- [ ] Both services accessible and working

## 📚 Full Documentation

See [ENVIRONMENT_SETUP.md](./ENVIRONMENT_SETUP.md) for detailed instructions.






