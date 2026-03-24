/*==============================================================================
NOTEBOOK - Glaze & Classify Explorer
Interactive notebook for live product classification and agent Q&A.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

CREATE OR REPLACE NOTEBOOK GLAZE_CLASSIFY_EXPLORER
  FROM '@SNOWFLAKE_EXAMPLE.GIT_REPOS.SFE_GLAZE_AND_CLASSIFY_REPO/branches/main/notebook'
  MAIN_FILE = 'glaze_classify_explorer.ipynb'
  QUERY_WAREHOUSE = SFE_GLAZE_AND_CLASSIFY_WH
  COMMENT = 'DEMO: Interactive Cortex AI explorer (Expires: 2026-07-01)';

ALTER NOTEBOOK GLAZE_CLASSIFY_EXPLORER ADD LIVE VERSION FROM LAST;
