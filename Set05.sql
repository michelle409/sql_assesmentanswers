-- SRM ALPHA PostgreSQL Assessment — SET 5
-- Scenario: Zomato - Restaurants & Reviews
-- Problem summary: Design a PostgreSQL schema for Zomato's restaurant discovery. Restaurants belong to a city and area, have cuisines (multiple), a menu with categories and items (with price, veg/non-veg, availability flag), opening hours per weekday, and photos. Users write reviews (rating 1-5 + text + photos). Need: (a) search restaurants in a city by cuisine and min-rating, (b) show top-10 dishes across a city by order count, (c) fetch average rating for a restaurant quickly.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Zomato: Restaurants & Reviews
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE cities (city_id bigserial PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE areas (area_id bigserial PRIMARY KEY, city_id bigint NOT NULL REFERENCES cities ON DELETE RESTRICT, name text NOT NULL, UNIQUE(city_id,name));
CREATE TABLE restaurants (restaurant_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), area_id bigint NOT NULL REFERENCES areas ON DELETE RESTRICT, name text NOT NULL, address text NOT NULL, avg_rating numeric(3,2) NOT NULL DEFAULT 0, rating_count integer NOT NULL DEFAULT 0);
CREATE TABLE cuisines (cuisine_id bigserial PRIMARY KEY, name text UNIQUE NOT NULL);
CREATE TABLE restaurant_cuisines (restaurant_id uuid REFERENCES restaurants ON DELETE CASCADE, cuisine_id bigint REFERENCES cuisines ON DELETE RESTRICT, PRIMARY KEY(restaurant_id,cuisine_id));
CREATE TABLE menu_categories (category_id bigserial PRIMARY KEY, restaurant_id uuid NOT NULL REFERENCES restaurants ON DELETE CASCADE, name text NOT NULL);
CREATE TABLE menu_items (item_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_id bigint NOT NULL REFERENCES menu_categories ON DELETE CASCADE, name text NOT NULL, price numeric(10,2) NOT NULL CHECK(price>=0), is_veg boolean NOT NULL, is_available boolean NOT NULL DEFAULT true, order_count bigint NOT NULL DEFAULT 0);
CREATE TABLE restaurant_hours (restaurant_id uuid REFERENCES restaurants ON DELETE CASCADE, weekday smallint CHECK(weekday BETWEEN 0 AND 6), opens_at time NOT NULL, closes_at time NOT NULL, PRIMARY KEY(restaurant_id,weekday,opens_at));
CREATE TABLE restaurant_photos (photo_id bigserial PRIMARY KEY, restaurant_id uuid NOT NULL REFERENCES restaurants ON DELETE CASCADE, photo_url text NOT NULL);
CREATE TABLE users (user_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE reviews (review_id bigserial PRIMARY KEY, restaurant_id uuid NOT NULL REFERENCES restaurants ON DELETE CASCADE, user_id uuid NOT NULL REFERENCES users ON DELETE CASCADE, rating smallint NOT NULL CHECK(rating BETWEEN 1 AND 5), review_text text, created_at timestamptz DEFAULT now(), UNIQUE(restaurant_id,user_id));
CREATE INDEX areas_city_idx ON areas(city_id);
CREATE INDEX restaurants_area_rating_idx ON restaurants(area_id,avg_rating DESC);
CREATE INDEX restaurant_cuisines_cuisine_idx ON restaurant_cuisines(cuisine_id,restaurant_id);
CREATE INDEX menu_items_order_count_idx ON menu_items(order_count DESC);
CREATE INDEX reviews_restaurant_idx ON reviews(restaurant_id);
-- Trade-off: stored rating aggregates speed discovery but require reliable maintenance when reviews change.


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
