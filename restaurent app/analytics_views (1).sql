-- ===================================================================
-- RESTAURANT ANALYTICS VIEWS
-- Run this after loading sample data
-- ===================================================================

USE DATABASE restaurant_analytics;
USE SCHEMA analytics;

-- ===================================================================
-- 1. DAILY REVENUE METRICS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.daily_revenue AS
SELECT 
    location_id,
    order_date as transaction_date,
    COUNT(DISTINCT order_id) as num_orders,
    SUM(total_amount) as daily_revenue,
    AVG(total_amount) as avg_order_value,
    SUM(tip_amount) as total_tips,
    SUM(discount_amount) as total_discounts
FROM raw_data.orders
WHERE status = 'Completed'
GROUP BY location_id, order_date;

-- ===================================================================
-- 2. FOOD COST ANALYSIS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.food_cost_summary AS
SELECT 
    s.location_id,
    DATE_TRUNC('month', s.order_date) as month,
    SUM(oi.line_total) as total_revenue,
    SUM(oi.quantity * oi.unit_cost) as total_cogs,
    ROUND((SUM(oi.quantity * oi.unit_cost) / NULLIF(SUM(oi.line_total), 0)) * 100, 2) as food_cost_percentage
FROM raw_data.orders s
JOIN raw_data.order_items oi ON s.order_id = oi.order_id
WHERE s.status = 'Completed'
GROUP BY s.location_id, month;

-- ===================================================================
-- 3. ITEM PERFORMANCE METRICS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.top_items AS
SELECT 
    oi.item_name,
    m.category_id,
    c.category_name,
    SUM(oi.quantity) as total_sold,
    SUM(oi.line_total) as total_revenue,
    SUM(oi.quantity * oi.unit_cost) as total_cost,
    SUM(oi.line_total) - SUM(oi.quantity * oi.unit_cost) as gross_profit,
    AVG(oi.unit_price) as avg_price,
    COUNT(DISTINCT o.order_id) as num_orders
FROM raw_data.order_items oi
JOIN raw_data.orders o ON oi.order_id = o.order_id
LEFT JOIN raw_data.menu_items m ON oi.item_id = m.item_id
LEFT JOIN raw_data.categories c ON m.category_id = c.category_id
WHERE o.status = 'Completed'
    AND o.order_date >= DATEADD(month, -1, CURRENT_DATE())
GROUP BY oi.item_name, m.category_id, c.category_name
ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW analytics.slow_moving_items AS
SELECT 
    oi.item_name,
    m.category_id,
    c.category_name,
    SUM(oi.quantity) as total_sold,
    SUM(oi.line_total) as total_revenue,
    COUNT(DISTINCT o.order_id) as num_orders,
    DATEDIFF(day, MIN(o.order_date), MAX(o.order_date)) as days_active
FROM raw_data.order_items oi
JOIN raw_data.orders o ON oi.order_id = o.order_id
LEFT JOIN raw_data.menu_items m ON oi.item_id = m.item_id
LEFT JOIN raw_data.categories c ON m.category_id = c.category_id
WHERE o.status = 'Completed'
    AND o.order_date >= DATEADD(month, -3, CURRENT_DATE())
GROUP BY oi.item_name, m.category_id, c.category_name
HAVING SUM(oi.quantity) < 10
ORDER BY total_sold ASC;

-- ===================================================================
-- 4. PEAK HOURS ANALYSIS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.peak_hours AS
SELECT 
    EXTRACT(HOUR FROM order_time) as hour_of_day,
    location_id,
    COUNT(*) as order_count,
    SUM(total_amount) as hourly_revenue,
    AVG(total_amount) as avg_order_value
FROM raw_data.orders
WHERE status = 'Completed'
    AND order_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY hour_of_day, location_id
ORDER BY hour_of_day;

CREATE OR REPLACE VIEW analytics.day_of_week_performance AS
SELECT 
    DAYOFWEEK(order_date) as day_of_week,
    CASE DAYOFWEEK(order_date)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END as day_name,
    location_id,
    COUNT(*) as order_count,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value
FROM raw_data.orders
WHERE status = 'Completed'
    AND order_date >= DATEADD(day, -90, CURRENT_DATE())
GROUP BY day_of_week, day_name, location_id
ORDER BY day_of_week;

