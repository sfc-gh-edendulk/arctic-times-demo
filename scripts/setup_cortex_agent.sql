-- ============================================================================
-- Arctic Times — Cortex Agent Setup
-- ============================================================================
-- Creates the Semantic View and Cortex Agent for the editorial assistant.
-- Run AFTER dbt models and Dynamic Tables are populated.
-- ============================================================================

USE DATABASE ARCTIC_TIMES;
USE SCHEMA AI;

-- ---------------------------------------------------------------------------
-- Semantic View: CONTENT_SV
-- Covers article performance, reader engagement, and subscriber journeys.
-- The agent uses this to answer editorial questions in natural language.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE SEMANTIC VIEW ARCTIC_TIMES.AI.CONTENT_SV
  COMMENT = 'Editorial content analytics — articles, readers, engagement, subscriptions'
AS
  SELECT *
  FROM (

    -- Entity 1: Articles with performance metrics
    SELECT
        article_id,
        title,
        author,
        section,
        publication,
        published_at,
        word_count,
        paywall_type,
        unique_readers,
        total_events,
        avg_engagement_sec,
        deep_reads,
        shares,
        paywall_hits,
        conversions,
        conversion_rate_pct,
        lifespan_hours,
        performance_tier
    FROM ARCTIC_TIMES.MARTS.CONTENT_ANALYTICS

  ) articles

  JOIN (

    -- Entity 2: Reader engagement by section/day
    SELECT
        day,
        section,
        unique_readers AS section_unique_readers,
        page_views,
        avg_engagement_sec AS section_avg_engagement_sec,
        paywall_hits AS section_paywall_hits,
        subscribe_clicks,
        conversion_rate_pct AS section_conversion_rate_pct
    FROM ARCTIC_TIMES.CURATED.READER_ENGAGEMENT

  ) engagement
    ON articles.section = engagement.section

  COLUMNS (
    -- Article dimensions
    articles.article_id
      LABEL 'Article ID'
      DESCRIPTION 'Unique identifier for each article',
    articles.title
      LABEL 'Title'
      DESCRIPTION 'Article headline',
    articles.author
      LABEL 'Author'
      DESCRIPTION 'Name of the journalist who wrote the article',
    articles.section
      LABEL 'Section'
      DESCRIPTION 'Editorial section: Politique, International, Economie, Culture, Sciences, Sport, Planete, Opinions, Societe',
    articles.publication
      LABEL 'Publication'
      DESCRIPTION 'Which publication within the group (Arctic Times, Courrier Polaire, etc.)',
    articles.published_at
      LABEL 'Published Date'
      DESCRIPTION 'When the article was first published',
    articles.word_count
      LABEL 'Word Count'
      DESCRIPTION 'Length of the article in words',
    articles.paywall_type
      LABEL 'Paywall Type'
      DESCRIPTION 'none, soft, or hard paywall',
    articles.performance_tier
      LABEL 'Performance Tier'
      DESCRIPTION 'VIRAL (>5000 readers), HIGH (>1000), NORMAL (>200), LOW',

    -- Article metrics
    articles.unique_readers
      LABEL 'Unique Readers'
      DESCRIPTION 'Number of distinct users who read this article',
    articles.total_events
      LABEL 'Total Events'
      DESCRIPTION 'Total interaction events on this article',
    articles.avg_engagement_sec
      LABEL 'Avg Engagement (sec)'
      DESCRIPTION 'Average time spent reading this article in seconds',
    articles.deep_reads
      LABEL 'Deep Reads'
      DESCRIPTION 'Number of readers who scrolled past 75% of the article',
    articles.shares
      LABEL 'Shares'
      DESCRIPTION 'Number of times the article was shared',
    articles.paywall_hits
      LABEL 'Paywall Hits'
      DESCRIPTION 'Number of times readers hit the paywall on this article',
    articles.conversions
      LABEL 'Conversions'
      DESCRIPTION 'Number of subscription sign-ups from this article',
    articles.conversion_rate_pct
      LABEL 'Conversion Rate (%)'
      DESCRIPTION 'Percentage of paywall hits that converted to subscriptions',
    articles.lifespan_hours
      LABEL 'Lifespan (hours)'
      DESCRIPTION 'Hours between publication and last reader interaction',

    -- Engagement dimensions & metrics
    engagement.day
      LABEL 'Date'
      DESCRIPTION 'Calendar date of the engagement data',
    engagement.section_unique_readers
      LABEL 'Section Daily Readers'
      DESCRIPTION 'Unique readers in this section on this day',
    engagement.page_views
      LABEL 'Page Views'
      DESCRIPTION 'Total page views in the section on this day',
    engagement.section_avg_engagement_sec
      LABEL 'Section Avg Engagement (sec)'
      DESCRIPTION 'Average engagement time in the section on this day',
    engagement.section_paywall_hits
      LABEL 'Section Paywall Hits'
      DESCRIPTION 'Paywall hits in this section on this day',
    engagement.subscribe_clicks
      LABEL 'Subscribe Clicks'
      DESCRIPTION 'Subscription button clicks in this section on this day',
    engagement.section_conversion_rate_pct
      LABEL 'Section Conversion Rate (%)'
      DESCRIPTION 'Section-level conversion rate on this day'
  )

  FILTERS (
    articles.section IN ('Politique', 'International', 'Economie', 'Culture', 'Sciences', 'Sport', 'Planete', 'Opinions', 'Societe')
      LABEL 'Section Filter'
      DESCRIPTION 'Filter by editorial section',
    articles.performance_tier IN ('VIRAL', 'HIGH', 'NORMAL', 'LOW')
      LABEL 'Performance Tier Filter'
      DESCRIPTION 'Filter by article performance category',
    articles.paywall_type IN ('none', 'soft', 'hard')
      LABEL 'Paywall Filter'
      DESCRIPTION 'Filter by paywall type'
  )

  METRICS (
    SUM(articles.unique_readers)
      LABEL 'Total Readers'
      DESCRIPTION 'Sum of unique readers across articles',
    AVG(articles.avg_engagement_sec)
      LABEL 'Avg Engagement Time'
      DESCRIPTION 'Average engagement time across articles in seconds',
    SUM(articles.conversions)
      LABEL 'Total Conversions'
      DESCRIPTION 'Total subscription conversions',
    AVG(articles.conversion_rate_pct)
      LABEL 'Avg Conversion Rate'
      DESCRIPTION 'Average conversion rate across articles'
  );


