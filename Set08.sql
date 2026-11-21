CREATE EXTENSION IF NOT EXISTS citext;
-- SRM ALPHA PostgreSQL Assessment — SET 8
-- Scenario: LinkedIn - Professional Network
-- Problem summary: Design a PostgreSQL schema for LinkedIn. Users have profiles with work experience, education, skills, and connections (bidirectional, with status: pending/accepted). Users post updates, endorse skills of connections, and companies have pages with followers. Need: (a) 'people you may know' = friends of friends excluding existing connections, (b) all work experiences of a user ordered by date, (c) count followers of a company.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- LinkedIn: Professional Network
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email citext UNIQUE NOT NULL, full_name text NOT NULL);
CREATE TABLE experiences (experience_id bigserial PRIMARY KEY, user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, company_name text NOT NULL, title text NOT NULL, start_date date NOT NULL, end_date date, CHECK(end_date IS NULL OR end_date>=start_date));
CREATE TABLE education (education_id bigserial PRIMARY KEY, user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, institution text NOT NULL, degree text, start_date date, end_date date);
CREATE TABLE skills (skill_id bigserial PRIMARY KEY, name citext UNIQUE NOT NULL);
CREATE TABLE user_skills (user_id uuid REFERENCES users ON DELETE CASCADE, skill_id bigint REFERENCES skills ON DELETE CASCADE, PRIMARY KEY(user_id,skill_id));
CREATE TABLE connections (user_low uuid REFERENCES users ON DELETE CASCADE, user_high uuid REFERENCES users ON DELETE CASCADE, requested_by uuid NOT NULL REFERENCES users ON DELETE CASCADE, status text NOT NULL CHECK(status IN ('pending','accepted')), created_at timestamptz DEFAULT now(), PRIMARY KEY(user_low,user_high), CHECK(user_low<user_high));
CREATE TABLE endorsements (endorser_id uuid REFERENCES users ON DELETE CASCADE, user_id uuid REFERENCES users ON DELETE CASCADE, skill_id bigint REFERENCES skills ON DELETE CASCADE, created_at timestamptz DEFAULT now(), PRIMARY KEY(endorser_id,user_id,skill_id));
CREATE TABLE posts (post_id bigserial PRIMARY KEY, user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, body text NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE companies (company_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text UNIQUE NOT NULL);
CREATE TABLE company_followers (company_id uuid REFERENCES companies ON DELETE CASCADE, user_id uuid REFERENCES users ON DELETE CASCADE, PRIMARY KEY(company_id,user_id));
CREATE INDEX experiences_user_dates_idx ON experiences(user_id,start_date DESC);
CREATE INDEX connections_status_idx ON connections(status,user_low,user_high);
CREATE INDEX company_followers_user_idx ON company_followers(user_id,company_id);
CREATE INDEX posts_user_recent_idx ON posts(user_id,created_at DESC);
-- Trade-off: canonical ordering of connection IDs prevents duplicate reverse edges; app normalizes the pair.


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
