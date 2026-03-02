USE DATABASE RESTAURANT_ANALYTICS;
USE SCHEMA RAW_DATA;

-- Check if tables exist
SHOW TABLES;

-- Check if data loaded
SELECT COUNT(*) FROM ORDERS;
SELECT COUNT(*) FROM ORDER_ITEMS;

-- If counts are 0, use Solution 2 (the SQL file)



-- ===================================================================
-- QUICK TEST DATA GENERATOR (SQL Only - No Python)
-- Run this in Snowflake SQL Worksheet if Python notebook is not working
-- Generates 1 month of sample data for 3 locations
-- ===================================================================

USE DATABASE RESTAURANT_ANALYTICS;
USE SCHEMA RAW_DATA;

-- ===================================================================
-- STEP 1: Generate Sample Orders (Run this first)
-- ===================================================================

INSERT INTO ORDERS (
    ORDER_ID,
    LOCATION_ID,
    ORDER_NUMBER,
    ORDER_DATE,
    ORDER_TIME,
    ORDER_TIMESTAMP,
    ORDER_TYPE,
    TABLE_NUMBER,
    SERVER_ID,
    CUSTOMER_NAME,
    CUSTOMER_PHONE,
    SUBTOTAL,
    TAX_AMOUNT,
    TIP_AMOUNT,
    DISCOUNT_AMOUNT,
    TOTAL_AMOUNT,
    PAYMENT_TYPE_ID,
    STATUS,
    NOTES
)
WITH date_series AS (
    SELECT DATEADD(day, SEQ4(), '2024-11-01'::DATE) as order_date
    FROM TABLE(GENERATOR(ROWCOUNT => 30))  -- 30 days
    WHERE DATEADD(day, SEQ4(), '2024-11-01'::DATE) < '2024-12-01'::DATE
),
location_series AS (
    SELECT 'LOC001' as location_id
    UNION ALL SELECT 'LOC002'
    UNION ALL SELECT 'LOC003'
),
daily_orders AS (
    SELECT ROW_NUMBER() OVER (ORDER BY RANDOM()) as order_seq
    FROM TABLE(GENERATOR(ROWCOUNT => 40))  -- 40 orders per location per day
),
order_types AS (
    SELECT 
        CASE MOD(ABS(RANDOM()), 10)
            WHEN 0 THEN 'Delivery'
            WHEN 1 THEN 'Delivery'
            WHEN 2 THEN 'Takeout'
            WHEN 3 THEN 'Takeout'
            WHEN 4 THEN 'Takeout'
            ELSE 'Dine-in'
        END as order_type,
        RANDOM() as rand
)
SELECT 
    'ORD' || LPAD(ROW_NUMBER() OVER (ORDER BY ds.order_date, ls.location_id, do.order_seq), 8, '0') as ORDER_ID,
    ls.location_id as LOCATION_ID,
    do.order_seq as ORDER_NUMBER,
    ds.order_date as ORDER_DATE,
    TIME_FROM_PARTS(11 + MOD(ABS(RANDOM()), 12), MOD(ABS(RANDOM()), 60), 0) as ORDER_TIME,
    TIMESTAMP_FROM_PARTS(
        ds.order_date, 
        TIME_FROM_PARTS(11 + MOD(ABS(RANDOM()), 12), MOD(ABS(RANDOM()), 60), 0)
    ) as ORDER_TIMESTAMP,
    ot.order_type as ORDER_TYPE,
    CASE WHEN ot.order_type = 'Dine-in' 
         THEN 'T' || (MOD(ABS(RANDOM()), 20) + 1)
         ELSE NULL END as TABLE_NUMBER,
    'EMP00' || (MOD(ABS(RANDOM()), 8) + 1) as SERVER_ID,
    'Customer ' || (MOD(ABS(RANDOM()), 9000) + 1000) as CUSTOMER_NAME,
    '(' || (MOD(ABS(RANDOM()), 800) + 200) || ') ' || 
        (MOD(ABS(RANDOM()), 800) + 200) || '-' || 
        (MOD(ABS(RANDOM()), 9000) + 1000) as CUSTOMER_PHONE,
    ROUND((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0, 2) as SUBTOTAL,
    ROUND(((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0) * 0.0825, 2) as TAX_AMOUNT,
    CASE WHEN MOD(ABS(RANDOM()), 10) < 7 
         THEN ROUND(((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0) * 0.18, 2)
         ELSE 0 END as TIP_AMOUNT,
    0 as DISCOUNT_AMOUNT,
    ROUND(((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0) * 1.25, 2) as TOTAL_AMOUNT,
    CASE MOD(ABS(RANDOM()), 4)
        WHEN 0 THEN 'PAY001'
        WHEN 1 THEN 'PAY002'
        WHEN 2 THEN 'PAY003'
        ELSE 'PAY004'
    END as PAYMENT_TYPE_ID,
    CASE WHEN MOD(ABS(RANDOM()), 100) < 97 THEN 'Completed' ELSE 'Cancelled' END as STATUS,
    NULL as NOTES
FROM date_series ds
CROSS JOIN location_series ls
CROSS JOIN daily_orders do
CROSS JOIN order_types ot;

-- Verify orders created
SELECT 
    'Orders Created' as status,
    COUNT(*) as count,
    MIN(order_date) as first_date,
    MAX(order_date) as last_date
FROM ORDERS;

-- ===================================================================
-- STEP 2: Generate Order Items (Run this second)
-- ===================================================================

INSERT INTO ORDER_ITEMS (
    ORDER_ITEM_ID,
    ORDER_ID,
    ITEM_ID,
    ITEM_NAME,
    QUANTITY,
    UNIT_PRICE,
    UNIT_COST,
    LINE_TOTAL,
    MODIFICATIONS,
    IS_VOIDED
)
WITH menu_items_sample AS (
    SELECT 'ITEM049' as item_id, 'Chicken BB Biryani (Half)' as item_name, 14.99 as price, 5.50 as cost, 10 as weight
    UNION ALL SELECT 'ITEM050', 'Chicken BB Biryani (Full)', 42.99, 16.50, 5
    UNION ALL SELECT 'ITEM053', 'Vijayawada Spl Chicken Biryani (Half)', 15.99, 6.00, 8
    UNION ALL SELECT 'ITEM045', 'Hashtag Spl Veg Biryani (Half)', 14.99, 5.20, 6
    UNION ALL SELECT 'ITEM043', 'Paneer Biryani (Half)', 13.99, 4.80, 5
    UNION ALL SELECT 'ITEM006', 'Pani Puri (6 Pcs)', 6.99, 1.50, 7
    UNION ALL SELECT 'ITEM005', 'Vada Pav (1 Pcs)', 5.99, 1.20, 6
    UNION ALL SELECT 'ITEM009', 'Samosa Chaat (2 Pcs)', 6.99, 2.10, 5
    UNION ALL SELECT 'ITEM023', 'Masala Dosa', 9.99, 2.50, 8
    UNION ALL SELECT 'ITEM024', 'Hashtag Spl Dosa', 11.99, 3.20, 4
    UNION ALL SELECT 'ITEM017', 'Idly (3 Pcs)', 5.99, 1.20, 5
    UNION ALL SELECT 'ITEM079', 'Mango Lassi', 5.99, 1.80, 6
    UNION ALL SELECT 'ITEM084', 'Coke/Sprite/Diet Coke/Pepsi', 1.99, 0.60, 8
    UNION ALL SELECT 'ITEM032', 'Gulab Jamun', 5.99, 1.80, 3
),
orders_with_items AS (
    SELECT 
        o.order_id,
        m.item_id,
        m.item_name,
        m.price,
        m.cost,
        ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY RANDOM()) as item_rank
    FROM ORDERS o
    CROSS JOIN menu_items_sample m
    WHERE MOD(ABS(HASH(o.order_id, m.item_id)), 100) < (m.weight * 2)  -- Weight-based selection
)
SELECT 
    owi.order_id || '_ITEM' || owi.item_rank as ORDER_ITEM_ID,
    owi.order_id as ORDER_ID,
    owi.item_id as ITEM_ID,
    owi.item_name as ITEM_NAME,
    CASE WHEN MOD(ABS(RANDOM()), 10) < 8 THEN 1 ELSE 2 END as QUANTITY,
    owi.price as UNIT_PRICE,
    owi.cost as UNIT_COST,
    owi.price * CASE WHEN MOD(ABS(RANDOM()), 10) < 8 THEN 1 ELSE 2 END as LINE_TOTAL,
    NULL as MODIFICATIONS,
    FALSE as IS_VOIDED
FROM orders_with_items owi
WHERE owi.item_rank <= 3;  -- Max 3 items per order

-- Verify order items created
SELECT 
    'Order Items Created' as status,
    COUNT(*) as count,
    COUNT(DISTINCT order_id) as distinct_orders
FROM ORDER_ITEMS;

-- ===================================================================
-- STEP 3: Generate Employee Schedules (Run this third)
-- ===================================================================

INSERT INTO EMPLOYEE_SCHEDULES (
    SCHEDULE_ID,
    EMPLOYEE_ID,
    LOCATION_ID,
    SHIFT_DATE,
    CLOCK_IN_TIME,
    CLOCK_OUT_TIME,
    HOURS_WORKED,
    LABOR_COST
)
WITH date_series AS (
    SELECT DATEADD(day, SEQ4(), '2024-11-01'::DATE) as shift_date
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
    WHERE DATEADD(day, SEQ4(), '2024-11-01'::DATE) < '2024-12-01'::DATE
),
employee_series AS (
    SELECT 'EMP001' as emp_id, 25.00 as rate
    UNION ALL SELECT 'EMP002', 15.00
    UNION ALL SELECT 'EMP003', 18.00
    UNION ALL SELECT 'EMP004', 15.00
    UNION ALL SELECT 'EMP005', 18.00
),
location_series AS (
    SELECT 'LOC001' as location_id
)
SELECT 
    'SCH' || LPAD(ROW_NUMBER() OVER (ORDER BY ds.shift_date, es.emp_id), 8, '0') as SCHEDULE_ID,
    es.emp_id as EMPLOYEE_ID,
    ls.location_id as LOCATION_ID,
    ds.shift_date as SHIFT_DATE,
    TIMESTAMP_FROM_PARTS(ds.shift_date, TIME_FROM_PARTS(9 + MOD(ABS(RANDOM()), 3), 0, 0)) as CLOCK_IN_TIME,
    TIMESTAMP_FROM_PARTS(ds.shift_date, TIME_FROM_PARTS(17 + MOD(ABS(RANDOM()), 3), 0, 0)) as CLOCK_OUT_TIME,
    8.0 as HOURS_WORKED,
    8.0 * es.rate as LABOR_COST
FROM date_series ds
CROSS JOIN employee_series es
CROSS JOIN location_series ls
WHERE DAYOFWEEK(ds.shift_date) NOT IN (0, 6) OR MOD(ABS(RANDOM()), 10) < 6;  -- Weekdays + some weekends

-- Verify schedules created
SELECT 
    'Employee Schedules Created' as status,
    COUNT(*) as count
FROM EMPLOYEE_SCHEDULES;

-- ===================================================================
-- STEP 4: Generate Sample Reviews (Run this fourth)
-- ===================================================================

INSERT INTO CUSTOMER_REVIEWS (
    REVIEW_ID,
    LOCATION_ID,
    REVIEW_DATE,
    PLATFORM,
    RATING,
    REVIEW_TEXT,
    SENTIMENT
)
WITH date_series AS (
    SELECT DATEADD(day, SEQ4(), '2024-11-01'::DATE) as review_date
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
),
location_series AS (
    SELECT 'LOC001' as location_id
    UNION ALL SELECT 'LOC002'
    UNION ALL SELECT 'LOC003'
),
review_generator AS (
    SELECT ROW_NUMBER() OVER (ORDER BY RANDOM()) as review_num
    FROM TABLE(GENERATOR(ROWCOUNT => 3))  -- 3 reviews per location per month
)
SELECT 
    'REV' || LPAD(ROW_NUMBER() OVER (ORDER BY ds.review_date, ls.location_id), 8, '0') as REVIEW_ID,
    ls.location_id as LOCATION_ID,
    ds.review_date as REVIEW_DATE,
    CASE MOD(ABS(RANDOM()), 3)
        WHEN 0 THEN 'Google'
        WHEN 1 THEN 'Yelp'
        ELSE 'Facebook'
    END as PLATFORM,
    CASE 
        WHEN MOD(ABS(RANDOM()), 10) < 7 THEN 5.0
        WHEN MOD(ABS(RANDOM()), 10) < 9 THEN 4.0
        ELSE 3.0
    END as RATING,
    CASE 
        WHEN MOD(ABS(RANDOM()), 10) < 7 THEN 'Amazing biryani! Best Indian food in Texas!'
        WHEN MOD(ABS(RANDOM()), 10) < 9 THEN 'Good food, nice service.'
        ELSE 'Food was okay, nothing special.'
    END as REVIEW_TEXT,
    CASE 
        WHEN MOD(ABS(RANDOM()), 10) < 7 THEN 'Positive'
        WHEN MOD(ABS(RANDOM()), 10) < 9 THEN 'Neutral'
        ELSE 'Negative'
    END as SENTIMENT
FROM date_series ds
CROSS JOIN location_series ls
CROSS JOIN review_generator rg
WHERE MOD(ABS(HASH(ds.review_date, ls.location_id, rg.review_num)), 10) < 3;  -- Random selection

-- Verify reviews created
SELECT 
    'Customer Reviews Created' as status,
    COUNT(*) as count
FROM CUSTOMER_REVIEWS;

-- ===================================================================
-- FINAL VERIFICATION
-- ===================================================================

SELECT '=== DATA GENERATION SUMMARY ===' as summary;

SELECT 
    'ORDERS' as table_name,
    COUNT(*) as row_count,
    MIN(order_date) as earliest_date,
    MAX(order_date) as latest_date,
    ROUND(SUM(total_amount), 2) as total_revenue
FROM ORDERS
UNION ALL
SELECT 
    'ORDER_ITEMS',
    COUNT(*),
    NULL,
    NULL,
    ROUND(SUM(line_total), 2)
FROM ORDER_ITEMS
UNION ALL
SELECT 
    'EMPLOYEE_SCHEDULES',
    COUNT(*),
    MIN(shift_date),
    MAX(shift_date),
    ROUND(SUM(labor_cost), 2)
FROM EMPLOYEE_SCHEDULES
UNION ALL
SELECT 
    'CUSTOMER_REVIEWS',
    COUNT(*),
    MIN(review_date),
    MAX(review_date),
    NULL
FROM CUSTOMER_REVIEWS;

-- Sample data preview
SELECT '=== SAMPLE ORDERS ===' as preview;
SELECT * FROM ORDERS LIMIT 5;

SELECT '=== SAMPLE ORDER ITEMS ===' as preview;
SELECT * FROM ORDER_ITEMS LIMIT 5;

-- Revenue by location
SELECT '=== REVENUE BY LOCATION ===' as report;
SELECT 
    location_id,
    COUNT(*) as num_orders,
    ROUND(SUM(total_amount), 2) as total_revenue,
    ROUND(AVG(total_amount), 2) as avg_order_value
FROM ORDERS
WHERE status = 'Completed'
GROUP BY location_id
ORDER BY total_revenue DESC;

SELECT '✅ DATA GENERATION COMPLETE!' as status;




==================================================================================



-- ===================================================================
-- GENERATE CURRENT MONTH DATA (December 2024)
-- Run this in Snowflake SQL Worksheet
-- Generates data for the last 30 days from today
-- ===================================================================

USE DATABASE RESTAURANT_ANALYTICS;
USE SCHEMA RAW_DATA;

-- First, clear old data (optional - remove if you want to keep old data)
-- TRUNCATE TABLE ORDERS;
-- TRUNCATE TABLE ORDER_ITEMS;

-- ===================================================================
-- Generate Current Month Orders
-- ===================================================================

INSERT INTO ORDERS (
    ORDER_ID,
    LOCATION_ID,
    ORDER_NUMBER,
    ORDER_DATE,
    ORDER_TIME,
    ORDER_TIMESTAMP,
    ORDER_TYPE,
    TABLE_NUMBER,
    SERVER_ID,
    CUSTOMER_NAME,
    CUSTOMER_PHONE,
    SUBTOTAL,
    TAX_AMOUNT,
    TIP_AMOUNT,
    DISCOUNT_AMOUNT,
    TOTAL_AMOUNT,
    PAYMENT_TYPE_ID,
    STATUS,
    NOTES
)
WITH date_series AS (
    -- Generate last 30 days
    SELECT DATEADD(day, -SEQ4(), CURRENT_DATE()) as order_date
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
    WHERE DATEADD(day, -SEQ4(), CURRENT_DATE()) >= DATEADD(day, -30, CURRENT_DATE())
),
location_series AS (
    SELECT 'LOC001' as location_id
    UNION ALL SELECT 'LOC002'
    UNION ALL SELECT 'LOC003'
),
daily_orders AS (
    SELECT ROW_NUMBER() OVER (ORDER BY RANDOM()) as order_seq
    FROM TABLE(GENERATOR(ROWCOUNT => 40))  -- 40 orders per location per day
)
SELECT 
    'ORD' || LPAD(ROW_NUMBER() OVER (ORDER BY ds.order_date, ls.location_id, do.order_seq), 8, '0') as ORDER_ID,
    ls.location_id as LOCATION_ID,
    do.order_seq as ORDER_NUMBER,
    ds.order_date as ORDER_DATE,
    TIME_FROM_PARTS(11 + MOD(ABS(RANDOM()), 12), MOD(ABS(RANDOM()), 60), 0) as ORDER_TIME,
    TIMESTAMP_FROM_PARTS(
        ds.order_date, 
        TIME_FROM_PARTS(11 + MOD(ABS(RANDOM()), 12), MOD(ABS(RANDOM()), 60), 0)
    ) as ORDER_TIMESTAMP,
    CASE MOD(ABS(RANDOM()), 10)
        WHEN 0 THEN 'Delivery'
        WHEN 1 THEN 'Delivery'
        WHEN 2 THEN 'Takeout'
        WHEN 3 THEN 'Takeout'
        WHEN 4 THEN 'Takeout'
        ELSE 'Dine-in'
    END as ORDER_TYPE,
    CASE WHEN MOD(ABS(RANDOM()), 10) > 5
         THEN 'T' || (MOD(ABS(RANDOM()), 20) + 1)
         ELSE NULL END as TABLE_NUMBER,
    'EMP00' || (MOD(ABS(RANDOM()), 8) + 1) as SERVER_ID,
    'Customer ' || (MOD(ABS(RANDOM()), 9000) + 1000) as CUSTOMER_NAME,
    '(' || (MOD(ABS(RANDOM()), 800) + 200) || ') ' || 
        (MOD(ABS(RANDOM()), 800) + 200) || '-' || 
        (MOD(ABS(RANDOM()), 9000) + 1000) as CUSTOMER_PHONE,
    ROUND((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0, 2) as SUBTOTAL,
    ROUND(((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0) * 0.0825, 2) as TAX_AMOUNT,
    CASE WHEN MOD(ABS(RANDOM()), 10) < 7 
         THEN ROUND(((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0) * 0.18, 2)
         ELSE 0 END as TIP_AMOUNT,
    0 as DISCOUNT_AMOUNT,
    ROUND(((MOD(ABS(RANDOM()), 4000) + 1000) / 100.0) * 1.25, 2) as TOTAL_AMOUNT,
    CASE MOD(ABS(RANDOM()), 4)
        WHEN 0 THEN 'PAY001'
        WHEN 1 THEN 'PAY002'
        WHEN 2 THEN 'PAY003'
        ELSE 'PAY004'
    END as PAYMENT_TYPE_ID,
    CASE WHEN MOD(ABS(RANDOM()), 100) < 97 THEN 'Completed' ELSE 'Cancelled' END as STATUS,
    NULL as NOTES
FROM date_series ds
CROSS JOIN location_series ls
CROSS JOIN daily_orders do;

-- Verify orders created
SELECT 
    'Current Month Orders' as status,
    COUNT(*) as count,
    MIN(order_date) as first_date,
    MAX(order_date) as last_date,
    ROUND(SUM(total_amount), 2) as total_revenue
FROM ORDERS
WHERE order_date >= DATEADD(day, -30, CURRENT_DATE());

-- ===================================================================
-- Generate Order Items for Current Orders
-- ===================================================================

INSERT INTO ORDER_ITEMS (
    ORDER_ITEM_ID,
    ORDER_ID,
    ITEM_ID,
    ITEM_NAME,
    QUANTITY,
    UNIT_PRICE,
    UNIT_COST,
    LINE_TOTAL,
    MODIFICATIONS,
    IS_VOIDED
)
WITH menu_items_sample AS (
    SELECT 'ITEM049' as item_id, 'Chicken BB Biryani (Half)' as item_name, 14.99 as price, 5.50 as cost, 10 as weight
    UNION ALL SELECT 'ITEM050', 'Chicken BB Biryani (Full)', 42.99, 16.50, 5
    UNION ALL SELECT 'ITEM053', 'Vijayawada Spl Chicken Biryani (Half)', 15.99, 6.00, 8
    UNION ALL SELECT 'ITEM045', 'Hashtag Spl Veg Biryani (Half)', 14.99, 5.20, 6
    UNION ALL SELECT 'ITEM043', 'Paneer Biryani (Half)', 13.99, 4.80, 5
    UNION ALL SELECT 'ITEM006', 'Pani Puri (6 Pcs)', 6.99, 1.50, 7
    UNION ALL SELECT 'ITEM005', 'Vada Pav (1 Pcs)', 5.99, 1.20, 6
    UNION ALL SELECT 'ITEM009', 'Samosa Chaat (2 Pcs)', 6.99, 2.10, 5
    UNION ALL SELECT 'ITEM023', 'Masala Dosa', 9.99, 2.50, 8
    UNION ALL SELECT 'ITEM024', 'Hashtag Spl Dosa', 11.99, 3.20, 4
    UNION ALL SELECT 'ITEM017', 'Idly (3 Pcs)', 5.99, 1.20, 5
    UNION ALL SELECT 'ITEM079', 'Mango Lassi', 5.99, 1.80, 6
    UNION ALL SELECT 'ITEM084', 'Coke/Sprite/Diet Coke/Pepsi', 1.99, 0.60, 8
    UNION ALL SELECT 'ITEM032', 'Gulab Jamun', 5.99, 1.80, 3
),
current_orders AS (
    SELECT order_id
    FROM ORDERS
    WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
),
orders_with_items AS (
    SELECT 
        o.order_id,
        m.item_id,
        m.item_name,
        m.price,
        m.cost,
        ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY RANDOM()) as item_rank
    FROM current_orders o
    CROSS JOIN menu_items_sample m
    WHERE MOD(ABS(HASH(o.order_id, m.item_id)), 100) < (m.weight * 2)
)
SELECT 
    owi.order_id || '_ITEM' || owi.item_rank as ORDER_ITEM_ID,
    owi.order_id as ORDER_ID,
    owi.item_id as ITEM_ID,
    owi.item_name as ITEM_NAME,
    CASE WHEN MOD(ABS(RANDOM()), 10) < 8 THEN 1 ELSE 2 END as QUANTITY,
    owi.price as UNIT_PRICE,
    owi.cost as UNIT_COST,
    owi.price * CASE WHEN MOD(ABS(RANDOM()), 10) < 8 THEN 1 ELSE 2 END as LINE_TOTAL,
    NULL as MODIFICATIONS,
    FALSE as IS_VOIDED
FROM orders_with_items owi
WHERE owi.item_rank <= 3;  -- Max 3 items per order

-- Verify order items created
SELECT 
    'Current Month Items' as status,
    COUNT(*) as count,
    COUNT(DISTINCT order_id) as distinct_orders
FROM ORDER_ITEMS
WHERE order_id IN (
    SELECT order_id FROM ORDERS WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
);

-- ===================================================================
-- FINAL VERIFICATION
-- ===================================================================

SELECT '=== CURRENT MONTH DATA SUMMARY ===' as summary;

SELECT 
    COUNT(*) as total_orders,
    MIN(order_date) as first_order,
    MAX(order_date) as last_order,
    ROUND(SUM(total_amount), 2) as total_revenue,
    ROUND(AVG(total_amount), 2) as avg_order_value
FROM ORDERS
WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
    AND status = 'Completed';

-- Revenue by location (last 30 days)
SELECT 
    location_id,
    COUNT(*) as orders,
    ROUND(SUM(total_amount), 2) as revenue
FROM ORDERS
WHERE order_date >= DATEADD(day, -30, CURRENT_DATE())
    AND status = 'Completed'
GROUP BY location_id
ORDER BY revenue DESC;

SELECT '✅ CURRENT DATA GENERATION COMPLETE!' as status;
SELECT 'Your dashboard should now show data for the last 30 days!' as message;


LIST @RESTAURANT_ANALYTICS.RAW_DATA.APP_ASSETS;


CREATE USER AMAN;

RESTAURANT_ANALYTICS.ANALYTICS