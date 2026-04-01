# JamRoom Booking System — Backend Documentation

## Tech Stack
- **Database**: MySQL 8.0+
- **Backend API**: Node.js + Express.js
- **ORM**: mysql2 (raw queries for performance)
- **Auth**: JWT (jsonwebtoken) + bcrypt
- **Frontend**: HTML5 + CSS3 + Vanilla JS (React-compatible)

---

## Database Setup

```bash
# 1. Start MySQL
mysql -u root -p

# 2. Run the schema
SOURCE /path/to/schema.sql;

# 3. Verify tables
USE jamroom_db;
SHOW TABLES;
```

---

## Tables Overview

| Table | Purpose |
|---|---|
| `users` | All club members and admins |
| `jam_rooms` | Individual practice rooms |
| `time_slots` | Pre-defined booking slots by day type |
| `bookings` | Core booking records |
| `night_perm_requests` | Extension requests past 10 PM |
| `events` | Battle of Bands / in-house events |
| `weekend_booking_options` | Stores 1hr vs 2hr choice for weekends |
| `booking_audit_log` | Full admin audit trail |

---

## Business Rules (Enforced in DB + API)

| Rule | Enforcement |
|---|---|
| Book only 1 day in advance | `sp_book_slot` stored procedure check |
| Max 7 days in advance | Stored procedure |
| One slot per user per day | `UNIQUE KEY uq_user_day` |
| One user per slot | `UNIQUE KEY uq_slot_date_room` |
| Weekday slots: 5–10 PM, 1 hr | `time_slots` seed data |
| Weekend slots: 9 AM–10 PM, 2 hr (default) | `time_slots` seed data |
| Weekend 1 hr option | `weekend_booking_options` table |
| Night perm requires admin approval | `night_perm_requests.status` ENUM |
| Priority booking for events | `bookings.booking_type` field |

---

## API Routes (Express.js)

### Auth
```
POST   /api/auth/register     → Register new member
POST   /api/auth/login        → Login → returns JWT token
POST   /api/auth/logout       → Invalidate token
```

### Slots
```
GET    /api/slots?date=YYYY-MM-DD    → Get all slots + availability for a date
GET    /api/slots/available?date=    → Only available slots
```

### Bookings
```
POST   /api/bookings              → Create booking (calls sp_book_slot)
GET    /api/bookings/mine         → My bookings (auth required)
DELETE /api/bookings/:id          → Cancel booking
GET    /api/bookings/schedule?date=YYYY-MM-DD  → Day's full schedule (public)
```

### Night Perms
```
POST   /api/night-perm            → Submit night perm request
GET    /api/night-perm/pending    → Admin: get all pending (admin only)
PATCH  /api/night-perm/:id        → Admin: approve/reject
```

### Admin
```
GET    /api/admin/bookings        → All bookings with filters
PATCH  /api/admin/bookings/:id/priority   → Toggle priority
DELETE /api/admin/bookings/:id    → Force cancel any booking
POST   /api/events                → Create event
GET    /api/events                → List events
```

---

## Sample API Request — Book a Slot

```http
POST /api/bookings
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "slot_id": 3,
  "booking_date": "2025-04-15",
  "purpose": "Battle of Bands rehearsal",
  "members_count": 5,
  "night_perm": {
    "requested": true,
    "end_time": "01:00:00",
    "reason": "Need to finish recording our original song"
  }
}
```

### Response
```json
{
  "success": true,
  "booking_id": 42,
  "message": "Slot confirmed! Night perm request sent for admin approval.",
  "data": {
    "slot": "7:00 PM – 8:00 PM",
    "date": "2025-04-15",
    "room": "Main Jam Room",
    "night_perm_status": "pending"
  }
}
```

---

## Useful Queries for Demo

```sql
-- 1. See tomorrow's full schedule
SELECT * FROM vw_bookings_with_details
WHERE booking_date = DATE_ADD(CURDATE(), INTERVAL 1 DAY)
ORDER BY start_time;

-- 2. Check slot availability for a date
SELECT ts.slot_label, ts.start_time, ts.duration_mins,
       b.booking_id, u.full_name, u.band_name, b.booking_type
FROM time_slots ts
LEFT JOIN bookings b ON ts.slot_id = b.slot_id
                     AND b.booking_date = '2025-04-15'
                     AND b.status != 'cancelled'
LEFT JOIN users u ON b.user_id = u.user_id
WHERE ts.day_type = 'weekday'
ORDER BY ts.slot_order;

-- 3. Admin: pending night perms
SELECT * FROM vw_pending_night_perms;

-- 4. Audit trail for a booking
SELECT * FROM booking_audit_log WHERE booking_id = 1;

-- 5. Most frequent bookers (leaderboard)
SELECT u.full_name, u.band_name, COUNT(*) as total_bookings
FROM bookings b JOIN users u ON b.user_id = u.user_id
WHERE b.status = 'confirmed'
GROUP BY u.user_id ORDER BY total_bookings DESC;
```

---

## Project Folder Structure

```
jamroom/
├── frontend/
│   └── index.html           ← Full responsive frontend (single file)
│
├── backend/
│   ├── sql/
│   │   └── schema.sql       ← Complete MySQL schema + seed data
│   │
│   ├── routes/
│   │   ├── auth.js
│   │   ├── bookings.js
│   │   ├── slots.js
│   │   ├── nightPerm.js
│   │   └── admin.js
│   │
│   ├── middleware/
│   │   ├── auth.js          ← JWT verification
│   │   └── adminOnly.js     ← Role check
│   │
│   ├── db.js                ← MySQL connection pool
│   ├── server.js            ← Express app entry point
│   └── .env                 ← DB credentials (not committed)
│
└── README.md
```
