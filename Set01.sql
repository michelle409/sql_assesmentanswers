-- SRM ALPHA PostgreSQL Assessment — SET 1
-- Scenario: Swiggy Instamart - Orders
-- Problem summary: Design a PostgreSQL schema for Swiggy Instamart's order management subsystem. The system supports customers placing grocery orders from the nearest dark store, each order containing multiple SKUs with quantity and unit price snapshot. Each order has a status lifecycle (placed, picked, packed, out_for_delivery, delivered, cancelled), is assigned to one delivery partner, has one delivery address, and may use one or more coupons. Store SKU inventory is per-dark-store. The platform needs: (a) fetch recent orders for a customer in under 50ms, (b) compute daily GMV per dark store, (c) detect out-of-stock SKUs quickly.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Swiggy Instamart: Orders
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE order_status AS ENUM ('placed','picked','packed','out_for_delivery','delivered','cancelled');
CREATE TABLE customers (customer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), full_name text NOT NULL, phone text UNIQUE NOT NULL);
CREATE TABLE dark_stores (store_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, city text NOT NULL);
CREATE TABLE delivery_partners (partner_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), full_name text NOT NULL, phone text UNIQUE);
CREATE TABLE addresses (address_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid NOT NULL REFERENCES customers ON DELETE CASCADE, line1 text NOT NULL, city text NOT NULL, postal_code text);
CREATE TABLE skus (sku_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), sku_code text UNIQUE NOT NULL, name text NOT NULL);
CREATE TABLE store_inventory (store_id uuid REFERENCES dark_stores ON DELETE CASCADE, sku_id uuid REFERENCES skus ON DELETE RESTRICT, quantity integer NOT NULL CHECK(quantity>=0), PRIMARY KEY(store_id,sku_id));
CREATE TABLE coupons (coupon_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text UNIQUE NOT NULL, discount numeric(10,2) NOT NULL CHECK(discount>=0));
CREATE TABLE orders (order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid NOT NULL REFERENCES customers ON DELETE RESTRICT, store_id uuid NOT NULL REFERENCES dark_stores ON DELETE RESTRICT, partner_id uuid REFERENCES delivery_partners ON DELETE SET NULL, address_id uuid NOT NULL REFERENCES addresses ON DELETE RESTRICT, status order_status NOT NULL DEFAULT 'placed', placed_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE order_items (order_id uuid REFERENCES orders ON DELETE CASCADE, sku_id uuid REFERENCES skus ON DELETE RESTRICT, quantity integer NOT NULL CHECK(quantity>0), unit_price numeric(12,2) NOT NULL CHECK(unit_price>=0), PRIMARY KEY(order_id,sku_id));
CREATE TABLE order_coupons (order_id uuid REFERENCES orders ON DELETE CASCADE, coupon_id uuid REFERENCES coupons ON DELETE RESTRICT, PRIMARY KEY(order_id,coupon_id));
CREATE INDEX orders_customer_recent_idx ON orders(customer_id,placed_at DESC);
CREATE INDEX orders_store_date_idx ON orders(store_id,placed_at);
CREATE INDEX inventory_oos_idx ON store_inventory(store_id,sku_id) WHERE quantity=0;
CREATE INDEX order_items_sku_idx ON order_items(sku_id);
-- Daily GMV: sum(quantity * unit_price) grouped by store and date.
-- Trade-off: normalized item snapshots preserve historical prices; reporting may benefit from a materialized aggregate.


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
