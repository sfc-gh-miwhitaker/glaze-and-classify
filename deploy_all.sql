/*==============================================================================
DEPLOY ALL - Glaze & Classify
Author: SE Community | Expires: 2026-07-01
INSTRUCTIONS: Open in Snowsight → Click "Run All"

Product classification showdown: traditional SQL vs Cortex AI vs SPCS vision.

SPCS Vision (optional):
  The vision service requires a container image. After the first Run All,
  copy the image repository URL from the SHOW IMAGE REPOSITORIES output,
  push the image with spcs/push-image.sh, then Run All again.
  See README.md for the full 3-step flow.
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

-- 6b. Surface image repo URL (copy this for push-image.sh)
SHOW IMAGE REPOSITORIES IN SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;

-- 6c. Data model & sample data
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/02_data/01_create_tables.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/02_data/02_load_sample_data.sql';

-- 6d. Classification approaches
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/01_traditional_sql.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/02_cortex_simple.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/03_cortex_robust.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/03_classification/04_comparison_view.sql';

-- 6e. Cortex Intelligence
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/04_cortex/01_create_semantic_view.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/04_cortex/02_create_agent.sql';

-- 6f. Streamlit Dashboard
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/06_streamlit/01_create_dashboard.sql';

-- 6g. SPCS Vision — infrastructure + populate (last — safe to skip on first run)
--     On first run this will fail if the image hasn't been pushed yet.
--     Push the image (step 2 in README), then Run All again.
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/05_spcs/01_create_image_service.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/05_spcs/02_populate_vision.sql';

-- 7. Final summary
SELECT
    CASE
        WHEN simple_ct = 0 OR robust_ct = 0 OR vision_ct = 0
        THEN '⚠️  DEPLOYED WITH WARNINGS — classification tables may be empty'
        ELSE '✅ Glaze & Classify deployed successfully!'
    END                            AS status,
    CURRENT_TIMESTAMP()            AS completed_at,
    products_loaded,
    trad_ct                        AS traditional_classified,
    simple_ct                      AS cortex_simple_classified,
    robust_ct                      AS cortex_robust_classified,
    vision_ct                      AS vision_classified,
    $DEMO_EXPIRES                  AS expires
FROM (
    SELECT
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.RAW_PRODUCTS)               AS products_loaded,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_TRADITIONAL)  AS trad_ct,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_CORTEX_SIMPLE) AS simple_ct,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_CORTEX_ROBUST) AS robust_ct,
        (SELECT COUNT(*) FROM SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.STG_CLASSIFIED_VISION)       AS vision_ct
);
