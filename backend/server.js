// ============================================================
// JAMROOM BACKEND — Express + MySQL REST API
// ============================================================
require('dotenv').config();
const express  = require('express');
const cors     = require('cors');
const mysql    = require('mysql2/promise');
const bcrypt   = require('bcryptjs');
const fs       = require('fs');
const path     = require('path');

const app  = express();
const PORT = process.env.PORT || 3001;

// ─── Middleware ───────────────────────────────────────────────
app.use(cors({
  origin: [
    'https://jamroom-musicclub.surge.sh',
    'http://localhost:3000',
    'http://127.0.0.1:5500',
    'null' // allow file:// for local dev
  ],
  methods: ['GET','POST','PATCH','DELETE'],
  allowedHeaders: ['Content-Type','Authorization']
}));
app.use(express.json());

// ─── DB Pool ─────────────────────────────────────────────────
const pool = mysql.createPool({
  host:     process.env.DB_HOST     || process.env.MYSQLHOST     || 'localhost',
  port:     Number(process.env.DB_PORT || process.env.MYSQLPORT) || 3306,
  user:     process.env.DB_USER     || process.env.MYSQLUSER     || 'root',
  password: process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '',
  database: process.env.DB_NAME     || process.env.MYSQLDATABASE || 'jamroom_db',
  waitForConnections: true,
  connectionLimit: 10,
  multipleStatements: true,
});

// Verify connection and auto-run schema.sql if empty
pool.getConnection()
  .then(async c => {
    console.log('✅ MySQL connected');
    try {
      const [rows] = await c.query("SHOW TABLES LIKE 'users'");
      if (rows.length === 0) {
        console.log('📦 Empty database detected. Running schema.sql...');
        const schemaPath = path.join(__dirname, 'schema.sql');
        const sql = fs.readFileSync(schemaPath, 'utf8');
        await c.query(sql);
        console.log('🎸 Database successfully initialized!');
      }
    } catch (e) {
      console.error('❌ Failed to run schema:', e.message);
    } finally {
      c.release();
    }
  })
  .catch(e => console.error('❌ MySQL connection failed:', e.message));

// ─── HEALTH ──────────────────────────────────────────────────
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ─── BOOKINGS ────────────────────────────────────────────────

