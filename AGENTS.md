# Glaze & Classify

Product classification showdown: four progressively sophisticated approaches to classifying an international bakery catalog.

## Project Structure
- `deploy_all.sql` -- Step 1: Deploy core (Run All in Snowsight)
- `deploy_spcs.sql` -- Step 3: Deploy SPCS vision (Run All in Snowsight)
- `teardown_all.sql` -- Complete cleanup
- `sql/` -- Individual SQL scripts (numbered)
- `streamlit/` -- Streamlit dashboard source
- `spcs/` -- Snowpark Container Services vision model (step 2: push-image.sh)
- `diagrams/` -- Architecture diagrams (Mermaid)

## Snowflake Environment
- Database: SNOWFLAKE_EXAMPLE
- Schema: GLAZE_AND_CLASSIFY
- Warehouse: SFE_GLAZE_AND_CLASSIFY_WH

## Key Patterns
- Four classification approaches: SQL keyword, simple Cortex (AI_TRANSLATE + AI_COMPLETE), robust Cortex pipeline, SPCS vision
- AI_TRANSLATE for multilingual product name translation
- AI_COMPLETE with llama3.3-70b for classification
- Snowpark Container Services for custom vision model
- Semantic view + Intelligence agent for analytics
- Multi-language product catalog (6 markets, 5+ languages)

## Development Standards
- SQL: Explicit columns, sargable predicates, QUALIFY for window functions
- Objects: COMMENT with expiration date on all objects
- Deploy: 3-step deployment — deploy_all.sql, push-image.sh, deploy_spcs.sql
- Naming: SFE_ prefix for account-level objects only; project objects scoped by schema

## When Helping with This Project
- Follow SFE naming conventions (SFE_ prefix for account-level objects)
- Use QUALIFY instead of subqueries for window function filtering
- Keep deploy_all.sql + deploy_spcs.sql as the two SQL entry points
- All new objects need COMMENT = 'DEMO: ... (Expires: 2026-07-01)'
- SPCS components require Enterprise edition with CREATE COMPUTE POOL privilege
- Classification accuracy comparison is the narrative arc
