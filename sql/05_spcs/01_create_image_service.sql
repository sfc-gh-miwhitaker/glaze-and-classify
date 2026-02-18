/*==============================================================================
CLASSIFICATION APPROACH 4: SPCS Custom Vision Model
Snowpark Container Services running a bakery image classification model.
Exposed as a SQL-callable service function.

NOTE: This requires SPCS to be enabled in the account and the container image
to be built and pushed to the image repository. If SPCS is not available,
this step can be skipped — the comparison view will show NULL for vision results.

To build and push the image:
  cd spcs/
  docker build -t glaze-vision:latest .
  docker tag glaze-vision:latest <registry>/SNOWFLAKE_EXAMPLE/GLAZE_AND_CLASSIFY/GLAZE_IMAGE_REPO/glaze-vision:latest
  docker push <registry>/SNOWFLAKE_EXAMPLE/GLAZE_AND_CLASSIFY/GLAZE_IMAGE_REPO/glaze-vision:latest
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

-- Image repository for the container
CREATE IMAGE REPOSITORY IF NOT EXISTS GLAZE_IMAGE_REPO
  COMMENT = 'DEMO: Container images for Glaze & Classify vision service (Expires: 2026-03-20)';

-- Compute pool (account-level, uses SYSADMIN)
USE ROLE SYSADMIN;
CREATE COMPUTE POOL IF NOT EXISTS SFE_GLAZE_VISION_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 300
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Compute pool for bakery image classification (Expires: 2026-03-20)';

-- Service
CREATE SERVICE IF NOT EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE
  IN COMPUTE POOL SFE_GLAZE_VISION_POOL
  FROM SPECIFICATION $$
  spec:
    containers:
      - name: vision-classifier
        image: /SNOWFLAKE_EXAMPLE/GLAZE_AND_CLASSIFY/GLAZE_IMAGE_REPO/glaze-vision:latest
        resources:
          requests:
            cpu: "0.5"
            memory: 256M
          limits:
            cpu: "1"
            memory: 512M
    endpoints:
      - name: classify
        port: 8080
  $$
  MIN_INSTANCES = 1
  MAX_INSTANCES = 1
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Bakery image classification HTTP service (Expires: 2026-03-20)';

-- Service function: callable from SQL
CREATE OR REPLACE FUNCTION CLASSIFY_IMAGE(image_url VARCHAR)
  RETURNS VARCHAR
  SERVICE = SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE
  ENDPOINT = classify
  AS '/classify';

-- Populate vision classification results
TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_VISION;

INSERT INTO STG_CLASSIFIED_VISION (product_id, predicted_category, predicted_subcategory, confidence_score, raw_response)
WITH classified AS (
    SELECT
        p.product_id,
        CLASSIFY_IMAGE(p.image_url) AS raw_response
    FROM RAW_PRODUCTS p
    WHERE p.image_url IS NOT NULL
)
SELECT
    product_id,
    TRY_PARSE_JSON(raw_response):category::VARCHAR       AS predicted_category,
    TRY_PARSE_JSON(raw_response):subcategory::VARCHAR    AS predicted_subcategory,
    TRY_PARSE_JSON(raw_response):confidence::NUMBER(5,4) AS confidence_score,
    raw_response
FROM classified;
