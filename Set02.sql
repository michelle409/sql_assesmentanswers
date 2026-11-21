-- SRM ALPHA PostgreSQL Assessment — SET 2
-- Scenario: Ola Cabs - Rides & Drivers
-- Problem summary: Design a PostgreSQL schema for Ola's ride dispatch and billing. A rider requests a ride from a pickup to a drop location (with lat/long and address), the system matches a nearby available driver, the driver accepts, trip starts, trip ends with final fare computed from distance + time + surge. Riders can rate drivers and vice versa. Drivers own one or more vehicles; only one is 'active' at a time. Need: (a) find drivers within 3km of a point, (b) a rider's last 20 rides fast, (c) daily payout per driver.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Ola Cabs: Rides & Drivers
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE riders (rider_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text UNIQUE NOT NULL);
CREATE TABLE drivers (driver_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text UNIQUE NOT NULL, is_available boolean NOT NULL DEFAULT false, latitude double precision, longitude double precision);
CREATE TABLE vehicles (vehicle_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), driver_id uuid NOT NULL REFERENCES drivers ON DELETE CASCADE, registration_no text UNIQUE NOT NULL, vehicle_type text NOT NULL, is_active boolean NOT NULL DEFAULT false);
CREATE UNIQUE INDEX one_active_vehicle_per_driver ON vehicles(driver_id) WHERE is_active;
CREATE TABLE rides (ride_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), rider_id uuid NOT NULL REFERENCES riders ON DELETE RESTRICT, driver_id uuid REFERENCES drivers ON DELETE SET NULL, pickup_address text NOT NULL, pickup_lat double precision NOT NULL, pickup_lon double precision NOT NULL, drop_address text NOT NULL, drop_lat double precision NOT NULL, drop_lon double precision NOT NULL, requested_at timestamptz NOT NULL DEFAULT now(), started_at timestamptz, ended_at timestamptz, distance_km numeric(8,2), duration_minutes integer, surge_multiplier numeric(5,2) NOT NULL DEFAULT 1, final_fare numeric(12,2), status text NOT NULL);
CREATE TABLE ride_ratings (ride_id uuid REFERENCES rides ON DELETE CASCADE, rater_type text NOT NULL CHECK(rater_type IN ('rider','driver')), rating smallint NOT NULL CHECK(rating BETWEEN 1 AND 5), comments text, PRIMARY KEY(ride_id,rater_type));
CREATE TABLE driver_payouts (payout_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), driver_id uuid NOT NULL REFERENCES drivers ON DELETE RESTRICT, paid_at timestamptz NOT NULL, amount numeric(12,2) NOT NULL CHECK(amount>=0));
CREATE INDEX rides_rider_recent_idx ON rides(rider_id,requested_at DESC);
CREATE INDEX rides_driver_date_idx ON rides(driver_id,ended_at);
CREATE INDEX drivers_available_idx ON drivers(is_available) WHERE is_available;
CREATE INDEX drivers_location_idx ON drivers(latitude,longitude) WHERE is_available;
CREATE INDEX payouts_driver_date_idx ON driver_payouts(driver_id,paid_at);
-- Production proximity search: PostGIS geography + GiST index is preferable to raw latitude/longitude.
-- Trade-off: location columns are simple here; PostGIS adds an extension but gives accurate radius queries.


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
