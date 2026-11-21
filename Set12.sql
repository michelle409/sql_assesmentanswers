-- SRM ALPHA PostgreSQL Assessment — SET 12
-- Scenario: Dream11 - Fantasy Sports Teams
-- Problem summary: Design a PostgreSQL schema for Dream11. A match has two real teams playing at a venue on a datetime. Real players belong to real teams and have roles (BAT/BOWL/AR/WK) and credit value. Users create fantasy teams (11 players, 1 captain, 1 vice-captain) for a given match, subject to rules (credit cap, max 7 from one real team). Contests are joined by many fantasy teams with an entry fee and prize breakdown. Scoring computes after match. Need: (a) leaderboard for a contest, (b) validate fantasy team rules before save, (c) user's all fantasy teams for an upcoming match.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Dream11: Fantasy Sports Teams
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE real_teams (real_team_id bigserial PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE venues (venue_id bigserial PRIMARY KEY, name text NOT NULL, city text NOT NULL);
CREATE TABLE matches (match_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), team1_id bigint NOT NULL REFERENCES real_teams ON DELETE RESTRICT, team2_id bigint NOT NULL REFERENCES real_teams ON DELETE RESTRICT, venue_id bigint REFERENCES venues ON DELETE SET NULL, starts_at timestamptz NOT NULL, CHECK(team1_id<>team2_id));
CREATE TABLE players (player_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), real_team_id bigint NOT NULL REFERENCES real_teams ON DELETE RESTRICT, name text NOT NULL, role text NOT NULL CHECK(role IN ('BAT','BOWL','AR','WK')), credit numeric(4,1) NOT NULL CHECK(credit>0));
CREATE TABLE users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE fantasy_teams (fantasy_team_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, match_id uuid NOT NULL REFERENCES matches ON DELETE CASCADE, name text NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE fantasy_team_players (fantasy_team_id uuid REFERENCES fantasy_teams ON DELETE CASCADE, player_id uuid REFERENCES players ON DELETE RESTRICT, is_captain boolean NOT NULL DEFAULT false, is_vice_captain boolean NOT NULL DEFAULT false, PRIMARY KEY(fantasy_team_id,player_id), CHECK(NOT(is_captain AND is_vice_captain)));
CREATE UNIQUE INDEX one_captain_per_fantasy_team ON fantasy_team_players(fantasy_team_id) WHERE is_captain;
CREATE UNIQUE INDEX one_vice_captain_per_fantasy_team ON fantasy_team_players(fantasy_team_id) WHERE is_vice_captain;
CREATE TABLE contests (contest_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), match_id uuid NOT NULL REFERENCES matches ON DELETE CASCADE, entry_fee numeric(10,2) NOT NULL CHECK(entry_fee>=0), prize_breakdown jsonb NOT NULL DEFAULT '{}');
CREATE TABLE contest_entries (contest_id uuid REFERENCES contests ON DELETE CASCADE, fantasy_team_id uuid REFERENCES fantasy_teams ON DELETE CASCADE, points numeric(10,2) NOT NULL DEFAULT 0, rank integer, PRIMARY KEY(contest_id,fantasy_team_id));
CREATE INDEX fantasy_user_match_idx ON fantasy_teams(user_id,match_id);
CREATE INDEX leaderboard_idx ON contest_entries(contest_id,points DESC);
CREATE INDEX players_team_idx ON players(real_team_id);
-- Enforce exactly 11 players, credit cap and max 7 from one real team in a validation function/trigger or application service.
-- Trade-off: row-level CHECK cannot validate aggregate child-row counts; explicit validation is required.


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
