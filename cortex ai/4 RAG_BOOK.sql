CREATE OR REPLACE STAGE books_stage
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    DIRECTORY = (ENABLE = TRUE);

ALTER STAGE books_stage REFRESH;

SELECT * FROM DIRECTORY(@RAG_DB.RAG_SCHEMA.BOOKS_STAGE);
-- Step 6: Parse the book into a table
CREATE OR REPLACE TABLE DOCUMENTS_PARSED AS
SELECT
    relative_path AS DOC_PATH,
    AI_PARSE_DOCUMENT(
        TO_FILE('@books_stage', relative_path),
        {'mode': 'LAYOUT', 'page_split': true}
    ) AS PARSED
FROM DIRECTORY(@books_stage)
WHERE relative_path = 'What-to-Say-When-you-Talk-To-Yourself.pdf';

select * from DOCUMENTS_PARSED;

-- Diagnostic: inspect raw JSON structure
SELECT PARSED FROM DOCUMENTS_PARSED LIMIT 1;

-- Inspect first page element structure
SELECT PARSED['pages'][0] AS FIRST_PAGE FROM DOCUMENTS_PARSED LIMIT 1;

-- Check keys in each page object
SELECT f.index AS PAGE_INDEX, OBJECT_KEYS(f.value) AS PAGE_KEYS
FROM DOCUMENTS_PARSED p,
LATERAL FLATTEN(input => p.PARSED['pages']) f
LIMIT 3;

-- Flatten each page from the parsed JSON into its own row
CREATE OR REPLACE TABLE BOOK_CHUNKS AS
SELECT
    p.DOC_PATH,
    f.value['index']::INTEGER   AS PAGE_NUM,
    f.value['content']::STRING  AS CHUNK_TEXT
FROM DOCUMENTS_PARSED p,
     LATERAL FLATTEN(input => p.PARSED['pages']) f
WHERE f.value['content']::STRING IS NOT NULL
  AND LENGTH(f.value['content']::STRING) > 0;

  
SELECT * FROM BOOK_CHUNKS LIMIT 10;


-- Add embedding column (same as RAG_text.sql)
ALTER TABLE BOOK_CHUNKS
ADD COLUMN CHUNK_EMBED VECTOR(FLOAT, 768);

-- Embed each chunk's text (same function as RAG_text.sql)
UPDATE BOOK_CHUNKS
SET CHUNK_EMBED = SNOWFLAKE.CORTEX.EMBED_TEXT_768(
    'snowflake-arctic-embed-m',
    CHUNK_TEXT
);
    
SELECT * FROM BOOK_CHUNKS LIMIT 5;



SET QUERY_TEXT = 'What does the book say about self-talk?';

WITH QUERY AS (
    SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768(
        'snowflake-arctic-embed-m',
        $QUERY_TEXT
    ) AS QUERY_VEC
),
RESULT AS (
    SELECT
        B.DOC_PATH,
        B.PAGE_NUM,
        B.CHUNK_TEXT,
        VECTOR_COSINE_SIMILARITY(B.CHUNK_EMBED, Q.QUERY_VEC) AS SIMILARITY
    FROM BOOK_CHUNKS B, QUERY Q
    ORDER BY SIMILARITY DESC
    LIMIT 3
),
CONCAT_TEXT AS (
    SELECT
        $QUERY_TEXT AS QUERY_TEXT,
        LISTAGG(
            CONCAT('Page ', PAGE_NUM, ': ', CHUNK_TEXT),
            '\\n\\n'
        ) AS CONTEXT_TEXT
    FROM RESULT
)
SELECT
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-7b',
        CONCAT(
            'You are an assistant that answers questions about the book. ',
            'Use only the following content as your source of truth.\\n\\n',
            'User question: ', QUERY_TEXT, '\\n\\n',
            'Relevant pages:\\n',
            CONTEXT_TEXT,
            '\\n\\nAnswer in a concise paragraph.'
        )
    ) AS ANSWER
FROM CONCAT_TEXT;

-- ============================================================
-- SELF-TALK SCRIPT + BEHAVIOUR CHANGE PLAN
-- Change QUERY_TEXT to any habit/behaviour goal
-- ============================================================


SET QUERY_TEXT = 'I want to quit smoking. Can you provide a self-talk script I need to repeat to myself and a step by step plan to change my behaviour?';

WITH QUERY AS (
    SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_768(
        'snowflake-arctic-embed-m',
        $QUERY_TEXT
    ) AS QUERY_VEC
),
RESULT AS (
    SELECT
        B.DOC_PATH,
        B.PAGE_NUM,
        B.CHUNK_TEXT,
        VECTOR_COSINE_SIMILARITY(B.CHUNK_EMBED, Q.QUERY_VEC) AS SIMILARITY
    FROM BOOK_CHUNKS B, QUERY Q
    ORDER BY SIMILARITY DESC
    LIMIT 5
),
CONCAT_TEXT AS (
    SELECT
        $QUERY_TEXT AS QUERY_TEXT,
        LISTAGG(
            CONCAT('Page ', PAGE_NUM, ': ', CHUNK_TEXT),
            '\n\n'
        ) AS CONTEXT_TEXT
    FROM RESULT
)
SELECT
    SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-7b',
        CONCAT(
            'You are a supportive self-improvement coach trained on the book "What to Say When You Talk to Yourself" by Shad Helmstetter. ',
            'Your role is to help people rewire their thinking and change specific behaviours using the self-talk techniques from the book.\n\n',
            'The user has a specific behaviour change goal. Using ONLY the book content below as your source of truth, respond with TWO clearly labelled sections:\n\n',
            '--- SECTION 1: YOUR SELF-TALK SCRIPT ---\n',
            'Write a personalised self-talk script the user should say to themselves daily. ',
            'The script must be written in first-person present tense (e.g. "I am...", "I choose...", "I no longer need..."). ',
            'Make it specific to their goal. Include 6 to 10 powerful self-talk statements drawn from the book techniques.\n\n',
            '--- SECTION 2: YOUR STEP-BY-STEP BEHAVIOUR CHANGE PLAN ---\n',
            'Provide a practical 5-step plan the user can follow to embed this new self-talk and change their behaviour. ',
            'Each step must include: what to do, when to do it, and why it works based on the book. ',
            'Step 1 must always be: Record the self-talk script above in your own voice. ',
            'Step 2 must always be: Listen to the recording morning, afternoon, and evening every day. ',
            'Step 3 must always be: Write the key statements and place them somewhere visible (mirror, desk, phone wallpaper). ',
            'Steps 4 and 5 should be drawn from the book content provided.\n\n',
            'User goal: ',
            QUERY_TEXT, '\n\n',
            'Relevant book content:\n',
            CONTEXT_TEXT,
            '\n\nRemember: respond only with the two sections above. Be warm, encouraging, and specific to the user goal.'
        )
    ) AS ANSWER
FROM CONCAT_TEXT;