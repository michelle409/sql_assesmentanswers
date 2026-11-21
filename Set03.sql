-- SRM ALPHA PostgreSQL Assessment — SET 3
-- Scenario: Airbnb - Property Bookings
-- Problem summary: Design a PostgreSQL schema for Airbnb bookings. A host lists one or more properties, each with amenities (wifi, pool, parking) and photos. Guests search by city + date range + guest count and book. A booking has check-in / check-out dates, nightly rate, cleaning fee, taxes, and status. Avoid double-booking the same property for overlapping dates. Guests leave reviews after stay (one per booking). Properties have availability calendars with blackout dates. Need: (a) search available properties in a city for a date range, (b) prevent overlapping bookings at the DB level, (c) average rating per property.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Airbnb: Property Bookings
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE booking_status AS ENUM ('pending','confirmed','cancelled','completed');
CREATE TABLE hosts (host_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE guests (guest_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE properties (property_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), host_id uuid NOT NULL REFERENCES hosts ON DELETE RESTRICT, title text NOT NULL, city text NOT NULL, address text NOT NULL, max_guests integer NOT NULL CHECK(max_guests>0));
CREATE TABLE amenities (amenity_id bigserial PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE property_amenities (property_id uuid REFERENCES properties ON DELETE CASCADE, amenity_id bigint REFERENCES amenities ON DELETE RESTRICT, PRIMARY KEY(property_id,amenity_id));
CREATE TABLE property_photos (photo_id bigserial PRIMARY KEY, property_id uuid NOT NULL REFERENCES properties ON DELETE CASCADE, photo_url text NOT NULL, sort_order integer NOT NULL DEFAULT 0);
CREATE TABLE bookings (booking_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), property_id uuid NOT NULL REFERENCES properties ON DELETE RESTRICT, guest_id uuid NOT NULL REFERENCES guests ON DELETE RESTRICT, stay daterange NOT NULL, nightly_rate numeric(12,2) NOT NULL CHECK(nightly_rate>=0), cleaning_fee numeric(12,2) NOT NULL DEFAULT 0, taxes numeric(12,2) NOT NULL DEFAULT 0, status booking_status NOT NULL, CHECK(NOT isempty(stay)), EXCLUDE USING gist(property_id WITH =, stay WITH &&) WHERE(status IN ('pending','confirmed')));
CREATE TABLE reviews (review_id bigserial PRIMARY KEY, booking_id uuid UNIQUE NOT NULL REFERENCES bookings ON DELETE CASCADE, rating smallint NOT NULL CHECK(rating BETWEEN 1 AND 5), review_text text, created_at timestamptz DEFAULT now());
CREATE TABLE blackout_dates (blackout_id bigserial PRIMARY KEY, property_id uuid NOT NULL REFERENCES properties ON DELETE CASCADE, blocked daterange NOT NULL);
CREATE INDEX properties_city_guests_idx ON properties(city,max_guests);
CREATE INDEX bookings_property_stay_gist_idx ON bookings USING gist(property_id,stay);
CREATE INDEX reviews_booking_idx ON reviews(booking_id);
-- Trade-off: exclusion constraint uses GiST and btree_gist to enforce no overlapping active bookings.


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
