-- SRM ALPHA PostgreSQL Assessment — SET 7
-- Scenario: Flipkart - Catalog & Orders
-- Problem summary: Design a PostgreSQL schema for Flipkart's product catalog + order flow. A product has a category hierarchy (category -> subcategory -> leaf), multiple variants (size/color SKUs) each with its own price and stock per warehouse, seller info, and attributes stored as key-value (JSONB). Orders contain multiple line items, each line item is one SKU x qty with price snapshot. Need: (a) filter products by category + attribute (e.g. brand=Nike, size=9), (b) recursive category tree query, (c) per-seller daily revenue.
--
-- DESIGN NOTES
-- Tables and constraints below form a normalized relational model.
-- ON DELETE CASCADE is used for dependent/junction rows; RESTRICT protects
-- historical business records; SET NULL is used for optional references.
-- Indexes are chosen for the access patterns specified in the paper.
--
-- Flipkart: Catalog & Orders
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE categories (category_id bigserial PRIMARY KEY, parent_id bigint REFERENCES categories ON DELETE RESTRICT, name text NOT NULL);
CREATE TABLE sellers (seller_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE products (product_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), category_id bigint NOT NULL REFERENCES categories ON DELETE RESTRICT, seller_id uuid NOT NULL REFERENCES sellers ON DELETE RESTRICT, name text NOT NULL, attributes jsonb NOT NULL DEFAULT '{}');
CREATE TABLE skus (sku_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), product_id uuid NOT NULL REFERENCES products ON DELETE CASCADE, sku_code text UNIQUE NOT NULL, size text, color text, price numeric(12,2) NOT NULL CHECK(price>=0));
CREATE TABLE warehouses (warehouse_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE inventory (warehouse_id uuid REFERENCES warehouses ON DELETE CASCADE, sku_id uuid REFERENCES skus ON DELETE CASCADE, quantity integer NOT NULL CHECK(quantity>=0), PRIMARY KEY(warehouse_id,sku_id));
CREATE TABLE customers (customer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL);
CREATE TABLE customer_orders (order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(), customer_id uuid NOT NULL REFERENCES customers ON DELETE RESTRICT, ordered_at timestamptz DEFAULT now());
CREATE TABLE order_items (order_id uuid REFERENCES customer_orders ON DELETE CASCADE, sku_id uuid REFERENCES skus ON DELETE RESTRICT, quantity integer NOT NULL CHECK(quantity>0), price_snapshot numeric(12,2) NOT NULL CHECK(price_snapshot>=0), PRIMARY KEY(order_id,sku_id));
CREATE INDEX categories_parent_idx ON categories(parent_id);
CREATE INDEX products_category_idx ON products(category_id);
CREATE INDEX products_attributes_gin_idx ON products USING gin(attributes jsonb_path_ops);
CREATE INDEX skus_product_idx ON skus(product_id);
CREATE INDEX orders_customer_recent_idx ON customer_orders(customer_id,ordered_at DESC);
CREATE INDEX orders_seller_revenue_idx ON order_items(sku_id,order_id);
-- Recursive tree: WITH RECURSIVE tree AS (SELECT ... WHERE parent_id IS NULL UNION ALL SELECT c... JOIN tree p ON c.parent_id=p.category_id) SELECT * FROM tree.
-- Trade-off: JSONB makes attributes flexible; frequently filtered attributes may merit typed columns.


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
