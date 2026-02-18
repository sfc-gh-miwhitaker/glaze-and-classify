/*==============================================================================
CLASSIFICATION APPROACH 3: Cortex AI_COMPLETE — Robust Pipeline
Multi-step pipeline with:
  - Structured output via type literals (GA)
  - Hierarchical classification (Category > Subcategory > Attributes)
  - Confidence scoring
  - Multi-language handling built in
  - Batch processing with error handling
Production-ready pattern.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

TRUNCATE TABLE IF EXISTS STG_CLASSIFIED_CORTEX_ROBUST;

-- Build the valid taxonomy as context for the prompt
CREATE OR REPLACE TEMPORARY TABLE TEMP_TAXONOMY_CONTEXT AS
SELECT LISTAGG(
    CONCAT('- ', category, ' > ', subcategory),
    '\n'
) WITHIN GROUP (ORDER BY sort_order) AS taxonomy_text
FROM RAW_CATEGORY_TAXONOMY;

-- Classify with structured output, confidence, and language detection
INSERT INTO STG_CLASSIFIED_CORTEX_ROBUST
    (product_id, detected_language, predicted_category, predicted_subcategory,
     confidence_score, attributes, raw_response, model_used)
SELECT
    p.product_id,
    result:detected_language::VARCHAR           AS detected_language,
    result:category::VARCHAR                    AS predicted_category,
    result:subcategory::VARCHAR                 AS predicted_subcategory,
    result:confidence::NUMBER(5,4)              AS confidence_score,
    result:attributes                           AS attributes,
    raw_json                                    AS raw_response,
    'llama3.1-70b'                              AS model_used
FROM RAW_PRODUCTS p
CROSS JOIN TEMP_TAXONOMY_CONTEXT tx,
    LATERAL (
        SELECT AI_COMPLETE(
            model => 'llama3.1-70b',
            prompt => CONCAT(
                'You are an expert product classifier for an international bakery/donut company operating in 6 markets. ',
                'You must classify products accurately regardless of the language they are written in.\n\n',

                '## Valid Taxonomy (you MUST pick from this list):\n',
                tx.taxonomy_text, '\n\n',

                '## Instructions:\n',
                '1. Detect the language of the product name and description.\n',
                '2. Classify the product into the BEST matching category and subcategory from the taxonomy above.\n',
                '3. Assign a confidence score from 0.0 to 1.0.\n',
                '4. Extract key attributes (flavor, topping, filling, coating) if identifiable.\n',
                '5. If the product name is just a filename (e.g., IMG_xxx.jpg) with no description, ',
                   'classify as best you can from the filename and set confidence low.\n\n',

                '## Product to Classify:\n',
                'Name: ', p.product_name, '\n',
                COALESCE(CONCAT('Description: ', p.product_description, '\n'), ''),
                'Market: ', p.market_code, '\n',
                'Language: ', p.language_code, '\n',
                COALESCE(CONCAT('Raw category: ', p.raw_category_string, '\n'), '')
            ),
            response_format => TYPE OBJECT(
                detected_language   VARCHAR,
                category            VARCHAR,
                subcategory         VARCHAR,
                confidence          NUMBER(5,4),
                attributes          OBJECT(
                    flavor      VARCHAR,
                    topping     VARCHAR,
                    filling     VARCHAR,
                    coating     VARCHAR
                )
            )
        ) AS raw_json
    ) llm,
    LATERAL (
        SELECT TRY_PARSE_JSON(llm.raw_json) AS result
    ) parsed;

DROP TABLE IF EXISTS TEMP_TAXONOMY_CONTEXT;
