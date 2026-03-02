USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE API INTEGRATION GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/Snowflake-Labs/sfguide-getting-started-with-cortex-agents.git')
  -- If you only want public read access, you can skip secrets:
  ENABLED = TRUE;

describe API INTEGRATION GIT_API_INTEGRATION


-- ===================================================================
-- USER AND ROLE SETUP FOR HASHTAG INDIA ANALYTICS
-- Creates user AMAN with ANALYST role and proper permissions
-- ===================================================================

-- Switch to ACCOUNTADMIN to create users and roles
USE ROLE ACCOUNTADMIN;

-- ===================================================================
-- STEP 1: CREATE ROLE
-- ===================================================================

-- Create ANALYST role
CREATE ROLE IF NOT EXISTS ANALYST
    COMMENT = 'Analyst role for viewing restaurant analytics dashboards';

-- Verify role created
SHOW ROLES LIKE 'ANALYST';

-- ===================================================================
-- STEP 2: CREATE USER
-- ===================================================================

-- Create user AMAN with password
CREATE USER IF NOT EXISTS AMAN
    PASSWORD = 'AMAN'
    DEFAULT_ROLE = ANALYST
    DEFAULT_WAREHOUSE = COMPUTE_WH
    DEFAULT_NAMESPACE = RESTAURANT_ANALYTICS.ANALYTICS
    COMMENT = 'Analyst user for restaurant analytics'
    MUST_CHANGE_PASSWORD = FALSE;  -- Set to TRUE if you want password change on first login

-- Verify user created
SHOW USERS LIKE 'AMAN';

-- ===================================================================
-- STEP 3: ASSIGN ROLE TO USER
-- ===================================================================

-- Grant ANALYST role to user AMAN
GRANT ROLE ANALYST TO USER AMAN;

-- Verify role assignment
SHOW GRANTS TO USER AMAN;

-- ===================================================================
-- STEP 4: GRANT DATABASE AND SCHEMA ACCESS
-- ===================================================================

-- Grant usage on database
GRANT USAGE ON DATABASE RESTAURANT_ANALYTICS TO ROLE ANALYST;

-- Grant usage on RAW_DATA schema (to access base tables if needed)
GRANT USAGE ON SCHEMA RESTAURANT_ANALYTICS.RAW_DATA TO ROLE ANALYST;

-- Grant usage on ANALYTICS schema (where all the views are)
GRANT USAGE ON SCHEMA RESTAURANT_ANALYTICS.ANALYTICS TO ROLE ANALYST;

-- ===================================================================
-- STEP 5: GRANT ACCESS TO ALL VIEWS IN ANALYTICS SCHEMA
-- ===================================================================

-- Grant SELECT on all existing views in ANALYTICS schema
GRANT SELECT ON ALL VIEWS IN SCHEMA RESTAURANT_ANALYTICS.ANALYTICS TO ROLE ANALYST;

-- Grant SELECT on all future views (auto-grant for new views)
GRANT SELECT ON FUTURE VIEWS IN SCHEMA RESTAURANT_ANALYTICS.ANALYTICS TO ROLE ANALYST;

-- ===================================================================
-- STEP 6: GRANT ACCESS TO BASE TABLES (Optional but Recommended)
-- ===================================================================

-- Grant SELECT on base tables in RAW_DATA schema (read-only)
GRANT SELECT ON ALL TABLES IN SCHEMA RESTAURANT_ANALYTICS.RAW_DATA TO ROLE ANALYST;

-- Grant SELECT on future tables
GRANT SELECT ON FUTURE TABLES IN SCHEMA RESTAURANT_ANALYTICS.RAW_DATA TO ROLE ANALYST;

-- ===================================================================
-- STEP 7: GRANT WAREHOUSE ACCESS
-- ===================================================================

-- Grant usage on warehouse (needed to run queries)
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE ANALYST;

-- Grant operate privilege (allows starting/stopping warehouse)
GRANT OPERATE ON WAREHOUSE COMPUTE_WH TO ROLE ANALYST;

