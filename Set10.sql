CREATE EXTENSION IF NOT EXISTS citext;
-- SRM ALPHA PostgreSQL Assessment — SET 10
-- Scenario: Netflix - Streaming Platform
-- Problem summary: Design a PostgreSQL schema for Netflix. Content is either Movie or Series (series has seasons and episodes). Users have profiles (up to 5 per account); each profile has a watchlist, viewing history (position-in-seconds per episode/movie), and preferences. Content has genres, cast, maturity rating, and per-country availability. Need: (a) 'continue watching' for a profile, (b) top-10 most-watched titles in India this week, (c) available content in a given country.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Netflix: Streaming Platform
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE accounts (account_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), email citext UNIQUE NOT NULL);
CREATE TABLE profiles (profile_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), account_id uuid NOT NULL REFERENCES accounts ON DELETE CASCADE, name text NOT NULL, maturity_level text, UNIQUE(account_id,name));
CREATE TABLE content (content_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), title text NOT NULL, content_type text NOT NULL CHECK(content_type IN ('movie','series')), maturity_rating text);
CREATE TABLE seasons (season_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), content_id uuid NOT NULL REFERENCES content ON DELETE CASCADE, season_number integer NOT NULL, UNIQUE(content_id,season_number));
CREATE TABLE episodes (episode_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), season_id uuid NOT NULL REFERENCES seasons ON DELETE CASCADE, episode_number integer NOT NULL, title text NOT NULL, duration_seconds integer NOT NULL, UNIQUE(season_id,episode_number));
CREATE TABLE genres (genre_id bigserial PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE content_genres (content_id uuid REFERENCES content ON DELETE CASCADE, genre_id bigint REFERENCES genres ON DELETE RESTRICT, PRIMARY KEY(content_id,genre_id));
CREATE TABLE watchlist (profile_id uuid REFERENCES profiles ON DELETE CASCADE, content_id uuid REFERENCES content ON DELETE CASCADE, added_at timestamptz DEFAULT now(), PRIMARY KEY(profile_id,content_id));
CREATE TABLE viewing_history (profile_id uuid REFERENCES profiles ON DELETE CASCADE, content_id uuid REFERENCES content ON DELETE CASCADE, episode_id uuid REFERENCES episodes ON DELETE CASCADE, position_seconds integer NOT NULL DEFAULT 0 CHECK(position_seconds>=0), watched_at timestamptz DEFAULT now(), PRIMARY KEY(profile_id,content_id,episode_id));
CREATE TABLE countries (country_code char(2) PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE availability (content_id uuid REFERENCES content ON DELETE CASCADE, country_code char(2) REFERENCES countries ON DELETE CASCADE, available_from date, available_to date, PRIMARY KEY(content_id,country_code));
CREATE INDEX profiles_account_idx ON profiles(account_id);
CREATE INDEX history_continue_idx ON viewing_history(profile_id,watched_at DESC);
CREATE INDEX availability_country_idx ON availability(country_code,content_id);
CREATE INDEX content_title_idx ON content(title);
-- Trade-off: history stores both title and episode context; a nullable episode_id represents movie-level viewing.


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