-- ===================================================================
-- 5. LABOR COST ANALYSIS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.labor_analysis AS
SELECT 
    l.shift_date as date,
    l.location_id,
    SUM(l.labor_cost) as total_labor_cost,
    SUM(l.hours_worked) as total_hours_worked,
    COALESCE(r.daily_revenue, 0) as daily_revenue,
    CASE 
        WHEN r.daily_revenue > 0 
        THEN ROUND((SUM(l.labor_cost) / r.daily_revenue) * 100, 2)
        ELSE 0 
    END as labor_cost_percentage,
    COUNT(DISTINCT l.employee_id) as employees_scheduled
FROM raw_data.employee_schedules l
LEFT JOIN analytics.daily_revenue r 
    ON l.shift_date = r.transaction_date 
    AND l.location_id = r.location_id
GROUP BY l.shift_date, l.location_id, r.daily_revenue;

-- ===================================================================
-- 6. PRIME COST (Food Cost + Labor Cost)
-- ===================================================================

CREATE OR REPLACE VIEW analytics.prime_cost AS
SELECT 
    fc.location_id,
    fc.month,
    fc.total_revenue,
    fc.total_cogs as food_cost,
    fc.food_cost_percentage,
    SUM(es.labor_cost) as labor_cost,
    ROUND((SUM(es.labor_cost) / NULLIF(fc.total_revenue, 0)) * 100, 2) as labor_cost_percentage,
    fc.total_cogs + SUM(es.labor_cost) as prime_cost,
    ROUND(((fc.total_cogs + SUM(es.labor_cost)) / NULLIF(fc.total_revenue, 0)) * 100, 2) as prime_cost_percentage
FROM analytics.food_cost_summary fc
LEFT JOIN raw_data.employee_schedules es 
    ON fc.location_id = es.location_id 
    AND DATE_TRUNC('month', es.shift_date) = fc.month
GROUP BY fc.location_id, fc.month, fc.total_revenue, fc.total_cogs, fc.food_cost_percentage;

-- ===================================================================
-- 7. ORDER TYPE DISTRIBUTION
-- ===================================================================

CREATE OR REPLACE VIEW analytics.order_type_mix AS
SELECT 
    location_id,
    order_type,
    COUNT(*) as order_count,
    SUM(total_amount) as total_revenue,
    ROUND(AVG(total_amount), 2) as avg_order_value,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY location_id)), 2) as percentage_of_orders
FROM raw_data.orders
WHERE status = 'Completed'
    AND order_date >= DATEADD(month, -1, CURRENT_DATE())
GROUP BY location_id, order_type;

-- ===================================================================
-- 8. CUSTOMER BEHAVIOR METRICS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.customer_frequency AS
SELECT 
    customer_phone,
    location_id,
    COUNT(*) as visit_count,
    SUM(total_amount) as lifetime_value,
    AVG(total_amount) as avg_order_value,
    MIN(order_date) as first_visit,
    MAX(order_date) as last_visit,
    DATEDIFF(day, MIN(order_date), MAX(order_date)) as customer_lifespan_days
FROM raw_data.orders
WHERE status = 'Completed'
    AND customer_phone IS NOT NULL
GROUP BY customer_phone, location_id
HAVING COUNT(*) > 1
ORDER BY lifetime_value DESC;

-- ===================================================================
-- 9. LOCATION COMPARISON METRICS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.location_performance AS
SELECT 
    o.location_id,
    l.location_name,
    l.city,
    l.state,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(o.total_amount) / NULLIF(COUNT(DISTINCT DATE(o.order_date)), 0) as avg_daily_revenue,
    COUNT(DISTINCT o.customer_phone) as unique_customers,
    DATEDIFF(day, l.opened_date, CURRENT_DATE()) as days_open
FROM raw_data.orders o
JOIN raw_data.locations l ON o.location_id = l.location_id
WHERE o.status = 'Completed'
    AND o.order_date >= DATEADD(month, -1, CURRENT_DATE())
GROUP BY o.location_id, l.location_name, l.city, l.state, l.opened_date;

-- ===================================================================
-- 10. REVENUE TRENDS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.monthly_trends AS
SELECT 
    location_id,
    DATE_TRUNC('month', order_date) as month,
    COUNT(DISTINCT order_id) as total_orders,
    SUM(total_amount) as total_revenue,
    AVG(total_amount) as avg_order_value,
    SUM(total_amount) / COUNT(DISTINCT DATE(order_date)) as avg_daily_revenue
