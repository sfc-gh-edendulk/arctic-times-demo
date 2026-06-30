-- ============================================================================
-- Arctic Times — Cortex Agent Setup (Semantic View + Agent)
-- ============================================================================
-- Creates the Semantic View and Cortex Agent for the editorial assistant.
-- Run AFTER the Dynamic Tables (scripts/deploy/05_dynamic_tables.sql) exist.
--   snow sql -f scripts/setup_cortex_agent.sql --connection lemondetrial
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARCTIC_TIMES;
USE SCHEMA AI;
USE WAREHOUSE COMPUTE_WH;

-- ---------------------------------------------------------------------------
-- Semantic View: CONTENT_SV
-- Editorial analytics over article performance + reader engagement.
-- Built on the CURATED dynamic tables.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW ARCTIC_TIMES.AI.CONTENT_SV

  TABLES (
    ARTICLES AS ARCTIC_TIMES.CURATED.ARTICLE_PERFORMANCE
      PRIMARY KEY (ARTICLE_ID)
      COMMENT = 'Articles publies avec metriques de performance lecteurs',
    ENGAGEMENT AS ARCTIC_TIMES.CURATED.READER_ENGAGEMENT
      PRIMARY KEY (DAY, SECTION, PUBLICATION)
      COMMENT = 'Engagement quotidien par section et publication'
  )

  DIMENSIONS (
    ARTICLES.SECTION AS section
      WITH SYNONYMS = ('rubrique', 'categorie')
      COMMENT = 'Section editoriale (Politique, International, Economie, Culture, Sciences, Sport, Planete, Opinions, Societe)',
    ARTICLES.PUBLICATION AS publication
      WITH SYNONYMS = ('journal', 'titre')
      COMMENT = 'Publication du groupe (Arctic Times, Courrier Polaire, Telerama Nord, La Vie Glaciale, Arctic Times Diplomatique)',
    ARTICLES.AUTHOR AS author
      WITH SYNONYMS = ('journaliste', 'auteur')
      COMMENT = 'Auteur de l article',
    ARTICLES.TITLE AS title
      COMMENT = 'Titre de l article',
    ARTICLES.PERFORMANCE_TIER AS performance_tier
      COMMENT = 'Niveau de performance (VIRAL, HIGH, NORMAL, LOW)',
    ARTICLES.PAYWALL_TYPE AS paywall_type
      COMMENT = 'Type de paywall (none, soft, hard)',
    ENGAGEMENT.DAY AS day
      WITH SYNONYMS = ('date', 'jour')
      COMMENT = 'Date du jour'
  )

  METRICS (
    ARTICLES.TOTAL_UNIQUE_READERS AS SUM(articles.unique_readers)
      WITH SYNONYMS = ('lecteurs', 'readers', 'audience')
      COMMENT = 'Nombre total de lecteurs uniques',
    ARTICLES.AVG_READING_TIME AS AVG(articles.avg_read_time_sec)
      WITH SYNONYMS = ('temps de lecture', 'reading time')
      COMMENT = 'Temps moyen de lecture en secondes',
    ARTICLES.TOTAL_DEEP_READS AS SUM(articles.deep_reads)
      COMMENT = 'Total de lectures profondes (scroll > 75%)',
    ARTICLES.TOTAL_SHARES AS SUM(articles.shares)
      WITH SYNONYMS = ('partages')
      COMMENT = 'Nombre total de partages',
    ARTICLES.TOTAL_CONVERSIONS AS SUM(articles.conversions)
      WITH SYNONYMS = ('abonnements', 'subscriptions')
      COMMENT = 'Nombre total de conversions vers abonnement',
    ARTICLES.TOTAL_PAYWALL_HITS AS SUM(articles.paywall_hits)
      COMMENT = 'Nombre total d affichages du paywall',
    ARTICLES.ARTICLE_COUNT AS COUNT(articles.article_id)
      COMMENT = 'Nombre d articles',
    ENGAGEMENT.TOTAL_PAGE_VIEWS AS SUM(engagement.page_views)
      WITH SYNONYMS = ('pages vues', 'vues')
      COMMENT = 'Nombre total de pages vues',
    ENGAGEMENT.AVG_ENGAGEMENT AS AVG(engagement.avg_engagement_sec)
      COMMENT = 'Temps d engagement moyen en secondes'
  )

  COMMENT = 'Modele semantique pour l analyse editoriale Arctic Times — performances articles et engagement lecteurs';


-- ---------------------------------------------------------------------------
-- Cross-region inference (eu-west-3 needs this for the orchestration LLM)
-- ---------------------------------------------------------------------------
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';


-- ---------------------------------------------------------------------------
-- Cortex Agent: EDITORIAL_ASSISTANT (French-speaking editorial assistant)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE AGENT ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT
  COMMENT = 'Assistant editorial Arctic Times — performances articles et engagement lecteurs'
  PROFILE = '{"display_name": "Assistant Editorial", "color": "blue"}'
  FROM SPECIFICATION
  $$
  models:
    orchestration: auto

  orchestration:
    budget:
      seconds: 30
      tokens: 16000

  instructions:
    response: "Tu es l'assistant editorial du groupe Arctic Times. Reponds toujours en francais. Sois concis et oriente donnees. Quand tu presentes des chiffres, ajoute une interpretation editoriale (ex: quelle section performe le mieux, quels articles sont viraux, quels auteurs sont les plus lus)."
    orchestration: "Utilise l'outil ContentAnalytics pour toute question sur les performances des articles, l'engagement lecteurs, les conversions, ou les tendances par section, publication ou auteur."
    sample_questions:
      - question: "Quels articles ont le meilleur engagement cette semaine?"
      - question: "Quelle section perd des lecteurs?"
      - question: "Montre-moi les articles premium avec le meilleur taux de conversion"
      - question: "Compare Arctic Times vs Courrier Polaire en nombre de lecteurs"

  tools:
    - tool_spec:
        type: "cortex_analyst_text_to_sql"
        name: "ContentAnalytics"
        description: "Analyse les performances editoriales: articles, lecteurs, engagement, conversions, sections, auteurs et publications du groupe Arctic Times. Utilise ce tool pour toute question sur les donnees editoriales."

  tool_resources:
    ContentAnalytics:
      semantic_view: "ARCTIC_TIMES.AI.CONTENT_SV"
  $$;

SHOW AGENTS IN SCHEMA ARCTIC_TIMES.AI;
