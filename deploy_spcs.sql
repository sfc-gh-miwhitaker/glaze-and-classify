/*==============================================================================
DEPLOY SPCS VISION - Glaze & Classify (Step 3 of 3)
Author: SE Community | Expires: 2026-07-01
INSTRUCTIONS: Open in Snowsight → Click "Run All"

Prerequisite: Run deploy_all.sql (step 1) and push-image.sh (step 2) first.
This creates the SPCS vision service and classifies products with it.
==============================================================================*/

-- 1. Bootstrap (idempotent — safe if deploy_all.sql already ran)
USE ROLE SYSADMIN;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

ALTER GIT REPOSITORY SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO FETCH;

-- 2. SPCS Vision — infrastructure + populate
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/05_spcs/01_create_image_service.sql';
EXECUTE IMMEDIATE FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/sql/05_spcs/02_populate_vision.sql';

-- 3. Final summary — all four classifiers
SET DEMO_EXPIRES = '2026-07-01';

SELECT
    CASE
        WHEN simple_ct = 0 OR robust_ct = 0 OR vision_ct = 0
        THEN '⚠️  DEPLOYED WITH WARNINGS — some classification tables may be empty'
        ELSE '✅ Glaze & Classify fully deployed — all 4 classifiers active!'
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
