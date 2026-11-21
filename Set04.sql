CREATE EXTENSION IF NOT EXISTS citext;
-- SRM ALPHA PostgreSQL Assessment — SET 4
-- Scenario: Instagram - Posts, Likes, Follows
-- Problem summary: Design a PostgreSQL schema for an Instagram-like social feed. Users create posts (image/video with caption), other users like posts, comment on them, follow users (directional), and use hashtags & mentions in captions. Need: (a) build a user's feed = posts from users they follow, ordered by recency; (b) count likes per post efficiently; (c) search posts by hashtag; (d) find all posts where a given user was mentioned. The system has 500M users and 100M posts/day.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Instagram: Posts, Likes, Follows
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), username citext UNIQUE NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE posts (post_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, media_url text, media_type text NOT NULL CHECK(media_type IN ('image','video','text')), caption text, created_at timestamptz NOT NULL DEFAULT now(), likes_count bigint NOT NULL DEFAULT 0);
CREATE TABLE follows (follower_id uuid REFERENCES users ON DELETE CASCADE, followed_id uuid REFERENCES users ON DELETE CASCADE, created_at timestamptz DEFAULT now(), PRIMARY KEY(follower_id,followed_id), CHECK(follower_id<>followed_id));
CREATE TABLE likes (user_id uuid REFERENCES users ON DELETE CASCADE, post_id uuid REFERENCES posts ON DELETE CASCADE, created_at timestamptz DEFAULT now(), PRIMARY KEY(user_id,post_id));
CREATE TABLE comments (comment_id bigserial PRIMARY KEY, post_id uuid NOT NULL REFERENCES posts ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, body text NOT NULL, created_at timestamptz DEFAULT now());
CREATE TABLE hashtags (hashtag_id bigserial PRIMARY KEY, tag citext UNIQUE NOT NULL);
CREATE TABLE post_hashtags (post_id uuid REFERENCES posts ON DELETE CASCADE, hashtag_id bigint REFERENCES hashtags ON DELETE CASCADE, PRIMARY KEY(post_id,hashtag_id));
CREATE TABLE mentions (post_id uuid REFERENCES posts ON DELETE CASCADE, mentioned_user_id uuid REFERENCES users ON DELETE CASCADE, PRIMARY KEY(post_id,mentioned_user_id));
CREATE INDEX posts_user_feed_idx ON posts(user_id,created_at DESC);
CREATE INDEX follows_followed_idx ON follows(followed_id,follower_id);
CREATE INDEX likes_post_idx ON likes(post_id);
CREATE INDEX post_hashtags_tag_idx ON post_hashtags(hashtag_id,post_id);
CREATE INDEX mentions_user_idx ON mentions(mentioned_user_id,post_id);
CREATE INDEX comments_post_recent_idx ON comments(post_id,created_at DESC);
-- Trade-off: likes_count is denormalized for fast reads and must be maintained by application logic or triggers.


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
