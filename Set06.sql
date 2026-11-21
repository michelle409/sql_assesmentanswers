-- SRM ALPHA PostgreSQL Assessment — SET 6
-- Scenario: BookMyShow - Movie Ticket Booking
-- Problem summary: Design a PostgreSQL schema for BookMyShow. Movies have multiple shows across cinemas and screens; each show is on one screen at one datetime. A screen has seats arranged by row & column with tier (gold, silver, platinum). Users book one or more seats for a show; a seat cannot be double-booked. Need: (a) prevent two users from booking the same seat for the same show, (b) show available seats for a given show in < 100ms, (c) cancel a booking within 1 hour of show start is disallowed.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- BookMyShow: Movie Ticket Booking
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE booking_state AS ENUM ('confirmed','cancelled');
CREATE TABLE cinemas (cinema_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, city text NOT NULL);
CREATE TABLE screens (screen_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), cinema_id uuid NOT NULL REFERENCES cinemas ON DELETE CASCADE, name text NOT NULL);
CREATE TABLE movies (movie_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, duration_minutes integer NOT NULL CHECK(duration_minutes>0));
CREATE TABLE seats (seat_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), screen_id uuid NOT NULL REFERENCES screens ON DELETE CASCADE, row_label text NOT NULL, seat_number integer NOT NULL, tier text NOT NULL CHECK(tier IN ('gold','silver','platinum')), UNIQUE(screen_id,row_label,seat_number));
CREATE TABLE shows (show_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), movie_id uuid NOT NULL REFERENCES movies ON DELETE RESTRICT, screen_id uuid NOT NULL REFERENCES screens ON DELETE RESTRICT, starts_at timestamptz NOT NULL, UNIQUE(screen_id,starts_at));
CREATE TABLE users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE bookings (booking_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users ON DELETE RESTRICT, show_id uuid NOT NULL REFERENCES shows ON DELETE RESTRICT, status booking_state NOT NULL DEFAULT 'confirmed', booked_at timestamptz DEFAULT now());
CREATE TABLE booking_seats (show_id uuid NOT NULL REFERENCES shows ON DELETE CASCADE, seat_id uuid NOT NULL REFERENCES seats ON DELETE RESTRICT, booking_id uuid NOT NULL REFERENCES bookings ON DELETE CASCADE, PRIMARY KEY(show_id,seat_id));
CREATE INDEX shows_movie_time_idx ON shows(movie_id,starts_at);
CREATE INDEX bookings_user_recent_idx ON bookings(user_id,booked_at DESC);
CREATE INDEX booking_seats_booking_idx ON booking_seats(booking_id);
-- Available seats: SELECT s.* FROM seats s JOIN shows sh ON sh.screen_id=s.screen_id LEFT JOIN booking_seats bs ON bs.show_id=sh.show_id AND bs.seat_id=s.seat_id WHERE sh.show_id=$1 AND bs.seat_id IS NULL.
-- Cancellation cutoff must be enforced in a stored procedure/trigger using show.starts_at; a CHECK cannot reference another table.
-- Trade-off: unique (show_id, seat_id) prevents double-booking; cancellation policy needs controlled update path.


-- NORMALIZATION JUSTIFICATION
-- 1NF: Each table has a primary key and stores single/atomic values; repeating
--      collections (items, tags, memberships, etc.) are represented as child
--      or junction rows rather than repeating columns.
-- 2NF: Non-key attributes depend on the whole candidate key. In composite-key
--      junction/detail tables, attributes describe the complete relationship
--      (for example, quantity/price belongs to an order-item pair).
-- 3NF: Descriptive attributes are kept with their own entities; non-key
--      attributes are not intentionally stored as facts about another
--      non-key attribute. Historical snapshots are retained only where the
--      scenario explicitly requires them.
-- BCNF: BCNF is not claimed universally. It depends on all business
--      functional dependencies, including candidate keys, being known.
--      The schema is designed to reach at least 3NF; validate BCNF against
--      the complete real-world dependency set before claiming it.