// GET /api/bookings?date=YYYY-MM-DD
app.get('/api/bookings', async (req, res) => {
  try {
    const { date } = req.query;
    let sql = `
      SELECT
        b.booking_id,
        b.booking_date,
        b.status,
        b.booking_type AS type,
        b.purpose,
        b.members_count,
        b.booked_at,
        b.slot_id,
        u.full_name   AS name,
        u.band_name   AS band,
        ts.slot_label AS slot,
        ts.start_time,
        ts.day_type,
        jr.room_name,
        npr.status    AS night_perm_status,
        CASE WHEN npr.perm_id IS NOT NULL AND npr.status != 'rejected' THEN 1 ELSE 0 END AS night_perm
      FROM bookings b
      JOIN users      u   ON b.user_id = u.user_id
      JOIN time_slots ts  ON b.slot_id = ts.slot_id
      JOIN jam_rooms  jr  ON b.room_id = jr.room_id
      LEFT JOIN night_perm_requests npr ON npr.booking_id = b.booking_id
      WHERE b.status != 'cancelled'
    `;
    const params = [];
    if (date) {
      sql += ' AND b.booking_date = ?';
      params.push(date);
    }
    sql += ' ORDER BY b.booking_date, ts.start_time';
    const [rows] = await pool.query(sql, params);
    res.json({ success: true, data: rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// GET /api/bookings/slot-status?date=YYYY-MM-DD
// Returns which slot_ids are booked on a given date
app.get('/api/bookings/slot-status', async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ success: false, error: 'date required' });
    const [rows] = await pool.query(
      `SELECT b.slot_id, u.full_name AS name, u.band_name AS band, b.booking_type AS type
       FROM bookings b
       JOIN users u ON b.user_id = u.user_id
       WHERE b.booking_date = ? AND b.status != 'cancelled'`,
      [date]
    );
    // Map slotId → booking info
    const map = {};
    rows.forEach(r => { map[r.slot_id] = r; });
    res.json({ success: true, data: map });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/bookings — create a booking
app.post('/api/bookings', async (req, res) => {
  const { name, band, members, purpose, slot_id, booking_date, night_perm, night_perm_end, night_reason } = req.body;
  if (!name || !slot_id || !booking_date) {
    return res.status(400).json({ success: false, error: 'name, slot_id and booking_date are required' });
  }
  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();

    // Find or create user by name+band
    let [users] = await conn.query(
      'SELECT user_id FROM users WHERE full_name = ? AND band_name <=> ?',
      [name, band || null]
    );
    let userId;
    if (users.length > 0) {
      userId = users[0].user_id;
    } else {
      const [ins] = await conn.query(
        'INSERT INTO users (full_name, email, phone, password_hash, role, band_name) VALUES (?,?,?,?,?,?)',
        [name, `${name.toLowerCase().replace(/\s/g,'_')}@jamroom.local`, '0000000000', 'no-auth', 'member', band || null]
      );
      userId = ins.insertId;
    }

    // Check slot not already taken
    const [existing] = await conn.query(
      `SELECT booking_id FROM bookings
       WHERE slot_id = ? AND booking_date = ? AND status != 'cancelled'`,
      [slot_id, booking_date]
    );
    if (existing.length > 0) {
      await conn.rollback();
      return res.status(409).json({ success: false, error: 'Slot already booked' });
    }

    // Insert booking
    const [result] = await conn.query(
      `INSERT INTO bookings (user_id, room_id, slot_id, booking_date, status, booking_type, purpose, members_count)
       VALUES (?, 1, ?, ?, 'confirmed', 'regular', ?, ?)`,
      [userId, slot_id, booking_date, purpose || null, members || 1]
    );
    const bookingId = result.insertId;

    // Night perm
    if (night_perm && night_reason) {
      const till = night_perm_end === '02:00' ? '02:00:00' : '01:00:00';
      await conn.query(
        `INSERT INTO night_perm_requests (booking_id, user_id, request_date, end_time, reason)
         VALUES (?, ?, ?, ?, ?)`,
        [bookingId, userId, booking_date, till, night_reason]
      );
    }

    // Audit log
    await conn.query(
      `INSERT INTO booking_audit_log (booking_id, action, performed_by, new_status) VALUES (?,?,?,?)`,
      [bookingId, 'created', userId, 'confirmed']
    );

    await conn.commit();
    res.json({ success: true, booking_id: bookingId });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  } finally {
    conn.release();
  }
});

// PATCH /api/bookings/:id/cancel
app.patch('/api/bookings/:id/cancel', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query(
      `UPDATE bookings SET status='cancelled', cancelled_at=NOW() WHERE booking_id=?`, [id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// PATCH /api/bookings/:id/priority
app.patch('/api/bookings/:id/priority', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query(
      `UPDATE bookings SET booking_type = IF(booking_type='priority','regular','priority') WHERE booking_id=?`, [id]
    );
    const [rows] = await pool.query(`SELECT booking_type FROM bookings WHERE booking_id=?`, [id]);
    res.json({ success: true, type: rows[0]?.booking_type });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── NIGHT PERMS ─────────────────────────────────────────────

// GET /api/night-perms
app.get('/api/night-perms', async (req, res) => {
  try {
    const [rows] = await pool.query(`
      SELECT
        npr.perm_id, npr.status, npr.reason,
        DATE_FORMAT(npr.end_time,'%l:%i %p') AS till,
        DATE_FORMAT(npr.request_date,'%a, %e %b') AS date_label,
        u.full_name AS user, u.band_name AS band,
        ts.slot_label AS slot
      FROM night_perm_requests npr
      JOIN users      u  ON npr.user_id   = u.user_id
      JOIN bookings   b  ON npr.booking_id = b.booking_id
      JOIN time_slots ts ON b.slot_id     = ts.slot_id
      ORDER BY npr.created_at DESC
    `);
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// PATCH /api/night-perms/:id  { status: 'approved'|'rejected' }
app.patch('/api/night-perms/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    if (!['approved','rejected'].includes(status)) {
      return res.status(400).json({ success: false, error: 'Invalid status' });
    }
    await pool.query(
      `UPDATE night_perm_requests SET status=?, reviewed_at=NOW() WHERE perm_id=?`, [status, id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── ADMIN AUTH ──────────────────────────────────────────────

// POST /api/admin/login  { password }
app.post('/api/admin/login', (req, res) => {
  const { password } = req.body;
  const correct = process.env.ADMIN_PASSWORD || 'jamroom2025';
  if (password === correct) {
    res.json({ success: true, token: Buffer.from(`admin:${Date.now()}`).toString('base64') });
  } else {
    res.status(401).json({ success: false, error: 'Wrong password' });
  }
});

// ─── STATS ───────────────────────────────────────────────────

// GET /api/stats
app.get('/api/stats', async (req, res) => {
  try {
    const today = new Date().toISOString().split('T')[0];
    const [[todayBookings]] = await pool.query(
      `SELECT COUNT(*) AS cnt FROM bookings WHERE booking_date=? AND status!='cancelled'`, [today]
    );
    const [[pending]] = await pool.query(
      `SELECT COUNT(*) AS cnt FROM night_perm_requests WHERE status='pending'`
    );
    const [[approved]] = await pool.query(
      `SELECT COUNT(*) AS cnt FROM night_perm_requests WHERE status='approved'`
    );
    const WEEKDAY_TOTAL = 5;
    res.json({
      success: true,
      data: {
        today_bookings:   todayBookings.cnt,
        available_today:  Math.max(0, WEEKDAY_TOTAL - todayBookings.cnt),
        pending_night_perms: pending.cnt,
        approved_night_perms: approved.cnt,
      }
    });
  } catch (err) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ─── Start ────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`🎸 JamRoom API running on http://localhost:${PORT}`);
});