FROM raw_data.orders
WHERE status = 'Completed'
GROUP BY location_id, month
ORDER BY location_id, month;

CREATE OR REPLACE VIEW analytics.same_store_sales_growth AS
SELECT 
    cur.location_id,
    cur.month,
    cur.total_revenue as current_revenue,
    previous.total_revenue as previous_month_revenue,
    ROUND(((cur.total_revenue - previous.total_revenue) / NULLIF(previous.total_revenue, 0)) * 100, 2) as mom_growth_percentage,
    cur.total_orders as current_orders,
    previous.total_orders as previous_orders
FROM analytics.monthly_trends cur
LEFT JOIN analytics.monthly_trends previous 
    ON cur.location_id = previous.location_id 
    AND cur.month = DATEADD(month, 1, previous.month)
ORDER BY cur.location_id, cur.month DESC;

-- ===================================================================
-- 11. CATEGORY PERFORMANCE
-- ===================================================================

CREATE OR REPLACE VIEW analytics.category_performance AS
SELECT 
    c.category_name,
    c.category_id,
    COUNT(DISTINCT oi.order_id) as orders_with_category,
    SUM(oi.quantity) as total_items_sold,
    SUM(oi.line_total) as total_revenue,
    SUM(oi.quantity * oi.unit_cost) as total_cost,
    SUM(oi.line_total) - SUM(oi.quantity * oi.unit_cost) as gross_profit,
    ROUND(((SUM(oi.line_total) - SUM(oi.quantity * oi.unit_cost)) / NULLIF(SUM(oi.line_total), 0)) * 100, 2) as profit_margin_percentage
FROM raw_data.order_items oi
JOIN raw_data.menu_items m ON oi.item_id = m.item_id
JOIN raw_data.categories c ON m.category_id = c.category_id
JOIN raw_data.orders o ON oi.order_id = o.order_id
WHERE o.status = 'Completed'
    AND o.order_date >= DATEADD(month, -1, CURRENT_DATE())
GROUP BY c.category_name, c.category_id
ORDER BY total_revenue DESC;

-- ===================================================================
-- 12. PAYMENT METHOD ANALYSIS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.payment_methods AS
SELECT 
    o.payment_type_id,
    pt.payment_type_name,
    COUNT(*) as transaction_count,
    SUM(o.total_amount) as total_amount,
    AVG(o.total_amount) as avg_transaction_value,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) as percentage_of_transactions
FROM raw_data.orders o
JOIN raw_data.payment_types pt ON o.payment_type_id = pt.payment_type_id
WHERE o.status = 'Completed'
    AND o.order_date >= DATEADD(month, -1, CURRENT_DATE())
GROUP BY o.payment_type_id, pt.payment_type_name;

-- ===================================================================
-- 13. REVIEW SENTIMENT ANALYSIS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.review_summary AS
SELECT 
    r.location_id,
    l.location_name,
    COUNT(*) as total_reviews,
    AVG(r.rating) as avg_rating,
    SUM(CASE WHEN r.sentiment = 'Positive' THEN 1 ELSE 0 END) as positive_reviews,
    SUM(CASE WHEN r.sentiment = 'Negative' THEN 1 ELSE 0 END) as negative_reviews,
    SUM(CASE WHEN r.sentiment = 'Neutral' THEN 1 ELSE 0 END) as neutral_reviews,
    ROUND((SUM(CASE WHEN r.sentiment = 'Positive' THEN 1 ELSE 0 END) * 100.0 / COUNT(*)), 2) as positive_percentage
FROM raw_data.customer_reviews r
JOIN raw_data.locations l ON r.location_id = l.location_id
WHERE r.review_date >= DATEADD(month, -3, CURRENT_DATE())
GROUP BY r.location_id, l.location_name;

-- ===================================================================
-- 14. TABLE TURNOVER (for Dine-in)
-- ===================================================================

CREATE OR REPLACE VIEW analytics.table_turnover AS
SELECT 
    location_id,
    table_number,
    DATE(order_date) as date,
    COUNT(*) as times_used,
    AVG(total_amount) as avg_revenue_per_use
