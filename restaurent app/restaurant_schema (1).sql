-- ===================================================================
-- HASHTAG INDIA RESTAURANT ANALYTICS DATABASE SCHEMA
-- Based on Toast POS structure with sample data
-- ===================================================================
CREATE DATABASE RESTAURANT_ANALYTICS;
CREATE SCHEMA RESTAURANT_ANALYTICS.RAW_DATA;

-- In Snowflake SQL Worksheet
USE DATABASE RESTAURANT_ANALYTICS;
USE SCHEMA RAW_DATA;

CREATE OR REPLACE STAGE APP_ASSETS
    DIRECTORY = (ENABLE = TRUE);

-- Drop existing tables if they exist
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS menu_items CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS locations CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS employee_schedules CASCADE;
DROP TABLE IF EXISTS inventory_items CASCADE;
DROP TABLE IF EXISTS inventory_transactions CASCADE;
DROP TABLE IF EXISTS customer_reviews CASCADE;
DROP TABLE IF EXISTS payment_types CASCADE;

-- ===================================================================
-- CORE TABLES
-- ===================================================================

-- Locations table (10 franchises across USA)
CREATE TABLE locations (
    location_id VARCHAR(50) PRIMARY KEY,
    location_name VARCHAR(200),
    address VARCHAR(300),
    city VARCHAR(100),
    state VARCHAR(2),
    zip_code VARCHAR(10),
    phone VARCHAR(20),
    opened_date DATE,
    timezone VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE
);

-- Categories table
CREATE TABLE categories (
    category_id VARCHAR(50) PRIMARY KEY,
    category_name VARCHAR(100),
    display_order INT,
    is_active BOOLEAN DEFAULT TRUE
);

