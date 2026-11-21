-- SRM ALPHA PostgreSQL Assessment — SET 15
-- Scenario: Rapido - Bike Taxi
-- Problem summary: Design a PostgreSQL schema for Rapido. Riders request a bike-taxi ride; the system assigns a nearby captain (driver) with a matching vehicle class (bike, auto, cab). A ride has pickup, drop, fare, surge, and status. Captains have documents (DL, RC, insurance) with verification status and expiry. Each captain has one active shift per day with online/offline time slots. Need: (a) find available captains within 2km of a pickup, (b) daily earnings per captain, (c) list captains whose documents expire in the next 15 days.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Rapido: Bike Taxi
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE riders (rider_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text UNIQUE);
CREATE TABLE captains (captain_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text UNIQUE, is_online boolean NOT NULL DEFAULT false, latitude double precision, longitude double precision);
CREATE TABLE vehicles (vehicle_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), captain_id uuid NOT NULL REFERENCES captains ON DELETE CASCADE, vehicle_class text NOT NULL CHECK(vehicle_class IN ('bike','auto','cab')), registration_no text UNIQUE NOT NULL, is_active boolean DEFAULT false);
CREATE UNIQUE INDEX one_active_vehicle_per_captain ON vehicles(captain_id) WHERE is_active;
CREATE TABLE rides (ride_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), rider_id uuid NOT NULL REFERENCES riders ON DELETE RESTRICT, captain_id uuid REFERENCES captains ON DELETE SET NULL, vehicle_class text NOT NULL, pickup_lat double precision NOT NULL, pickup_lon double precision NOT NULL, drop_lat double precision NOT NULL, drop_lon double precision NOT NULL, fare numeric(12,2) NOT NULL CHECK(fare>=0), surge numeric(5,2) NOT NULL DEFAULT 1, status text NOT NULL, requested_at timestamptz DEFAULT now(), completed_at timestamptz);
CREATE TABLE captain_documents (document_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), captain_id uuid NOT NULL REFERENCES captains ON DELETE CASCADE, document_type text NOT NULL CHECK(document_type IN ('DL','RC','insurance')), verification_status text NOT NULL, expires_on date NOT NULL, document_url text NOT NULL);
CREATE TABLE shifts (shift_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), captain_id uuid NOT NULL REFERENCES captains ON DELETE CASCADE, shift_date date NOT NULL, online_from timestamptz NOT NULL, offline_at timestamptz, UNIQUE(captain_id,shift_date), CHECK(offline_at IS NULL OR offline_at>=online_from));
CREATE TABLE earnings (earning_id bigserial PRIMARY KEY, captain_id uuid NOT NULL REFERENCES captains ON DELETE RESTRICT, ride_id uuid REFERENCES rides ON DELETE SET NULL, amount numeric(12,2) NOT NULL, earned_at timestamptz DEFAULT now());
CREATE INDEX captains_available_location_idx ON captains(latitude,longitude) WHERE is_online;
CREATE INDEX rides_captain_date_idx ON rides(captain_id,completed_at);
CREATE INDEX docs_expiry_idx ON captain_documents(expires_on) WHERE verification_status='verified';
CREATE INDEX earnings_captain_date_idx ON earnings(captain_id,earned_at DESC);
CREATE INDEX shifts_captain_date_idx ON shifts(captain_id,shift_date);
-- Trade-off: PostGIS geography/GiST is recommended for accurate 2km proximity; partial indexes target online captains.


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
