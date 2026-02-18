/*==============================================================================
SEMANTIC VIEW - Glaze & Classify
Provides the Intelligence agent with a structured understanding of the
classification comparison data and product catalog.
==============================================================================*/

USE SCHEMA SNOWFLAKE_EXAMPLE.SEMANTIC_MODELS;
USE WAREHOUSE SFE_GLAZE_AND_CLASSIFY_WH;

CREATE OR REPLACE SEMANTIC VIEW SV_GLAZE_PRODUCTS

  TABLES (
    products AS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.RAW_PRODUCTS
      PRIMARY KEY (product_id)
      WITH SYNONYMS = ('items', 'catalog', 'donuts', 'doughnuts', 'bakery items')
      COMMENT = 'International bakery product catalog with names in 5+ languages across 6 markets',

    comparison AS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.CLASSIFICATION_COMPARISON
      PRIMARY KEY (product_id)
      WITH SYNONYMS = ('results', 'classification results', 'accuracy', 'predictions')
      COMMENT = 'Side-by-side classification results from all four approaches with accuracy flags',

    accuracy AS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.ACCURACY_SUMMARY
      WITH SYNONYMS = ('accuracy summary', 'performance', 'scores')
      COMMENT = 'Aggregated accuracy metrics by approach and market',

    taxonomy AS SNOWFLAKE_EXAMPLE.GLAZE_AND_CLASSIFY.RAW_CATEGORY_TAXONOMY
      PRIMARY KEY (category_id)
      WITH SYNONYMS = ('categories', 'hierarchy', 'classification scheme')
      COMMENT = 'Gold-standard category hierarchy for the bakery product line'
  )

  RELATIONSHIPS (
    comparison.product_id REFERENCES products.product_id
  )

  DIMENSIONS (
    products.product_name AS product_name
      WITH SYNONYMS = ('name', 'item name', 'donut name')
      COMMENT = 'Product name in native market language — may be English, Japanese, French, Spanish, or Portuguese',

    products.market_code AS market
      WITH SYNONYMS = ('country', 'region', 'market')
      COMMENT = 'Two-letter market code: US, JP, FR, MX, UK, BR',

    products.language_code AS language
      WITH SYNONYMS = ('lang', 'locale')
      COMMENT = 'Language of the product name: en, ja, fr, es, pt',

    products.gold_category AS true_category
      WITH SYNONYMS = ('actual category', 'correct category', 'gold standard')
      COMMENT = 'The verified correct category for accuracy measurement',

    products.gold_subcategory AS true_subcategory
      WITH SYNONYMS = ('actual subcategory', 'correct subcategory')
      COMMENT = 'The verified correct subcategory for accuracy measurement',

    products.is_seasonal AS seasonal
      WITH SYNONYMS = ('limited edition', 'seasonal item')
      COMMENT = 'Whether the product is a seasonal/limited-time offering',

    comparison.trad_category AS traditional_prediction
      WITH SYNONYMS = ('sql prediction', 'traditional result', 'regex result')
      COMMENT = 'Category predicted by the traditional SQL CASE/LIKE/regex approach',

    comparison.simple_category AS simple_ai_prediction
      WITH SYNONYMS = ('simple cortex', 'basic ai prediction')
      COMMENT = 'Category predicted by the single AI_COMPLETE call approach',

    comparison.robust_category AS robust_ai_prediction
      WITH SYNONYMS = ('robust cortex', 'advanced ai prediction', 'pipeline prediction')
      COMMENT = 'Category predicted by the multi-step robust Cortex pipeline',

    comparison.vision_category AS vision_prediction
      WITH SYNONYMS = ('image prediction', 'spcs prediction', 'vision model')
      COMMENT = 'Category predicted by the SPCS custom vision model',

    comparison.is_image_only AS image_only
      WITH SYNONYMS = ('no description', 'image only product')
      COMMENT = 'Whether the product has only an image and no text description — hardest case',

    taxonomy.category AS category_name
      WITH SYNONYMS = ('category')
      COMMENT = 'Top-level product category in the taxonomy',

    taxonomy.subcategory AS subcategory_name
      WITH SYNONYMS = ('subcategory')
      COMMENT = 'Second-level product subcategory in the taxonomy'
  )

  FACTS (
    comparison.trad_category_correct AS trad_correct
      COMMENT = '1 if traditional SQL correctly predicted the category, 0 otherwise',

    comparison.simple_category_correct AS simple_correct
      COMMENT = '1 if simple Cortex correctly predicted the category, 0 otherwise',

    comparison.robust_category_correct AS robust_correct
      COMMENT = '1 if robust Cortex correctly predicted the category, 0 otherwise',

    comparison.robust_confidence AS robust_confidence
      COMMENT = 'Confidence score from the robust Cortex pipeline (0.0 to 1.0)',

    comparison.vision_category_correct AS vision_correct
      COMMENT = '1 if SPCS vision model correctly predicted the category, 0 otherwise'
  )

  METRICS (
    products.total_products AS COUNT(products.product_id)
      COMMENT = 'Total number of products in the catalog',

    comparison.traditional_accuracy AS AVG(comparison.trad_category_correct) * 100
      COMMENT = 'Accuracy percentage of the traditional SQL classification approach',

    comparison.simple_ai_accuracy AS AVG(comparison.simple_category_correct) * 100
      COMMENT = 'Accuracy percentage of the simple Cortex AI_COMPLETE approach',

    comparison.robust_ai_accuracy AS AVG(comparison.robust_category_correct) * 100
      COMMENT = 'Accuracy percentage of the robust multi-step Cortex pipeline',

    comparison.vision_accuracy AS AVG(comparison.vision_category_correct) * 100
      COMMENT = 'Accuracy percentage of the SPCS custom vision model',

    comparison.avg_confidence AS AVG(comparison.robust_confidence)
      COMMENT = 'Average confidence score from the robust Cortex pipeline'
  )

  COMMENT = 'DEMO: Semantic view for bakery product classification comparison across 4 approaches (Expires: 2026-03-20)'

  AI_SQL_GENERATION
    'This semantic view covers an international bakery product catalog classified by four different approaches:
     traditional SQL (CASE/LIKE/regex), simple Cortex AI_COMPLETE, robust multi-step Cortex pipeline, and
     SPCS custom vision model. Products span 6 markets (US, JP, FR, MX, UK, BR) in 5 languages.
     The gold_category and gold_subcategory fields contain the verified correct answers.
     Accuracy is measured by comparing each approach''s prediction to the gold standard.
     When asked about accuracy, compute AVG of the _correct fields and multiply by 100 for percentages.
     The robust pipeline also has confidence scores between 0 and 1.';
