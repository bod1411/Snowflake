
CREATE DATABASE IF NOT EXISTS RAG_DB;
USE DATABASE RAG_DB;
CREATE SCHEMA IF NOT EXISTS RAG_SCHEMA;
USE SCHEMA RAG_SCHEMA;

CREATE OR REPLACE TABLE LAWS_OF_POWER_RAW (
  LAW_ID        INTEGER,
  LAW_NUMBER    INTEGER,
  LAW_TITLE     STRING,
  LAW_SUMMARY   STRING,
  FULL_TEXT     STRING
);

select * from LAWS_OF_POWER_RAW;




ALTER TABLE LAWS_OF_POWER_RAW
ADD COLUMN LAW_EMBED VECTOR(FLOAT, 768);

---Create Chuncks 
UPDATE LAWS_OF_POWER_RAW
SET LAW_EMBED = SNOWFLAKE.CORTEX.EMBED_TEXT_768(
  'snowflake-arctic-embed-m',
  FULL_TEXT
);

select * from LAWS_OF_POWER_RAW;


-- Assume a session variable QUERY_TEXT already set
SET QUERY_TEXT = 'which law talks about reputation?';

WITH QUERY AS (
  SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768(
           'snowflake-arctic-embed-m',
           $QUERY_TEXT
         ) AS QUERY_VEC
),
RESULT AS (
  SELECT
    L.LAW_NUMBER,
    L.LAW_TITLE,
    L.FULL_TEXT,
    VECTOR_COSINE_SIMILARITY(L.LAW_EMBED, Q.QUERY_VEC) AS SIMILARITY
  FROM LAWS_OF_POWER_RAW L, QUERY Q
  ORDER BY SIMILARITY DESC
  LIMIT 3
),
CONCAT_TEXT AS (
  SELECT
    $QUERY_TEXT AS QUERY_TEXT,
    LISTAGG(
      CONCAT('Law ', LAW_NUMBER, ' - ', LAW_TITLE, ': ', FULL_TEXT),
      '\n\n'
    ) AS CONTEXT_TEXT
  FROM RESULT
)
SELECT
  SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-7b',
    CONCAT(
      'You are an assistant that answers questions about the 48 Laws of Power. ',
      'Use only the following laws as your source of truth.\n\n',
      'User question: ', QUERY_TEXT, '\n\n',
      'Relevant laws:\n',
      CONTEXT_TEXT,
      '\n\nAnswer in a concise paragraph.'
    )
  ) AS ANSWER
FROM CONCAT_TEXT;
