-- T012/T015: Atribuição determinística de numero_link por obra (spec 002 / research.md).
-- Fase 1: pares (titular.chain_id = T e editor.chain = T) — ordem lexicográfica de T.
-- Fase 2: linhas ainda NULL cujo chain_id não é valor de chain de nenhuma linha da obra.
-- Fase 3: demais NULL — uma linha = um link, ordenação por chain_id.

-- Fase 1
WITH ref_editor AS (
    SELECT DISTINCT
        atlas_id,
        NULLIF(TRIM(chain), '') AS titular_ref
    FROM migracao_stg.sbacem_import_staging
    WHERE NULLIF(TRIM(chain), '') IS NOT NULL
),
ordered_pairs AS (
    SELECT
        atlas_id,
        titular_ref AS t,
        ROW_NUMBER() OVER (PARTITION BY atlas_id ORDER BY titular_ref) AS link_num
    FROM ref_editor
)
UPDATE migracao_stg.sbacem_import_staging s
SET numero_link = o.link_num
FROM ordered_pairs o
WHERE s.atlas_id = o.atlas_id
  AND (
        NULLIF(TRIM(s.chain_id), '') = o.t
        OR NULLIF(TRIM(s.chain), '') = o.t
      );

-- Fase 2
WITH ref AS (
    SELECT DISTINCT
        atlas_id,
        NULLIF(TRIM(chain), '') AS c
    FROM migracao_stg.sbacem_import_staging
    WHERE NULLIF(TRIM(chain), '') IS NOT NULL
),
candidates AS (
    SELECT s.id
    FROM migracao_stg.sbacem_import_staging s
    WHERE s.numero_link IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ref r
          WHERE r.atlas_id = s.atlas_id
            AND r.c = NULLIF(TRIM(s.chain_id), '')
      )
),
dedup AS (
    SELECT DISTINCT s.atlas_id, NULLIF(TRIM(s.chain_id), '') AS chain_id_norm
    FROM migracao_stg.sbacem_import_staging s
    JOIN candidates c ON c.id = s.id
    WHERE NULLIF(TRIM(s.chain_id), '') IS NOT NULL
),
ord2 AS (
    SELECT
        atlas_id,
        chain_id_norm,
        ROW_NUMBER() OVER (PARTITION BY atlas_id ORDER BY chain_id_norm) AS rn
    FROM dedup
),
mx AS (
    SELECT atlas_id, COALESCE(MAX(numero_link), 0) AS m
    FROM migracao_stg.sbacem_import_staging
    GROUP BY atlas_id
),
assign2 AS (
    SELECT o.atlas_id, o.chain_id_norm, mx.m + o.rn AS new_link
    FROM ord2 o
    JOIN mx ON mx.atlas_id = o.atlas_id
)
UPDATE migracao_stg.sbacem_import_staging s
SET numero_link = a.new_link
FROM assign2 a
WHERE s.atlas_id = a.atlas_id
  AND NULLIF(TRIM(s.chain_id), '') = a.chain_id_norm
  AND s.numero_link IS NULL;

-- Fase 3 (fallback linhas remanescentes)
WITH mx AS (
    SELECT atlas_id, COALESCE(MAX(numero_link), 0) AS m
    FROM migracao_stg.sbacem_import_staging
    GROUP BY atlas_id
),
remaining AS (
    SELECT
        s.id,
        s.atlas_id,
        ROW_NUMBER() OVER (
            PARTITION BY s.atlas_id
            ORDER BY NULLIF(TRIM(s.chain_id), '') NULLS LAST, s.source_row
        ) AS rn
    FROM migracao_stg.sbacem_import_staging s
    WHERE s.numero_link IS NULL
)
UPDATE migracao_stg.sbacem_import_staging s
SET numero_link = mx.m + r.rn
FROM remaining r
JOIN mx ON mx.atlas_id = r.atlas_id
WHERE s.id = r.id;