-- Menu Items table (from actual menu)
CREATE TABLE menu_items (
    item_id VARCHAR(50) PRIMARY KEY,
    item_name VARCHAR(200),
    category_id VARCHAR(50) REFERENCES categories(category_id),
    description TEXT,
    selling_price DECIMAL(10,2),
    cost_price DECIMAL(10,2),  -- COGS (Cost of Goods Sold)
    prep_time_minutes INT,
    calories INT,
    is_vegetarian BOOLEAN,
    is_spicy BOOLEAN,
    is_active BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Payment Types
CREATE TABLE payment_types (
    payment_type_id VARCHAR(50) PRIMARY KEY,
    payment_type_name VARCHAR(50)
);

-- Orders table (main transaction table)
CREATE TABLE orders (
    order_id VARCHAR(50) PRIMARY KEY,
    location_id VARCHAR(50) REFERENCES locations(location_id),
    order_number INT,
    order_date DATE,
    order_time TIME,
    order_timestamp TIMESTAMP,
    order_type VARCHAR(50), -- Dine-in, Takeout, Delivery, Catering
    table_number VARCHAR(20),
    server_id VARCHAR(50),
    customer_name VARCHAR(200),
    customer_phone VARCHAR(20),
    subtotal DECIMAL(10,2),
    tax_amount DECIMAL(10,2),
    tip_amount DECIMAL(10,2),
    discount_amount DECIMAL(10,2),
    total_amount DECIMAL(10,2),
    payment_type_id VARCHAR(50) REFERENCES payment_types(payment_type_id),
    status VARCHAR(50), -- Completed, Cancelled, Refunded
    notes TEXT
);

-- Order Items table (line items)
CREATE TABLE order_items (
    order_item_id VARCHAR(50) PRIMARY KEY,
    order_id VARCHAR(50) REFERENCES orders(order_id),
    item_id VARCHAR(50) REFERENCES menu_items(item_id),
    item_name VARCHAR(200),
    quantity INT,
    unit_price DECIMAL(10,2),
    unit_cost DECIMAL(10,2),
    line_total DECIMAL(10,2),
    modifications TEXT,
    is_voided BOOLEAN DEFAULT FALSE
);

-- ===================================================================
-- EMPLOYEE & LABOR TABLES
-- ===================================================================

CREATE TABLE employees (
    employee_id VARCHAR(50) PRIMARY KEY,
    location_id VARCHAR(50) REFERENCES locations(location_id),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role VARCHAR(50), -- Server, Cook, Manager, Cashier
    hourly_rate DECIMAL(10,2),
    hire_date DATE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE employee_schedules (
    schedule_id VARCHAR(50) PRIMARY KEY,
    employee_id VARCHAR(50) REFERENCES employees(employee_id),
    location_id VARCHAR(50) REFERENCES locations(location_id),
    shift_date DATE,
    clock_in_time TIMESTAMP,
    clock_out_time TIMESTAMP,
    hours_worked DECIMAL(5,2),
    labor_cost DECIMAL(10,2)
);

-- ===================================================================
-- INVENTORY TABLES
-- ===================================================================

CREATE TABLE inventory_items (
    inventory_item_id VARCHAR(50) PRIMARY KEY,
    item_name VARCHAR(200),
    unit_of_measure VARCHAR(50), -- lbs, kg, units, gallons
    category VARCHAR(100), -- Proteins, Vegetables, Dairy, Spices, etc.
    reorder_point DECIMAL(10,2),
    unit_cost DECIMAL(10,2)
);

CREATE TABLE inventory_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    location_id VARCHAR(50) REFERENCES locations(location_id),
    inventory_item_id VARCHAR(50) REFERENCES inventory_items(inventory_item_id),
    transaction_date DATE,
    transaction_type VARCHAR(50), -- Purchase, Usage, Waste, Adjustment
    quantity DECIMAL(10,2),
    unit_cost DECIMAL(10,2),
    total_cost DECIMAL(10,2),
    supplier_name VARCHAR(200),
    notes TEXT
);

-- ===================================================================
-- CUSTOMER REVIEWS TABLE
-- ===================================================================

CREATE TABLE customer_reviews (
    review_id VARCHAR(50) PRIMARY KEY,
    location_id VARCHAR(50) REFERENCES locations(location_id),
    review_date DATE,
    platform VARCHAR(50), -- Google, Yelp, Facebook
    rating DECIMAL(2,1), -- 1.0 to 5.0
    review_text TEXT,
    sentiment VARCHAR(20) -- Positive, Negative, Neutral
);

-- ===================================================================
-- INSERT SAMPLE DATA
-- ===================================================================

-- Insert Locations (10 franchises)
INSERT INTO locations VALUES
('LOC001', 'Hashtag India - Aubrey', '123 Main St', 'Aubrey', 'TX', '76227', '(945) 274-3547', '2020-01-15', 'America/Chicago', TRUE),
('LOC002', 'Hashtag India - Frisco', '456 Preston Rd', 'Frisco', 'TX', '75034', '(972) 555-0101', '2020-06-01', 'America/Chicago', TRUE),
('LOC003', 'Hashtag India - Plano', '789 Legacy Dr', 'Plano', 'TX', '75024', '(972) 555-0102', '2021-03-15', 'America/Chicago', TRUE),
('LOC004', 'Hashtag India - Irving', '321 Irving Blvd', 'Irving', 'TX', '75039', '(972) 555-0103', '2021-08-20', 'America/Chicago', TRUE),
('LOC005', 'Hashtag India - McKinney', '654 El Dorado', 'McKinney', 'TX', '75070', '(972) 555-0104', '2022-01-10', 'America/Chicago', TRUE),
('LOC006', 'Hashtag India - Dallas', '987 Mockingbird Ln', 'Dallas', 'TX', '75205', '(214) 555-0105', '2022-05-15', 'America/Chicago', TRUE),
('LOC007', 'Hashtag India - Austin', '147 Congress Ave', 'Austin', 'TX', '78701', '(512) 555-0106', '2022-09-01', 'America/Chicago', TRUE),
('LOC008', 'Hashtag India - Houston', '258 Westheimer Rd', 'Houston', 'TX', '77027', '(713) 555-0107', '2023-02-14', 'America/Chicago', TRUE),
('LOC009', 'Hashtag India - San Antonio', '369 River Walk', 'San Antonio', 'TX', '78205', '(210) 555-0108', '2023-06-20', 'America/Chicago', TRUE),
('LOC010', 'Hashtag India - Fort Worth', '741 Sundance Sq', 'Fort Worth', 'TX', '76102', '(817) 555-0109', '2023-10-05', 'America/Chicago', TRUE);

-- Insert Categories
INSERT INTO categories VALUES
('CAT001', 'Indo-Chinese', 1, TRUE),
('CAT002', 'Chaats', 2, TRUE),
('CAT003', 'Muntha Masala', 3, TRUE),
('CAT004', 'Tiffins', 4, TRUE),
('CAT005', 'Desserts', 5, TRUE),
('CAT006', 'Cakes', 6, TRUE),
('CAT007', 'Refreshments', 7, TRUE),
('CAT008', 'Biryanis', 8, TRUE),
('CAT009', 'Pulavs', 9, TRUE);

-- Insert Menu Items (from actual menu with estimated costs)
INSERT INTO menu_items VALUES
-- Indo-Chinese
('ITEM001', 'Street Style Fried Rice', 'CAT001', 'Street style fried rice with veggies', 13.99, 4.20, 12, 450, TRUE, FALSE, TRUE),
('ITEM002', 'Street Style Noodles', 'CAT001', 'Street style noodles', 14.99, 4.50, 12, 480, TRUE, FALSE, TRUE),
('ITEM003', 'Boti Fried Rice', 'CAT001', 'Fried rice with boneless chicken', 14.99, 5.20, 15, 520, FALSE, FALSE, TRUE),
('ITEM004', 'Thai Pepper Fried Rice', 'CAT001', 'Spicy Thai style fried rice', 14.99, 4.80, 12, 490, TRUE, TRUE, TRUE),

-- Chaats
('ITEM005', 'Vada Pav (1 Pcs)', 'CAT002', 'Mumbai style potato fritter burger', 5.99, 1.20, 8, 280, TRUE, TRUE, TRUE),
('ITEM006', 'Pani Puri (6 Pcs)', 'CAT002', 'Crispy puris with spicy water', 6.99, 1.50, 10, 200, TRUE, TRUE, TRUE),
('ITEM007', 'Dahi Puri (5 Pcs)', 'CAT002', 'Puris with yogurt and chutneys', 6.99, 1.80, 10, 220, TRUE, FALSE, TRUE),
('ITEM008', 'Bhel Puri', 'CAT002', 'Puffed rice mixture', 6.99, 1.40, 8, 180, TRUE, TRUE, TRUE),
('ITEM009', 'Samosa Chaat (2 Pcs)', 'CAT002', 'Samosas with chole and chutneys', 6.99, 2.10, 10, 380, TRUE, TRUE, TRUE),
('ITEM010', 'Papdi Chaat', 'CAT002', 'Crispy crackers with toppings', 6.99, 1.70, 10, 240, TRUE, TRUE, TRUE),
('ITEM011', 'Pav Bhaji', 'CAT002', 'Vegetable curry with butter buns', 6.99, 2.00, 15, 420, TRUE, FALSE, TRUE),
('ITEM012', 'Kachori Chaat', 'CAT002', 'Kachori with chutneys', 6.99, 1.90, 10, 260, TRUE, TRUE, TRUE),

-- Muntha Masala
('ITEM013', 'Mirchi Bajji Mixture', 'CAT003', 'Spicy pepper fritters mixture', 6.99, 1.80, 12, 220, TRUE, TRUE, TRUE),
('ITEM014', 'Fried Palli Mixture', 'CAT003', 'Fried peanut mixture', 6.99, 1.60, 8, 240, TRUE, TRUE, TRUE),
('ITEM015', 'Egg Mixture', 'CAT003', 'Egg based mixture', 6.99, 2.20, 10, 280, FALSE, TRUE, TRUE),
('ITEM016', 'Kaju Mixture', 'CAT003', 'Cashew based mixture', 6.99, 2.80, 10, 320, TRUE, FALSE, TRUE),

-- Tiffins
('ITEM017', 'Idly (3 Pcs)', 'CAT004', 'Steamed rice cakes', 5.99, 1.20, 15, 180, TRUE, FALSE, TRUE),
('ITEM018', 'Sambar Idly (2 Pcs)', 'CAT004', 'Idly soaked in sambar', 6.99, 1.50, 15, 220, TRUE, FALSE, TRUE),
('ITEM019', 'Ghee Podi Idly (3 Pcs)', 'CAT004', 'Idly with ghee and spice powder', 7.99, 2.00, 15, 280, TRUE, FALSE, TRUE),
('ITEM020', 'Guntur Karam Idly (3 Pcs)', 'CAT004', 'Spicy Guntur style idly', 7.99, 1.80, 15, 240, TRUE, TRUE, TRUE),
('ITEM021', 'Poori (3 Pcs)', 'CAT004', 'Deep fried wheat bread', 9.99, 2.40, 12, 380, TRUE, FALSE, TRUE),
('ITEM022', 'Plain Dosa', 'CAT004', 'Thin crispy crepe', 8.99, 1.80, 10, 220, TRUE, FALSE, TRUE),
('ITEM023', 'Masala Dosa', 'CAT004', 'Dosa with potato filling', 9.99, 2.50, 12, 320, TRUE, FALSE, TRUE),
('ITEM024', 'Hashtag Spl Dosa', 'CAT004', 'Special house dosa', 11.99, 3.20, 15, 380, TRUE, TRUE, TRUE),
('ITEM025', 'Spring Dosa', 'CAT004', 'Dosa with spring vegetables', 10.99, 2.80, 12, 340, TRUE, FALSE, TRUE),
('ITEM026', 'Paper Dosa', 'CAT004', 'Extra thin crispy dosa', 10.99, 2.20, 10, 280, TRUE, FALSE, TRUE),
('ITEM027', 'Paper Masala Dosa', 'CAT004', 'Paper thin dosa with filling', 11.99, 2.90, 12, 360, TRUE, FALSE, TRUE),
('ITEM028', 'Mysore Masala Dosa', 'CAT004', 'Spicy red chutney dosa', 10.99, 3.00, 12, 380, TRUE, TRUE, TRUE),
('ITEM029', 'Mutton Kheema Dosa', 'CAT004', 'Dosa with minced mutton', 12.99, 5.20, 18, 480, FALSE, TRUE, TRUE),
('ITEM030', 'Chole Batura', 'CAT004', 'Chickpea curry with fried bread', 10.99, 3.40, 15, 520, TRUE, FALSE, TRUE),

-- Desserts
('ITEM031', 'Rasmalai', 'CAT005', 'Cottage cheese in sweet milk', 5.99, 2.10, 5, 280, TRUE, FALSE, TRUE),
('ITEM032', 'Gulab Jamun', 'CAT005', 'Fried milk balls in syrup', 5.99, 1.80, 5, 320, TRUE, FALSE, TRUE),
('ITEM033', 'Pastries', 'CAT005', 'Assorted pastries', 3.99, 1.40, 5, 250, TRUE, FALSE, TRUE),
('ITEM034', 'Sweet Paan', 'CAT005', 'Sweet betel leaf', 1.99, 0.60, 3, 80, TRUE, FALSE, TRUE),

-- Cakes
('ITEM035', 'ButterScotch Cake (Half)', 'CAT006', 'Half kg butterscotch cake', 30.00, 12.00, 60, 1200, TRUE, FALSE, TRUE),
('ITEM036', 'ButterScotch Cake (Full)', 'CAT006', 'Full kg butterscotch cake', 55.00, 22.00, 60, 2400, TRUE, FALSE, TRUE),
('ITEM037', 'Black Forest Cake (Half)', 'CAT006', 'Half kg black forest cake', 30.00, 12.00, 60, 1300, TRUE, FALSE, TRUE),
('ITEM038', 'Black Forest Cake (Full)', 'CAT006', 'Full kg black forest cake', 55.00, 22.00, 60, 2600, TRUE, FALSE, TRUE),
('ITEM039', 'Gulab Jamun Cake (Half)', 'CAT006', 'Half kg gulab jamun cake', 35.00, 14.00, 60, 1400, TRUE, FALSE, TRUE),
('ITEM040', 'Gulab Jamun Cake (Full)', 'CAT006', 'Full kg gulab jamun cake', 65.00, 26.00, 60, 2800, TRUE, FALSE, TRUE),
('ITEM041', 'Rasmalai Cake (Half)', 'CAT006', 'Half kg rasmalai cake', 35.00, 14.00, 60, 1350, TRUE, FALSE, TRUE),
('ITEM042', 'Rasmalai Cake (Full)', 'CAT006', 'Full kg rasmalai cake', 65.00, 26.00, 60, 2700, TRUE, FALSE, TRUE),

-- Biryanis (Veg)
('ITEM043', 'Paneer Biryani (Half)', 'CAT008', 'Half tray paneer biryani', 13.99, 4.80, 25, 480, TRUE, FALSE, TRUE),
('ITEM044', 'Paneer Biryani (Full)', 'CAT008', 'Full tray paneer biryani', 41.99, 14.00, 25, 960, TRUE, FALSE, TRUE),
('ITEM045', 'Hashtag Spl Veg Biryani (Half)', 'CAT008', 'Half tray special veg biryani', 14.99, 5.20, 25, 520, TRUE, TRUE, TRUE),
('ITEM046', 'Hashtag Spl Veg Biryani (Full)', 'CAT008', 'Full tray special veg biryani', 41.99, 15.00, 25, 1040, TRUE, TRUE, TRUE),
('ITEM047', 'Egg Biryani (Half)', 'CAT008', 'Half tray egg biryani', 13.99, 4.20, 25, 440, FALSE, FALSE, TRUE),
('ITEM048', 'Egg Biryani (Full)', 'CAT008', 'Full tray egg biryani', 39.99, 12.50, 25, 880, FALSE, FALSE, TRUE),

-- Biryanis (Non-Veg)
('ITEM049', 'Chicken BB Biryani (Half)', 'CAT008', 'Half tray boneless chicken biryani', 14.99, 5.50, 30, 560, FALSE, TRUE, TRUE),
('ITEM050', 'Chicken BB Biryani (Full)', 'CAT008', 'Full tray boneless chicken biryani', 42.99, 16.50, 30, 1120, FALSE, TRUE, TRUE),
('ITEM051', 'Chicken 65 Piece Biryani (Half)', 'CAT008', 'Half tray with chicken 65', 15.99, 6.20, 30, 620, FALSE, TRUE, TRUE),
('ITEM052', 'Chicken 65 Piece Biryani (Full)', 'CAT008', 'Full tray with chicken 65', 44.99, 18.50, 30, 1240, FALSE, TRUE, TRUE),
('ITEM053', 'Vijayawada Spl Chicken Biryani (Half)', 'CAT008', 'Spicy Vijayawada style half', 15.99, 6.00, 30, 600, FALSE, TRUE, TRUE),
('ITEM054', 'Vijayawada Spl Chicken Biryani (Full)', 'CAT008', 'Spicy Vijayawada style full', 44.99, 18.00, 30, 1200, FALSE, TRUE, TRUE),
('ITEM055', 'Hashtag Spl Chicken Biryani (Half)', 'CAT008', 'House special chicken half', 15.99, 6.20, 30, 620, FALSE, TRUE, TRUE),
('ITEM056', 'Hashtag Spl Chicken Biryani (Full)', 'CAT008', 'House special chicken full', 47.99, 19.00, 30, 1240, FALSE, TRUE, TRUE),
('ITEM057', 'Mutton Fry Piece Biryani (Half)', 'CAT008', 'Half tray mutton biryani', 17.99, 8.50, 35, 680, FALSE, TRUE, TRUE),
('ITEM058', 'Mutton Fry Piece Biryani (Full)', 'CAT008', 'Full tray mutton biryani', 49.99, 25.00, 35, 1360, FALSE, TRUE, TRUE),
('ITEM059', 'Lamb Biryani Boneless (Half)', 'CAT008', 'Half tray boneless lamb', 19.99, 9.80, 35, 720, FALSE, TRUE, TRUE),
('ITEM060', 'Lamb Biryani Boneless (Full)', 'CAT008', 'Full tray boneless lamb', 47.99, 29.00, 35, 1440, FALSE, TRUE, TRUE),
('ITEM061', 'Guntur Mastan Biryani (Half)', 'CAT008', 'Very spicy Guntur style half', 16.99, 6.50, 30, 640, FALSE, TRUE, TRUE),
('ITEM062', 'Guntur Mastan Biryani (Full)', 'CAT008', 'Very spicy Guntur style full', 47.99, 19.50, 30, 1280, FALSE, TRUE, TRUE),

-- Pulavs
('ITEM063', 'Paneer Pulav (Half)', 'CAT009', 'Half tray paneer pulav', 14.99, 5.20, 20, 420, TRUE, FALSE, TRUE),
('ITEM064', 'Paneer Pulav (Full)', 'CAT009', 'Full tray paneer pulav', 41.99, 15.50, 20, 840, TRUE, FALSE, TRUE),
('ITEM065', 'Chef Spl Veg Pulav (Half)', 'CAT009', 'Special vegetable pulav half', 14.99, 5.00, 20, 400, TRUE, FALSE, TRUE),
('ITEM066', 'Chef Spl Veg Pulav (Full)', 'CAT009', 'Special vegetable pulav full', 41.99, 15.00, 20, 800, TRUE, FALSE, TRUE),
('ITEM067', 'Vijayawada Spl Chicken Pulav (Half)', 'CAT009', 'Spicy chicken pulav half', 15.99, 6.20, 25, 520, FALSE, TRUE, TRUE),
('ITEM068', 'Vijayawada Spl Chicken Pulav (Full)', 'CAT009', 'Spicy chicken pulav full', 40.99, 18.50, 25, 1040, FALSE, TRUE, TRUE),
('ITEM069', 'Chicken Fry Piece Pulav (Half)', 'CAT009', 'Chicken fry pulav half', 16.99, 6.50, 25, 540, FALSE, TRUE, TRUE),
('ITEM070', 'Chicken Fry Piece Pulav (Full)', 'CAT009', 'Chicken fry pulav full', 47.99, 19.50, 25, 1080, FALSE, TRUE, TRUE),
('ITEM071', 'Mutton Fry Piece Pulav (Half)', 'CAT009', 'Mutton pulav half', 17.99, 8.80, 30, 620, FALSE, TRUE, TRUE),
('ITEM072', 'Mutton Fry Piece Pulav (Full)', 'CAT009', 'Mutton pulav full', 47.99, 26.00, 30, 1240, FALSE, TRUE, TRUE),
('ITEM073', 'Fish Pulav (Half)', 'CAT009', 'Fish pulav half', 16.99, 7.50, 25, 480, FALSE, FALSE, TRUE),
('ITEM074', 'Fish Pulav (Full)', 'CAT009', 'Fish pulav full', 47.99, 22.50, 25, 960, FALSE, FALSE, TRUE),
('ITEM075', 'Shrimp Pulav (Half)', 'CAT009', 'Shrimp pulav half', 16.99, 8.20, 25, 460, FALSE, FALSE, TRUE),
('ITEM076', 'Shrimp Pulav (Full)', 'CAT009', 'Shrimp pulav full', 47.99, 24.50, 25, 920, FALSE, FALSE, TRUE),
('ITEM077', 'Tandoori Chicken Pulav (Half)', 'CAT009', 'Tandoori chicken pulav half', 16.99, 6.80, 25, 560, FALSE, TRUE, TRUE),
('ITEM078', 'Tandoori Chicken Pulav (Full)', 'CAT009', 'Tandoori chicken pulav full', 47.99, 20.00, 25, 1120, FALSE, TRUE, TRUE),

-- Drinks (Cold)
('ITEM079', 'Mango Lassi', 'CAT007', 'Sweet mango yogurt drink', 5.99, 1.80, 5, 220, TRUE, FALSE, TRUE),
('ITEM080', 'Sweet Lassi', 'CAT007', 'Sweet yogurt drink', 5.99, 1.50, 5, 180, TRUE, FALSE, TRUE),
('ITEM081', 'Salt Lassi', 'CAT007', 'Salted yogurt drink', 5.99, 1.50, 5, 160, TRUE, FALSE, TRUE),
('ITEM082', 'Badam Milk', 'CAT007', 'Almond milk drink', 5.99, 2.20, 5, 240, TRUE, FALSE, TRUE),
('ITEM083', 'Nimbu Masala Soda', 'CAT007', 'Spiced lemon soda', 4.99, 1.20, 3, 120, TRUE, FALSE, TRUE),
('ITEM084', 'Coke/Sprite/Diet Coke/Pepsi', 'CAT007', 'Soft drinks', 1.99, 0.60, 1, 140, TRUE, FALSE, TRUE),
('ITEM085', 'Thums Up', 'CAT007', 'Indian cola', 2.99, 1.00, 1, 150, TRUE, FALSE, TRUE),
('ITEM086', 'Water Bottle', 'CAT007', 'Bottled water', 0.99, 0.30, 1, 0, TRUE, FALSE, TRUE),

-- Drinks (Hot)
('ITEM087', 'Irani Chai Small', 'CAT007', 'Small Indian tea', 1.00, 0.30, 5, 80, TRUE, FALSE, TRUE),
('ITEM088', 'Irani Chai Large', 'CAT007', 'Large Indian tea', 2.00, 0.50, 5, 120, TRUE, FALSE, TRUE),
('ITEM089', 'Masala Tea Small', 'CAT007', 'Small spiced tea', 1.00, 0.35, 5, 90, TRUE, FALSE, TRUE),
('ITEM090', 'Masala Tea Large', 'CAT007', 'Large spiced tea', 2.00, 0.60, 5, 140, TRUE, FALSE, TRUE),
('ITEM091', 'Coffee', 'CAT007', 'Hot coffee', 2.99, 0.80, 5, 100, TRUE, FALSE, TRUE);

-- Insert Payment Types
INSERT INTO payment_types VALUES
('PAY001', 'Cash'),
('PAY002', 'Credit Card'),
('PAY003', 'Debit Card'),
('PAY004', 'Mobile Payment'),
('PAY005', 'Gift Card');

-- Insert Employees (sample for LOC001)
INSERT INTO employees VALUES
('EMP001', 'LOC001', 'Raj', 'Kumar', 'Manager', 25.00, '2020-01-15', TRUE),
('EMP002', 'LOC001', 'Priya', 'Sharma', 'Server', 15.00, '2020-02-01', TRUE),
('EMP003', 'LOC001', 'Amit', 'Patel', 'Cook', 18.00, '2020-01-20', TRUE),
('EMP004', 'LOC001', 'Neha', 'Singh', 'Server', 15.00, '2020-03-15', TRUE),
('EMP005', 'LOC001', 'Vikram', 'Reddy', 'Cook', 18.00, '2020-04-01', TRUE),
('EMP006', 'LOC001', 'Anjali', 'Desai', 'Cashier', 14.00, '2020-05-10', TRUE),
('EMP007', 'LOC001', 'Rahul', 'Mehta', 'Server', 15.00, '2021-01-05', TRUE),
('EMP008', 'LOC001', 'Deepa', 'Iyer', 'Cook', 18.00, '2021-02-15', TRUE);

-- Insert Inventory Items (key ingredients)
INSERT INTO inventory_items VALUES
('INV001', 'Basmati Rice', 'lbs', 'Grains', 50, 1.20),
('INV002', 'Chicken (Boneless)', 'lbs', 'Proteins', 30, 3.50),
('INV003', 'Chicken (With Bone)', 'lbs', 'Proteins', 25, 2.80),
('INV004', 'Mutton', 'lbs', 'Proteins', 20, 8.50),
('INV005', 'Paneer', 'lbs', 'Dairy', 15, 4.50),
('INV006', 'Onions', 'lbs', 'Vegetables', 40, 0.60),
('INV007', 'Tomatoes', 'lbs', 'Vegetables', 40, 0.80),
('INV008', 'Potatoes', 'lbs', 'Vegetables', 50, 0.40),
('INV009', 'Yogurt', 'gallons', 'Dairy', 10, 8.00),
('INV010', 'Cooking Oil', 'gallons', 'Oils', 15, 12.00),
('INV011', 'Ghee', 'lbs', 'Dairy', 10, 15.00),
('INV012', 'Biryani Masala', 'lbs', 'Spices', 5, 12.00),
('INV013', 'Garam Masala', 'lbs', 'Spices', 5, 10.00),
('INV014', 'Turmeric', 'lbs', 'Spices', 5, 8.00),
('INV015', 'Coriander', 'lbs', 'Spices', 5, 6.00),
('INV016', 'Cumin', 'lbs', 'Spices', 5, 7.00),
('INV017', 'Mint Leaves', 'lbs', 'Herbs', 3, 4.00),
('INV018', 'Cilantro', 'lbs', 'Herbs', 3, 3.50),
('INV019', 'Green Chilies', 'lbs', 'Vegetables', 5, 2.50),
('INV020', 'Ginger-Garlic Paste', 'lbs', 'Condiments', 10, 5.00),
('INV021', 'Tamarind', 'lbs', 'Condiments', 5, 6.00),
('INV022', 'Jaggery', 'lbs', 'Sweeteners', 10, 3.00),
('INV023', 'Idli Rice', 'lbs', 'Grains', 30, 1.50),
('INV024', 'Urad Dal', 'lbs', 'Grains', 20, 1.80),
('INV025', 'Sambar Powder', 'lbs', 'Spices', 5, 9.00);

-- ===================================================================
-- INDEXES FOR PERFORMANCE
-- ===================================================================

-- Note: Snowflake auto-manages clustering, but these are logical indexes
-- for query optimization patterns

-- Note: Sample orders and transactions will be generated using 
-- Snowflake Python worksheet (see separate script)

select top 100* from orders;

-- Run this query to see all tables
   SHOW TABLES IN DATABASE restaurant_analytics;
