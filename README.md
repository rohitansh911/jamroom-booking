# 🎸 JamRoom — Music Club Booking System

A full-stack jam room booking system for college music clubs. No more WhatsApp chaos!

**Live Frontend:** https://jamroom-musicclub.surge.sh

---

## ✨ Features
- Book slots 1 day in advance (weekday 1hr / weekend 1hr or 2hr)
- Night permission requests (past 10 PM → till 1 AM or 2 AM)
- Admin panel with password protection
- Real-time slot availability from MySQL backend
- Fully responsive dark UI

## 🗂 Project Structure
```
Jamroom/
├── jamroom_frontend.html   # Frontend (deployed to Surge)
├── index.html              # Surge entry point (copy of above)
├── backend/
│   ├── server.js           # Express + MySQL REST API
│   ├── schema.sql          # Database setup
│   ├── package.json
│   └── .env.example        # Environment variable template
```

## 🚀 Local Setup

### 1. Database
```bash
mysql -u root -p < backend/schema.sql
```

### 2. Backend
```bash
cd backend
cp .env.example .env           # fill in your MySQL password
npm install
npm run dev                    # runs on http://localhost:3001
```

### 3. Frontend
Open `jamroom_frontend.html` in your browser.  
For local dev, change `API_BASE` in the script to `http://localhost:3001`.

## 🌐 Deployment

### Frontend → Surge
```bash
npx surge /path/to/Jamroom jamroom-musicclub.surge.sh
```

### Backend → Railway
1. Go to https://railway.app → New Project → Deploy from GitHub
2. Add a MySQL plugin
3. Set environment variables from `.env.example`
4. Deploy!

## 🔑 Admin Access
Navigate to **Admin** tab → enter password `jamroom2025`

## 🛠 Tech Stack
- **Frontend:** Vanilla HTML/CSS/JS
- **Backend:** Node.js + Express
- **Database:** MySQL
- **Frontend Host:** Surge.sh
- **Backend Host:** Railway (recommended)
