CREATE EXTENSION IF NOT EXISTS citext;
-- SRM ALPHA PostgreSQL Assessment — SET 11
-- Scenario: PhonePe - UPI Payment Metadata
-- Problem summary: Design a PostgreSQL schema for PhonePe's UPI payment metadata (schema only - do NOT handle transactional isolation here). Users have one or more linked bank accounts and one or more UPI handles (vpa). A payment has a sender vpa, receiver vpa, amount, status (initiated/success/failed/reversed), reference id, and metadata. Users have contact list with saved vpas, and recent payees. Need: (a) fetch a user's last 50 payments fast, (b) daily settlement report by bank, (c) duplicate-payment detection (same payer+payee+amount within 30s).
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- PhonePe: UPI Payment Metadata (metadata only)
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE app_users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), full_name text NOT NULL, phone text UNIQUE NOT NULL);
CREATE TABLE bank_accounts (bank_account_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES app_users ON DELETE CASCADE, bank_name text NOT NULL, account_token text NOT NULL, UNIQUE(user_id,account_token));
CREATE TABLE upi_handles (vpa_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES app_users ON DELETE CASCADE, vpa citext UNIQUE NOT NULL, bank_account_id uuid REFERENCES bank_accounts ON DELETE SET NULL);
CREATE TABLE payments (payment_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), sender_vpa_id uuid NOT NULL REFERENCES upi_handles ON DELETE RESTRICT, receiver_vpa_id uuid NOT NULL REFERENCES upi_handles ON DELETE RESTRICT, amount numeric(14,2) NOT NULL CHECK(amount>0), status text NOT NULL CHECK(status IN ('initiated','success','failed','reversed')), reference_id text UNIQUE NOT NULL, metadata jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE saved_payees (user_id uuid REFERENCES app_users ON DELETE CASCADE, vpa_id uuid REFERENCES upi_handles ON DELETE CASCADE, nickname text, PRIMARY KEY(user_id,vpa_id));
CREATE INDEX payments_sender_recent_idx ON payments(sender_vpa_id,created_at DESC);
CREATE INDEX payments_receiver_recent_idx ON payments(receiver_vpa_id,created_at DESC);
CREATE INDEX payments_metadata_gin_idx ON payments USING gin(metadata);
CREATE INDEX bank_accounts_user_idx ON bank_accounts(user_id);
-- Duplicate detection within 30 seconds: query payer, payee, amount and created_at >= now()-interval '30 seconds'; partial/index support can be added for business-specific retention.
-- Trade-off: reference_id is unique; duplicate detection is a separate business query, not a transaction/locking design.


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