FROM raw_data.orders
WHERE order_type = 'Dine-in'
    AND table_number IS NOT NULL
    AND status = 'Completed'
    AND order_date >= DATEADD(day, -30, CURRENT_DATE())
GROUP BY location_id, table_number, DATE(order_date);

-- ===================================================================
-- 15. WASTE & CANCELLATION ANALYSIS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.cancelled_orders AS
SELECT 
    location_id,
    DATE_TRUNC('month', order_date) as month,
    COUNT(*) as cancelled_count,
    SUM(total_amount) as potential_revenue_lost,
    ROUND((COUNT(*) * 100.0 / 
        (SELECT COUNT(*) FROM raw_data.orders o2 
         WHERE o2.location_id = orders.location_id 
         AND DATE_TRUNC('month', o2.order_date) = DATE_TRUNC('month', orders.order_date))), 2) as cancellation_rate
FROM raw_data.orders
WHERE status IN ('Cancelled', 'Refunded')
GROUP BY location_id, month;

-- ===================================================================
-- 16. INVENTORY COST TRENDS
-- ===================================================================

CREATE OR REPLACE VIEW analytics.inventory_costs AS
SELECT 
    it.location_id,
    DATE_TRUNC('month', it.transaction_date) as month,
    ii.category as inventory_category,
    SUM(it.total_cost) as total_cost,
    SUM(it.quantity) as total_quantity,
    AVG(it.unit_cost) as avg_unit_cost
FROM raw_data.inventory_transactions it
JOIN raw_data.inventory_items ii ON it.inventory_item_id = ii.inventory_item_id
WHERE it.transaction_type = 'Purchase'
GROUP BY it.location_id, month, ii.category;

-- ===================================================================
-- 17. EXECUTIVE DASHBOARD VIEW
-- ===================================================================

CREATE OR REPLACE VIEW analytics.executive_dashboard AS
SELECT 
    l.location_id,
    l.location_name,
    l.city,
    
    -- Revenue Metrics
    COALESCE(SUM(o.total_amount), 0) as mtd_revenue,
    COALESCE(COUNT(DISTINCT o.order_id), 0) as mtd_orders,
    COALESCE(AVG(o.total_amount), 0) as avg_order_value,
    
    -- Cost Metrics
    COALESCE(fc.food_cost_percentage, 0) as food_cost_pct,
    COALESCE(lc.labor_cost_percentage, 0) as labor_cost_pct,
    COALESCE(pc.prime_cost_percentage, 0) as prime_cost_pct,
    
    -- Customer Metrics
    COUNT(DISTINCT o.customer_phone) as unique_customers,
    COALESCE(rs.avg_rating, 0) as avg_rating,
    COALESCE(rs.positive_percentage, 0) as positive_review_pct,
    
    -- Operational Metrics
    DATEDIFF(day, l.opened_date, CURRENT_DATE()) as days_open
    
FROM raw_data.locations l
LEFT JOIN raw_data.orders o 
    ON l.location_id = o.location_id 
    AND o.status = 'Completed'
    AND o.order_date >= DATE_TRUNC('month', CURRENT_DATE())
LEFT JOIN analytics.food_cost_summary fc 
    ON l.location_id = fc.location_id 
    AND fc.month = DATE_TRUNC('month', CURRENT_DATE())
LEFT JOIN (
    SELECT location_id, AVG(labor_cost_percentage) as labor_cost_percentage
    FROM analytics.labor_analysis
    WHERE date >= DATE_TRUNC('month', CURRENT_DATE())
    GROUP BY location_id
) lc ON l.location_id = lc.location_id
LEFT JOIN analytics.prime_cost pc 
    ON l.location_id = pc.location_id 
    AND pc.month = DATE_TRUNC('month', CURRENT_DATE())
LEFT JOIN analytics.review_summary rs ON l.location_id = rs.location_id
WHERE l.is_active = TRUE
GROUP BY 
    l.location_id, l.location_name, l.city, l.opened_date,
    fc.food_cost_percentage, lc.labor_cost_percentage, 
    pc.prime_cost_percentage, rs.avg_rating, rs.positive_percentage;

-- ===================================================================
-- VERIFICATION QUERIES
-- ===================================================================

-- Check that views are created
SHOW VIEWS IN SCHEMA analytics;
