CREATE EXTENSION IF NOT EXISTS citext;
-- SRM ALPHA PostgreSQL Assessment — SET 14
-- Scenario: CRED - Credit Card Bill Management
-- Problem summary: Design a PostgreSQL schema for CRED's bill tracking (metadata only, no transaction semantics). Users link credit cards (issuer, last-four, nickname). Each card has a monthly statement (period start/end, total due, min due, due date, status: generated/paid/overdue). Users earn reward coins per bill payment, redeem on offers. Need: (a) show upcoming bills in next 7 days for a user, (b) history of statements for a card ordered by period, (c) total coins balance for a user.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- CRED: Credit Card Bill Management
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, email citext UNIQUE NOT NULL);
CREATE TABLE cards (card_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, issuer text NOT NULL, last_four char(4) NOT NULL CHECK(last_four ~ '^[0-9]{4}$'), nickname text);
CREATE TABLE statements (statement_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), card_id uuid NOT NULL REFERENCES cards ON DELETE CASCADE, period_start date NOT NULL, period_end date NOT NULL, total_due numeric(12,2) NOT NULL CHECK(total_due>=0), minimum_due numeric(12,2) NOT NULL CHECK(minimum_due>=0), due_date date NOT NULL, status text NOT NULL CHECK(status IN ('generated','paid','overdue')), UNIQUE(card_id,period_start), CHECK(period_end>=period_start));
CREATE TABLE rewards_ledger (entry_id bigserial PRIMARY KEY, user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, statement_id uuid REFERENCES statements ON DELETE SET NULL, coins_delta bigint NOT NULL, description text, created_at timestamptz DEFAULT now());
CREATE TABLE offers (offer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, coins_required bigint NOT NULL CHECK(coins_required>0));
CREATE TABLE redemptions (redemption_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, offer_id uuid NOT NULL REFERENCES offers ON DELETE RESTRICT, coins_spent bigint NOT NULL CHECK(coins_spent>0), redeemed_at timestamptz DEFAULT now());
CREATE INDEX cards_user_idx ON cards(user_id);
CREATE INDEX statements_card_period_idx ON statements(card_id,period_start DESC);
CREATE INDEX upcoming_bills_idx ON statements(due_date,user_id) WHERE status IN ('generated','overdue');
CREATE INDEX rewards_user_date_idx ON rewards_ledger(user_id,created_at DESC);
CREATE INDEX redemptions_user_idx ON redemptions(user_id,redeemed_at DESC);
-- Balance: SUM(coins_delta) plus negative redemption entries, or include redemptions in the balance query.
-- Trade-off: immutable ledger supports auditability; balance aggregation may be cached for scale.


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
