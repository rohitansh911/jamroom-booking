-- ============================================================
--  JamRoom DB — Quick Setup Schema
-- ============================================================

-- Users table
CREATE TABLE IF NOT EXISTS users (
  user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(100)  NOT NULL,
  email         VARCHAR(150)  NOT NULL UNIQUE,
  phone         VARCHAR(15)   NOT NULL DEFAULT '0000000000',
  password_hash VARCHAR(255)  NOT NULL DEFAULT 'no-auth',
  role          ENUM('member','admin') NOT NULL DEFAULT 'member',
  band_name     VARCHAR(100)  DEFAULT NULL,
  is_active     BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_email (email)
) ENGINE=InnoDB;

-- Jam rooms
CREATE TABLE IF NOT EXISTS jam_rooms (
  room_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  room_name   VARCHAR(100) NOT NULL,
  capacity    TINYINT UNSIGNED NOT NULL DEFAULT 8,
  description TEXT DEFAULT NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

INSERT IGNORE INTO jam_rooms (room_id, room_name, capacity, description)
VALUES (1, 'Main Jam Room', 8, 'Full drum kit, 2 guitar amps, bass amp, PA system, mic stands');

-- Time slots
CREATE TABLE IF NOT EXISTS time_slots (
  slot_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  day_type      ENUM('weekday','weekend') NOT NULL,
  slot_label    VARCHAR(30)  NOT NULL,
  start_time    TIME         NOT NULL,
  end_time      TIME         NOT NULL,
  duration_mins SMALLINT UNSIGNED NOT NULL,
  slot_order    TINYINT UNSIGNED NOT NULL,
  UNIQUE KEY uq_slot (day_type, start_time)
) ENGINE=InnoDB;

-- Weekday slots
INSERT IGNORE INTO time_slots (slot_id, day_type, slot_label, start_time, end_time, duration_mins, slot_order) VALUES
(1,  'weekday', '5:00 PM – 6:00 PM',   '17:00:00', '18:00:00', 60,  1),
(2,  'weekday', '6:00 PM – 7:00 PM',   '18:00:00', '19:00:00', 60,  2),
(3,  'weekday', '7:00 PM – 8:00 PM',   '19:00:00', '20:00:00', 60,  3),
(4,  'weekday', '8:00 PM – 9:00 PM',   '20:00:00', '21:00:00', 60,  4),
(5,  'weekday', '9:00 PM – 10:00 PM',  '21:00:00', '22:00:00', 60,  5);

-- Weekend 2hr slots
INSERT IGNORE INTO time_slots (slot_id, day_type, slot_label, start_time, end_time, duration_mins, slot_order) VALUES
(6,  'weekend', '9:00 AM – 11:00 AM',  '09:00:00', '11:00:00', 120, 1),
(7,  'weekend', '11:00 AM – 1:00 PM',  '11:00:00', '13:00:00', 120, 2),
(8,  'weekend', '1:00 PM – 3:00 PM',   '13:00:00', '15:00:00', 120, 3),
(9,  'weekend', '3:00 PM – 5:00 PM',   '15:00:00', '17:00:00', 120, 4),
(10, 'weekend', '5:00 PM – 7:00 PM',   '17:00:00', '19:00:00', 120, 5),
(11, 'weekend', '7:00 PM – 9:00 PM',   '19:00:00', '21:00:00', 120, 6),
(12, 'weekend', '9:00 PM – 10:00 PM',  '21:00:00', '22:00:00', 60,  7);

-- Weekend 1hr slots
INSERT IGNORE INTO time_slots (slot_id, day_type, slot_label, start_time, end_time, duration_mins, slot_order) VALUES
(13, 'weekend', '9:00 AM – 10:00 AM',  '09:00:00', '10:00:00', 60,  1),
(14, 'weekend', '10:00 AM – 11:00 AM', '10:00:00', '11:00:00', 60,  2),
(15, 'weekend', '11:00 AM – 12:00 PM', '11:00:00', '12:00:00', 60,  3),
(16, 'weekend', '12:00 PM – 1:00 PM',  '12:00:00', '13:00:00', 60,  4),
(17, 'weekend', '1:00 PM – 2:00 PM',   '13:00:00', '14:00:00', 60,  5),
(18, 'weekend', '2:00 PM – 3:00 PM',   '14:00:00', '15:00:00', 60,  6),
(19, 'weekend', '3:00 PM – 4:00 PM',   '15:00:00', '16:00:00', 60,  7),
(20, 'weekend', '4:00 PM – 5:00 PM',   '16:00:00', '17:00:00', 60,  8),
(21, 'weekend', '5:00 PM – 6:00 PM',   '17:00:00', '18:00:00', 60,  9),
(22, 'weekend', '6:00 PM – 7:00 PM',   '18:00:00', '19:00:00', 60,  10),
(23, 'weekend', '7:00 PM – 8:00 PM',   '19:00:00', '20:00:00', 60,  11),
(24, 'weekend', '8:00 PM – 9:00 PM',   '20:00:00', '21:00:00', 60,  12),
(25, 'weekend', '9:00 PM – 10:00 PM',  '21:00:00', '22:00:00', 60,  13);

-- Bookings
CREATE TABLE IF NOT EXISTS bookings (
  booking_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id       INT UNSIGNED NOT NULL,
  room_id       INT UNSIGNED NOT NULL DEFAULT 1,
  slot_id       INT UNSIGNED NOT NULL,
  booking_date  DATE         NOT NULL,
  status        ENUM('pending','confirmed','cancelled','completed') NOT NULL DEFAULT 'confirmed',
  booking_type  ENUM('regular','priority') NOT NULL DEFAULT 'regular',
  purpose       VARCHAR(255) DEFAULT NULL,
  members_count TINYINT UNSIGNED NOT NULL DEFAULT 1,
  booked_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  cancelled_at  DATETIME     DEFAULT NULL,
  UNIQUE KEY uq_slot_date (slot_id, booking_date, room_id),
  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  FOREIGN KEY (room_id) REFERENCES jam_rooms(room_id) ON DELETE CASCADE,
  FOREIGN KEY (slot_id) REFERENCES time_slots(slot_id) ON DELETE RESTRICT,
  INDEX idx_date (booking_date),
  INDEX idx_status (status)
) ENGINE=InnoDB;

-- Night permission requests
CREATE TABLE IF NOT EXISTS night_perm_requests (
  perm_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id   INT UNSIGNED NOT NULL,
  user_id      INT UNSIGNED NOT NULL,
  request_date DATE         NOT NULL,
  end_time     TIME         NOT NULL,
  reason       TEXT         NOT NULL,
  status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  reviewed_at  DATETIME     DEFAULT NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id)    REFERENCES users(user_id)       ON DELETE CASCADE,
  INDEX idx_status (status)
) ENGINE=InnoDB;

-- Audit log
CREATE TABLE IF NOT EXISTS booking_audit_log (
  log_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  booking_id   INT UNSIGNED DEFAULT NULL,
  action       VARCHAR(50)  NOT NULL,
  performed_by INT UNSIGNED NOT NULL,
  old_status   VARCHAR(50)  DEFAULT NULL,
  new_status   VARCHAR(50)  DEFAULT NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

SELECT 'JamRoom DB setup complete! 🎸' AS message;
