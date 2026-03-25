/*==============================================================================
DEPLOY ALL - Glaze & Classify (Step 1 of 3)
Author: SE Community | Expires: 2026-07-01
INSTRUCTIONS: Open in Snowsight → Click "Run All"

Deploys schema, data, three classification approaches (Traditional SQL,
Cortex Simple, Cortex Robust), Streamlit dashboard, and Intelligence agent.

After this completes, the LAST RESULT shows your image repository URL.
Copy it, then follow steps 2-3 in README.md to activate SPCS vision.
==============================================================================*/

-- 1. SSOT: Expiration date — change ONLY here
SET DEMO_EXPIRES = '2026-07-01';

-- 2. Expiration check (informational — warns but does not block)
SELECT
    $DEMO_EXPIRES::DATE                                          AS expiration_date,
    CURRENT_DATE()                                               AS current_date,
    DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE)         AS days_remaining,
    CASE
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) < 0
        THEN 'EXPIRED - Code may use outdated syntax. Validate against docs before use.'
        WHEN DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) <= 7
        THEN 'EXPIRING SOON - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
        ELSE 'ACTIVE - ' || DATEDIFF('day', CURRENT_DATE(), $DEMO_EXPIRES::DATE) || ' days remaining'
    END AS demo_status;

-- 3. API integration (ACCOUNTADMIN required for CREATE API INTEGRATION)
USE ROLE ACCOUNTADMIN;
CREATE API INTEGRATION IF NOT EXISTS SFE_GIT_API_INTEGRATION
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-miwhitaker/glaze-and-classify')
  ENABLED = TRUE
  COMMENT = 'Git integration for glaze-and-classify | Author: SE Community';

-- 4. Bootstrap warehouse (required before EXECUTE IMMEDIATE FROM)
USE ROLE SYSADMIN;
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_EXAMPLE;
CREATE WAREHOUSE IF NOT EXISTS SFE_GLAZE_AND_CLASSIFY_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Glaze & Classify compute (Expires: 2026-07-01)';
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

-- 5. Fetch latest from Git
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS
  COMMENT = 'Shared schema for Git repository stages across demo projects';

CREATE GIT REPOSITORY IF NOT EXISTS SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO
  API_INTEGRATION = SFE_GIT_API_INTEGRATION
  ORIGIN = 'https://github.com/sfc-gh-miwhitaker/glaze-and-classify.git'
  COMMENT = 'DEMO: Glaze & Classify Git repo (Expires: 2026-07-01)';

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO FETCH;

-- 6. Execute scripts in order
-- 6a. Setup (creates schema, warehouse, image repository)
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/01_setup/01_create_schema.sql';

-- 6b. Data model & sample data
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/02_data/02_load_sample_data.sql';

-- 6c. Classification approaches
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/01_traditional_sql.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/02_cortex_simple.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/03_cortex_robust.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/04_comparison_view.sql';

-- 6d. Cortex Intelligence
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/04_cortex/02_create_agent.sql';

-- 6e. Streamlit Dashboard
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/06_streamlit/01_create_dashboard.sql';

-- 6f. Notebook Explorer
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/07_notebook/01_create_notebook.sql';

-- 7. LAST RESULT — copy the URL for push-image.sh (step 2)
SHOW IMAGE REPOSITORIES IN SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
SET image_repo_qid = LAST_QUERY_ID();

SELECT
    '✅ Step 1 complete — copy the URL below for push-image.sh (step 2)' AS status,
    $5 AS image_repo_url
FROM TABLE(RESULT_SCAN($image_repo_qid))
WHERE $2 = 'GLAZE_IMAGE_REPO';