-- ===================================================================
-- STEP 8: GRANT STREAMLIT APP ACCESS
-- ===================================================================

-- Grant usage on Streamlit apps (if you have them)
-- Note: Replace 'HASHTAG_ANALYTICS' with your actual Streamlit app name
-- GRANT USAGE ON STREAMLIT RESTAURANT_ANALYTICS.RAW_DATA.HASHTAG_ANALYTICS TO ROLE ANALYST;

-- ===================================================================
-- VERIFICATION QUERIES
-- ===================================================================

-- Check what the ANALYST role can access
SHOW GRANTS TO ROLE ANALYST;

-- Check what user AMAN has been granted
SHOW GRANTS TO USER AMAN;

SHOW STREAMLIT APPS;


GRANT USAGE ON STREAMLIT RESTAURANT_ANALYTICS.RAW_DATA.<YOUR_APP_NAME> TO ROLE ANALYST;

-- Test connection as AMAN (run these separately after logging in as AMAN)
-- USE ROLE ANALYST;
-- USE DATABASE RESTAURANT_ANALYTICS;
-- USE SCHEMA ANALYTICS;
-- SELECT * FROM DAILY_REVENUE LIMIT 5;

-- ===================================================================
-- SUMMARY
-- ===================================================================

SELECT '✅ USER SETUP COMPLETE!' as status;

SELECT 
    'User: AMAN' as info,
    'Password: AMAN' as credentials,
    'Role: ANALYST' as role,
    'Access: Read-only to all analytics views' as permissions
UNION ALL
SELECT 
    'Database: RESTAURANT_ANALYTICS',
    'Schema: ANALYTICS',
    'Warehouse: COMPUTE_WH',
    'Can view: All dashboards and reports';

-- ===================================================================
-- LOGIN INSTRUCTIONS FOR AMAN
-- ===================================================================

/*
TO LOGIN AS AMAN:
1. Go to Snowflake login page
2. Username: AMAN
3. Password: AMAN
4. Role: ANALYST (should auto-select)
5. Warehouse: COMPUTE_WH

AMAN CAN NOW:
- View all analytics dashboards
- Run queries on analytics views
- Access Streamlit apps
- See all reports

AMAN CANNOT:
- Modify data (read-only)
- Create/drop tables
- Change warehouse settings
- Create new users
- Delete records
*/

-- ===================================================================
-- OPTIONAL: CREATE ADDITIONAL USERS
-- ===================================================================

/*
-- To create more analysts, copy this template:

CREATE USER IF NOT EXISTS <USERNAME>
    PASSWORD = '<PASSWORD>'
    DEFAULT_ROLE = ANALYST
    DEFAULT_WAREHOUSE = COMPUTE_WH
    DEFAULT_NAMESPACE = RESTAURANT_ANALYTICS.ANALYTICS
    MUST_CHANGE_PASSWORD = TRUE;

GRANT ROLE ANALYST TO USER <USERNAME>;

-- Examples:
-- CREATE USER MANAGER1 PASSWORD = 'TempPass123' ...
-- CREATE USER OWNER PASSWORD = 'SecurePass456' ...
*/

-- ===================================================================
-- CLEANUP (USE ONLY IF YOU NEED TO REMOVE USER/ROLE)
-- ===================================================================

/*
-- To remove everything (DON'T RUN unless you want to delete):

-- DROP USER AMAN;
-- REVOKE ROLE ANALYST FROM USER AMAN;
-- DROP ROLE ANALYST;
*/

-- Run as ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Find your app
SHOW STREAMLIT APPS;

-- Grant (update app name!)
GRANT USAGE ON STREAMLIT RESTAURANT_ANALYTICS.RAW_DATA.HASHTAG_ANALYTICS TO ROLE ANALYST;

-- Auto-grant future apps
GRANT USAGE ON FUTURE STREAMLIT APPS IN SCHEMA RESTAURANT_ANALYTICS.RAW_DATA TO ROLE ANALYST;

-- Verify
SHOW GRANTS TO ROLE ANALYST;