-- ---------------------------------------------------------------------------
-- Cortex Agent: EDITORIAL_ASSISTANT
-- French-speaking editorial assistant for the newsroom.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE CORTEX AGENT ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT
  TOOLS = (
    snowflake_data_tool(
      semantic_view => 'ARCTIC_TIMES.AI.CONTENT_SV'
    )
  )
  COMMENT = 'Assistant editorial — performances articles, tendances lecteurs, conversions abonnements'
  LLM = 'claude-3-5-sonnet'
  SYSTEM_PROMPT = 'Tu es un assistant éditorial pour Arctic Times, un groupe de presse français. Tu aides les journalistes et rédacteurs en chef à comprendre les performances de leurs articles, les tendances de lectorat, et les opportunités de conversion. Réponds toujours en français. Sois concis et factuel. Quand tu donnes des chiffres, mets-les en contexte (comparaison temporelle ou entre sections).';


-- ---------------------------------------------------------------------------
-- Test queries (run these to verify the agent works)
-- ---------------------------------------------------------------------------

-- Test 1: Article performance
-- SELECT SNOWFLAKE.CORTEX.AGENT(
--   'ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT',
--   'Quels articles ont le meilleur engagement cette semaine?'
-- );

-- Test 2: Section trends
-- SELECT SNOWFLAKE.CORTEX.AGENT(
--   'ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT',
--   'Quelle section perd des lecteurs par rapport au mois dernier?'
-- );

-- Test 3: Conversion analysis
-- SELECT SNOWFLAKE.CORTEX.AGENT(
--   'ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT',
--   'Montre-moi les articles premium avec le meilleur taux de conversion'
-- );

-- Test 4: Author performance
-- SELECT SNOWFLAKE.CORTEX.AGENT(
--   'ARCTIC_TIMES.AI.EDITORIAL_ASSISTANT',
--   'Quel journaliste a les meilleurs scores d''engagement ce mois-ci?'
-- );
