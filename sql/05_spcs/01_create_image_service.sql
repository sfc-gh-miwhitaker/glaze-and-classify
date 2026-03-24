/*==============================================================================
CLASSIFICATION APPROACH 4: SPCS Custom Vision Model (Infrastructure)
Creates the compute pool, service, and SQL function.

The image repository is created during setup (01_setup/01_create_schema.sql).
The container image must be pushed before this script runs — see README.md.

The service takes ~30-90s to start after creation. Populate results with
02_populate_vision.sql which waits for the service to become READY.

Requires Enterprise edition with SPCS enabled and CREATE COMPUTE POOL privilege.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

USE ROLE ACCOUNTADMIN;
CREATE COMPUTE POOL IF NOT EXISTS SFE_GLAZE_VISION_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS
  AUTO_SUSPEND_SECS = 300
  AUTO_RESUME = TRUE
  COMMENT = 'DEMO: Compute pool for bakery image classification (Expires: 2026-07-01)';

GRANT USAGE, MONITOR ON COMPUTE POOL SFE_GLAZE_VISION_POOL TO ROLE SYSADMIN;

USE ROLE SYSADMIN;
DROP SERVICE IF EXISTS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE;

CREATE SERVICE SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE
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
  COMMENT = 'DEMO: Bakery image classification HTTP service (Expires: 2026-07-01)';

CREATE OR REPLACE FUNCTION CLASSIFY_IMAGE(image_url VARCHAR)
  RETURNS VARCHAR
  SERVICE = SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.GLAZE_VISION_SERVICE
  ENDPOINT = classify
  AS '/classify';
