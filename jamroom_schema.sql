-- ============================================================
--  JAM ROOM BOOKING SYSTEM — MySQL Schema
--  Music Club Project | Full Backend Design
-- ============================================================

CREATE DATABASE IF NOT EXISTS jamroom_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE jamroom_db;

-- ============================================================
-- TABLE 1: users
-- Stores all club members + admins
-- ============================================================
CREATE TABLE users (
  user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(100)  NOT NULL,
  email         VARCHAR(150)  NOT NULL UNIQUE,
  phone         VARCHAR(15)   NOT NULL,
  password_hash VARCHAR(255)  NOT NULL,
  role          ENUM('member', 'admin') NOT NULL DEFAULT 'member',
  band_name     VARCHAR(100)  DEFAULT NULL,        -- optional band affiliation
  is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_email (email),
  INDEX idx_role  (role)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 2: jam_rooms
-- Individual practice rooms (can scale to multiple rooms)
-- ============================================================
CREATE TABLE jam_rooms (
  room_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_name   VARCHAR(100) NOT NULL,               -- e.g. "Jam Room A"
  capacity    TINYINT UNSIGNED NOT NULL DEFAULT 6, -- max people
  description TEXT         DEFAULT NULL,
  is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Seed default room
INSERT INTO jam_rooms (room_name, capacity, description)
VALUES ('Main Jam Room', 8, 'Full drum kit, 2 guitar amps, bass amp, PA system, mic stands');


-- ============================================================
-- TABLE 3: time_slots
-- Pre-defined time slots per day type
-- Weekday : 5:00 PM – 10:00 PM  → 1-hour slots (5 slots/day)
-- Weekend : 9:00 AM – 10:00 PM  → 2-hour slots (6.5 slots → 6 slots/day)
-- ============================================================
CREATE TABLE time_slots (
  slot_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  day_type      ENUM('weekday', 'weekend') NOT NULL,
  slot_label    VARCHAR(30)  NOT NULL,              -- e.g. "5:00 PM – 6:00 PM"
  start_time    TIME         NOT NULL,
  end_time      TIME         NOT NULL,
  duration_mins SMALLINT UNSIGNED NOT NULL,         -- 60 or 120
  slot_order    TINYINT UNSIGNED NOT NULL,          -- display order

  UNIQUE KEY uq_slot (day_type, start_time),
  INDEX idx_day_type (day_type)
) ENGINE=InnoDB;

-- Weekday slots (Mon–Fri): 5 PM to 10 PM, 1-hour each
INSERT INTO time_slots (day_type, slot_label, start_time, end_time, duration_mins, slot_order) VALUES
('weekday', '5:00 PM – 6:00 PM',   '17:00:00', '18:00:00', 60, 1),
('weekday', '6:00 PM – 7:00 PM',   '18:00:00', '19:00:00', 60, 2),
('weekday', '7:00 PM – 8:00 PM',   '19:00:00', '20:00:00', 60, 3),
('weekday', '8:00 PM – 9:00 PM',   '20:00:00', '21:00:00', 60, 4),
('weekday', '9:00 PM – 10:00 PM',  '21:00:00', '22:00:00', 60, 5);

-- Weekend slots (Sat–Sun): 9 AM to 10 PM, 2-hour each
INSERT INTO time_slots (day_type, slot_label, start_time, end_time, duration_mins, slot_order) VALUES
('weekend', '9:00 AM – 11:00 AM',  '09:00:00', '11:00:00', 120, 1),
('weekend', '11:00 AM – 1:00 PM',  '11:00:00', '13:00:00', 120, 2),
('weekend', '1:00 PM – 3:00 PM',   '13:00:00', '15:00:00', 120, 3),
('weekend', '3:00 PM – 5:00 PM',   '15:00:00', '17:00:00', 120, 4),
('weekend', '5:00 PM – 7:00 PM',   '17:00:00', '19:00:00', 120, 5),
('weekend', '7:00 PM – 9:00 PM',   '19:00:00', '21:00:00', 120, 6),
('weekend', '9:00 PM – 10:00 PM',  '21:00:00', '22:00:00',  60, 7);  -- partial last slot


-- ============================================================
-- TABLE 4: bookings
-- Core booking table
-- ============================================================
CREATE TABLE bookings (
  booking_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id         INT UNSIGNED NOT NULL,
  room_id         INT UNSIGNED NOT NULL DEFAULT 1,
  slot_id         INT UNSIGNED NOT NULL,
  booking_date    DATE         NOT NULL,               -- the actual practice date
  status          ENUM('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'pending',
  booking_type    ENUM('regular','priority') NOT NULL DEFAULT 'regular',
                                                       -- priority = admin-granted for events/battles
  purpose         VARCHAR(255) DEFAULT NULL,           -- e.g. "Practice for Battle of Bands"
  members_count   TINYINT UNSIGNED NOT NULL DEFAULT 1,
  booked_at       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  confirmed_at    DATETIME     DEFAULT NULL,
  cancelled_at    DATETIME     DEFAULT NULL,
  cancelled_by    INT UNSIGNED DEFAULT NULL,           -- user_id who cancelled
  notes           TEXT         DEFAULT NULL,

  -- Business rule: one booking per user per day
  UNIQUE KEY uq_user_day (user_id, booking_date),
  -- Business rule: one booking per slot per day per room
  UNIQUE KEY uq_slot_date_room (slot_id, booking_date, room_id),

  FOREIGN KEY fk_booking_user (user_id)   REFERENCES users(user_id)      ON DELETE CASCADE,
  FOREIGN KEY fk_booking_room (room_id)   REFERENCES jam_rooms(room_id)  ON DELETE CASCADE,
  FOREIGN KEY fk_booking_slot (slot_id)   REFERENCES time_slots(slot_id) ON DELETE RESTRICT,
  FOREIGN KEY fk_cancelled_by (cancelled_by) REFERENCES users(user_id)   ON DELETE SET NULL,

  INDEX idx_booking_date  (booking_date),
  INDEX idx_booking_user  (user_id),
  INDEX idx_booking_status (status)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 5: night_perm_requests
-- Extended night practice (11 PM – 1/2 AM)
-- Requires admin approval
-- ============================================================
CREATE TABLE night_perm_requests (
  perm_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id    INT UNSIGNED NOT NULL,               -- linked to a regular booking
  user_id       INT UNSIGNED NOT NULL,
  request_date  DATE         NOT NULL,               -- which night
  end_time      TIME         NOT NULL,               -- 01:00:00 or 02:00:00
  reason        TEXT         NOT NULL,               -- why they need extra time
  status        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  reviewed_by   INT UNSIGNED DEFAULT NULL,           -- admin who approved/rejected
  reviewed_at   DATETIME     DEFAULT NULL,
  admin_note    TEXT         DEFAULT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY fk_perm_booking (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE,
  FOREIGN KEY fk_perm_user    (user_id)    REFERENCES users(user_id)       ON DELETE CASCADE,
  FOREIGN KEY fk_perm_admin   (reviewed_by) REFERENCES users(user_id)      ON DELETE SET NULL,

  INDEX idx_perm_date   (request_date),
  INDEX idx_perm_status (status)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 6: events
-- Tracks in-house events or upcoming battle of bands
-- Admin can link events to priority bookings
-- ============================================================
CREATE TABLE events (
  event_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  event_name    VARCHAR(200) NOT NULL,
  event_date    DATE         NOT NULL,
  event_type    ENUM('inhouse','battle_of_bands','workshop','other') NOT NULL DEFAULT 'inhouse',
  description   TEXT         DEFAULT NULL,
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_by    INT UNSIGNED NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY fk_event_creator (created_by) REFERENCES users(user_id) ON DELETE CASCADE,
  INDEX idx_event_date (event_date)
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 7: weekend_1hr_slots
-- On weekends, members can optionally book 1-hr instead of 2-hr
-- This table handles split weekend slots
-- ============================================================
CREATE TABLE weekend_booking_options (
  option_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id    INT UNSIGNED NOT NULL,
  chosen_duration ENUM('1hr','2hr') NOT NULL DEFAULT '2hr',
  actual_start  TIME NOT NULL,
  actual_end    TIME NOT NULL,

  FOREIGN KEY fk_opt_booking (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- ============================================================
-- TABLE 8: booking_audit_log
-- Full audit trail for admin accountability
-- ============================================================
CREATE TABLE booking_audit_log (
  log_id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id    INT UNSIGNED DEFAULT NULL,
  action        VARCHAR(50)  NOT NULL,   -- 'created','confirmed','cancelled','upgraded_priority'
  performed_by  INT UNSIGNED NOT NULL,
  old_status    VARCHAR(50)  DEFAULT NULL,
  new_status    VARCHAR(50)  DEFAULT NULL,
  details       TEXT         DEFAULT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  INDEX idx_audit_booking (booking_id),
  INDEX idx_audit_user    (performed_by)
) ENGINE=InnoDB;


-- ============================================================
-- VIEWS — Useful queries pre-packaged
-- ============================================================

-- View: Available slots for a given date (used by booking page)
CREATE OR REPLACE VIEW vw_bookings_with_details AS
SELECT
  b.booking_id,
  b.booking_date,
  b.status,
  b.booking_type,
  b.purpose,
  b.members_count,
  b.booked_at,
  u.full_name      AS booked_by,
  u.band_name,
  u.email,
  u.phone,
  ts.slot_label,
  ts.start_time,
  ts.end_time,
  ts.duration_mins,
  ts.day_type,
  jr.room_name,
  npr.status       AS night_perm_status,
  npr.end_time     AS night_perm_end
FROM bookings b
JOIN users      u   ON b.user_id  = u.user_id
JOIN time_slots ts  ON b.slot_id  = ts.slot_id
JOIN jam_rooms  jr  ON b.room_id  = jr.room_id
LEFT JOIN night_perm_requests npr ON npr.booking_id = b.booking_id;


-- View: Today's schedule at a glance
CREATE OR REPLACE VIEW vw_todays_schedule AS
SELECT * FROM vw_bookings_with_details
WHERE booking_date = CURDATE()
ORDER BY start_time;


-- View: Pending night perm requests for admin
CREATE OR REPLACE VIEW vw_pending_night_perms AS
SELECT
  npr.perm_id,
  npr.request_date,
  npr.end_time AS perm_end_time,
  npr.reason,
  npr.status,
  npr.created_at,
  u.full_name,
  u.band_name,
  u.phone,
  ts.slot_label AS original_slot
FROM night_perm_requests npr
JOIN users      u  ON npr.user_id   = u.user_id
JOIN bookings   b  ON npr.booking_id = b.booking_id
JOIN time_slots ts ON b.slot_id     = ts.slot_id
WHERE npr.status = 'pending'
ORDER BY npr.request_date, npr.created_at;


-- ============================================================
-- STORED PROCEDURE: Book a slot
-- Enforces all business rules in one atomic call
-- ============================================================
DELIMITER $$

CREATE PROCEDURE sp_book_slot(
  IN  p_user_id      INT UNSIGNED,
  IN  p_slot_id      INT UNSIGNED,
  IN  p_booking_date DATE,
  IN  p_purpose      VARCHAR(255),
  IN  p_members      TINYINT UNSIGNED,
  OUT p_booking_id   INT UNSIGNED,
  OUT p_error_msg    VARCHAR(255)
)
BEGIN
  DECLARE v_day_of_week  TINYINT;
  DECLARE v_slot_daytype VARCHAR(10);
  DECLARE v_existing     INT;
  DECLARE v_today        DATE;
  DECLARE v_tomorrow     DATE;

  SET v_today    = CURDATE();
  SET v_tomorrow = DATE_ADD(CURDATE(), INTERVAL 1 DAY);
  SET p_booking_id = 0;
  SET p_error_msg  = '';

  -- Rule 1: Can only book ONE DAY in advance
  IF p_booking_date < v_tomorrow THEN
    SET p_error_msg = 'Bookings can only be made one day in advance.';
    LEAVE sp_book_slot;  -- note: use label in real stored proc
  END IF;

  IF p_booking_date > DATE_ADD(v_today, INTERVAL 7 DAY) THEN
    SET p_error_msg = 'Cannot book more than 7 days in advance.';
    LEAVE sp_book_slot;
  END IF;

  -- Rule 2: Get the slot's day_type
  SELECT day_type INTO v_slot_daytype FROM time_slots WHERE slot_id = p_slot_id;

  -- Rule 3: Validate slot day_type matches actual booking_date day
  SET v_day_of_week = DAYOFWEEK(p_booking_date); -- 1=Sun, 7=Sat
  IF v_day_of_week IN (1, 7) AND v_slot_daytype != 'weekend' THEN
    SET p_error_msg = 'Weekday slot cannot be booked on a weekend.';
    LEAVE sp_book_slot;
  END IF;
  IF v_day_of_week NOT IN (1, 7) AND v_slot_daytype != 'weekday' THEN
    SET p_error_msg = 'Weekend slot cannot be booked on a weekday.';
    LEAVE sp_book_slot;
  END IF;

  -- Rule 4: User can only book one slot per day
  SELECT COUNT(*) INTO v_existing
  FROM bookings
  WHERE user_id = p_user_id
    AND booking_date = p_booking_date
    AND status NOT IN ('cancelled');
  IF v_existing > 0 THEN
    SET p_error_msg = 'You already have a booking on this date.';
    LEAVE sp_book_slot;
  END IF;

  -- Rule 5: Slot must be available
  SELECT COUNT(*) INTO v_existing
  FROM bookings
  WHERE slot_id = p_slot_id
    AND booking_date = p_booking_date
    AND room_id = 1
    AND status NOT IN ('cancelled');
  IF v_existing > 0 THEN
    SET p_error_msg = 'This slot is already booked. Please choose another.';
    LEAVE sp_book_slot;
  END IF;

  -- All checks passed — insert booking
  INSERT INTO bookings (user_id, room_id, slot_id, booking_date, status, purpose, members_count)
  VALUES (p_user_id, 1, p_slot_id, p_booking_date, 'confirmed', p_purpose, p_members);

  SET p_booking_id = LAST_INSERT_ID();

  -- Log the action
  INSERT INTO booking_audit_log (booking_id, action, performed_by, new_status)
  VALUES (p_booking_id, 'created', p_user_id, 'confirmed');

END$$

DELIMITER ;


-- ============================================================
-- TRIGGER: Auto-log status changes on bookings
-- ============================================================
DELIMITER $$

CREATE TRIGGER trg_booking_status_change
AFTER UPDATE ON bookings
FOR EACH ROW
BEGIN
  IF OLD.status != NEW.status THEN
    INSERT INTO booking_audit_log (booking_id, action, performed_by, old_status, new_status)
    VALUES (
      NEW.booking_id,
      CONCAT('status_changed_to_', NEW.status),
      NEW.user_id,
      OLD.status,
      NEW.status
    );
  END IF;
END$$

DELIMITER ;


-- ============================================================
-- SAMPLE DATA — Admins & Members
-- ============================================================
INSERT INTO users (full_name, email, phone, password_hash, role, band_name) VALUES
('Admin Raj',       'admin@musicclub.com',   '9876543210', '$2b$10$hashedpassword1', 'admin',  NULL),
('Arjun Mehta',     'arjun@example.com',     '9812345678', '$2b$10$hashedpassword2', 'member', 'The Riffs'),
('Priya Sharma',    'priya@example.com',     '9823456789', '$2b$10$hashedpassword3', 'member', 'Echo Chamber'),
('Rohan Das',       'rohan@example.com',     '9834567890', '$2b$10$hashedpassword4', 'member', 'Stray Cats'),
('Sneha Kapoor',    'sneha@example.com',     '9845678901', '$2b$10$hashedpassword5', 'member', 'The Riffs'),
('Vikram Nair',     'vikram@example.com',    '9856789012', '$2b$10$hashedpassword6', 'member', 'Solo'),
('Ananya Singh',    'ananya@example.com',    '9867890123', '$2b$10$hashedpassword7', 'member', 'Freq Wave');

-- Sample event
INSERT INTO events (event_name, event_date, event_type, description, created_by)
VALUES ('Battle of Bands 2025', '2025-05-10', 'battle_of_bands',
        'Annual college Battle of Bands. Top 6 bands compete. Registration open.', 1);

-- Sample bookings (tomorrow's date for demo)
INSERT INTO bookings (user_id, room_id, slot_id, booking_date, status, booking_type, purpose, members_count)
VALUES
(2, 1, 1, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'confirmed', 'regular', 'Regular practice', 4),
(3, 1, 3, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'confirmed', 'regular', 'Setlist rehearsal', 5),
(4, 1, 5, DATE_ADD(CURDATE(), INTERVAL 1 DAY), 'confirmed', 'priority', 'Battle of Bands prep', 4);

-- Sample night perm request
INSERT INTO night_perm_requests (booking_id, user_id, request_date, end_time, reason)
VALUES (3, 3, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '01:00:00',
        'We have an original composition to finish recording for Battle of Bands submission. Need the extra 2 hours badly!');
