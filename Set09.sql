-- SRM ALPHA PostgreSQL Assessment — SET 9
-- Scenario: Dunzo - Hyperlocal Delivery
-- Problem summary: Design a PostgreSQL schema for Dunzo's pick-and-drop task platform. A customer places a task with pickup address, drop address, item description, instructions, and optional pay-on-delivery amount. A delivery partner accepts, picks up, drops off. Pricing depends on distance (geospatial). Partners have earnings ledger and daily payouts. Need: (a) assign tasks to partners within 2km of pickup, (b) partner's earnings last 30 days, (c) all tasks currently in-flight (picked but not dropped).
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Dunzo: Hyperlocal Delivery
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE customers (customer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text UNIQUE);
CREATE TABLE partners (partner_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, phone text UNIQUE, is_online boolean DEFAULT false, latitude double precision, longitude double precision);
CREATE TABLE delivery_tasks (task_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid NOT NULL REFERENCES customers ON DELETE RESTRICT, partner_id uuid REFERENCES partners ON DELETE SET NULL, pickup_address text NOT NULL, pickup_lat double precision NOT NULL, pickup_lon double precision NOT NULL, drop_address text NOT NULL, drop_lat double precision NOT NULL, drop_lon double precision NOT NULL, item_description text NOT NULL, instructions text, cod_amount numeric(12,2) CHECK(cod_amount>=0), price numeric(12,2) NOT NULL CHECK(price>=0), status text NOT NULL CHECK(status IN ('created','accepted','picked','dropped','cancelled')), created_at timestamptz DEFAULT now(), picked_at timestamptz, dropped_at timestamptz);
CREATE TABLE earnings_ledger (entry_id bigserial PRIMARY KEY, partner_id uuid NOT NULL REFERENCES partners ON DELETE RESTRICT, task_id uuid REFERENCES delivery_tasks ON DELETE SET NULL, amount numeric(12,2) NOT NULL, entry_type text NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE daily_payouts (payout_id bigserial PRIMARY KEY, partner_id uuid NOT NULL REFERENCES partners ON DELETE RESTRICT, payout_date date NOT NULL, amount numeric(12,2) NOT NULL, UNIQUE(partner_id,payout_date));
CREATE INDEX partners_online_location_idx ON partners(is_online,latitude,longitude) WHERE is_online;
CREATE INDEX tasks_partner_status_idx ON delivery_tasks(partner_id,status);
CREATE INDEX tasks_inflight_idx ON delivery_tasks(created_at) WHERE status='picked';
CREATE INDEX earnings_partner_date_idx ON earnings_ledger(partner_id,created_at DESC);
-- Trade-off: raw coordinates keep the DDL portable; PostGIS geography + GiST is the scalable radius-search choice.


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
