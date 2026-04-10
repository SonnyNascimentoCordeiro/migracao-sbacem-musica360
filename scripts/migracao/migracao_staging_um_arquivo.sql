-- =============================================================================
-- MIGRAÇÃO STAGING — UM ÚNICO ARQUIVO (ordem correta embutida)
-- =============================================================================
-- Como executar (PowerShell, na pasta scripts/migracao):
--   $env:PGPASSWORD = "senha"
--   psql -h HOST -p 5432 -U backstage -d woodstock -v ON_ERROR_STOP=1 -f migracao_staging_um_arquivo.sql
--
-- DBeaver: abra este arquivo e execute o script inteiro (Ctrl+Enter em modo script).
--
-- SEGURANÇA:
--   Não há DELETE em obras/pessoas/mdb.sbacem.
--   Há DROP/TRUNCATE apenas em migracao_stg.sbacem_import_staging (tabela de trabalho).
--
-- Pré-requisitos: schemas mdb.sbacem, mdb.titular, mdb.titular2 existentes no mesmo banco.
-- =============================================================================

SET client_encoding = 'UTF8';


-- =============================================================================
-- 1) Staging: schema + tabela
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS migracao_stg;

DROP TABLE IF EXISTS migracao_stg.sbacem_import_staging;

CREATE TABLE migracao_stg.sbacem_import_staging (
    id                BIGSERIAL PRIMARY KEY,
    atlas_id          VARCHAR(64) NOT NULL,
    chain_id          VARCHAR(32),
    chain             VARCHAR(32),
    ip_name           TEXT,
    ipi_name_number   VARCHAR(32),
    ip_role           VARCHAR(8),
    pr_pct            DOUBLE PRECISION,
    mr_pct            DOUBLE PRECISION,
    sr_pct            DOUBLE PRECISION,
    numero_link       INTEGER,
    ref_titular_nome  TEXT,
    source_row        INTEGER NOT NULL DEFAULT 0,
    criacao_staging   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_stg_atlas ON migracao_stg.sbacem_import_staging (atlas_id);
CREATE INDEX ix_stg_atlas_link ON migracao_stg.sbacem_import_staging (atlas_id, numero_link);

COMMENT ON TABLE migracao_stg.sbacem_import_staging IS 'Linhas mdb.sbacem enriquecidas: percentuais normalizados, link editorial, ref titular para UI.';


-- =============================================================================
-- 2) Popular staging a partir de mdb.sbacem
-- =============================================================================

TRUNCATE migracao_stg.sbacem_import_staging RESTART IDENTITY;

INSERT INTO migracao_stg.sbacem_import_staging (
    atlas_id,
    chain_id,
    chain,
    ip_name,
    ipi_name_number,
    ip_role,
    pr_pct,
    mr_pct,
    sr_pct,
    source_row
)
SELECT
    s.atlas_id,
    NULLIF(TRIM(s.chain_id), ''),
    NULLIF(TRIM(s.chain), ''),
    s.ip_name,
    s.ipi_name_number,
    NULLIF(TRIM(s.ip_role), ''),
    REPLACE(COALESCE(s.per_own, '0'), ',', '.')::DOUBLE PRECISION,
    REPLACE(COALESCE(s.mec_own, '0'), ',', '.')::DOUBLE PRECISION,
    REPLACE(COALESCE(s.per_own, '0'), ',', '.')::DOUBLE PRECISION,
    ROW_NUMBER() OVER (PARTITION BY s.atlas_id ORDER BY s.chain_id NULLS LAST, s.ip_name_number)
FROM mdb.sbacem s;


-- =============================================================================
-- 3) Verificação DDL: coluna de link em obras.obra_integrante (só consulta)
-- =============================================================================

SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type
FROM information_schema.columns c
WHERE c.table_schema = 'obras'
  AND c.table_name = 'obra_integrante'
  AND c.column_name IN ('numero_link', 'link', 'nr_link', 'cod_link');


-- =============================================================================
-- 4) View: cessão MR unificada (titular + titular2)
-- =============================================================================

CREATE OR REPLACE VIEW migracao_stg.vw_cessao_mr_por_cae AS
SELECT
    cae,
    MAX(cessao_numeric) AS percentual_cessao_mr
FROM (
    SELECT
        TRIM(t.cae) AS cae,
        REPLACE(TRIM(t.percentual::TEXT), ',', '.')::DOUBLE PRECISION AS cessao_numeric
    FROM mdb.titular t
    WHERE TRIM(COALESCE(t.cae, '')) <> ''

    UNION ALL

    SELECT
        TRIM(t2.cae) AS cae,
        REPLACE(TRIM(t2.percentual::TEXT), ',', '.')::DOUBLE PRECISION AS cessao_numeric
    FROM mdb.titular2 t2
    WHERE TRIM(COALESCE(t2.cae, '')) <> ''
) u
WHERE cae IS NOT NULL AND cae <> ''
GROUP BY cae;

COMMENT ON VIEW migracao_stg.vw_cessao_mr_por_cae IS 'Cessão total de MR (%) à M360 por CAE/IPI; titular + titular2 unificados.';


-- =============================================================================
-- 5) Atribuir numero_link (3 fases)
-- =============================================================================

-- Fase 1: pares editoriais
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

-- Fase 2: titulares sem referência em chain
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

-- Fase 3: fallback
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


-- =============================================================================
-- 6) Nome do titular na linha editorial (ref_titular_nome)
-- =============================================================================

UPDATE migracao_stg.sbacem_import_staging s
SET ref_titular_nome = t.ip_name
FROM migracao_stg.sbacem_import_staging t
WHERE s.atlas_id = t.atlas_id
  AND NULLIF(TRIM(s.chain), '') IS NOT NULL
  AND NULLIF(TRIM(t.chain_id), '') = NULLIF(TRIM(s.chain), '');


-- =============================================================================
-- 7) View: parcela de cessão MR por link
-- =============================================================================

CREATE OR REPLACE VIEW migracao_stg.vw_parcela_cessao_por_link AS
WITH ced AS (
    SELECT * FROM migracao_stg.vw_cessao_mr_por_cae
),
nlinks AS (
    SELECT
        s.atlas_id,
        s.ipi_name_number AS cae,
        COUNT(DISTINCT s.numero_link) AS n_links
    FROM migracao_stg.sbacem_import_staging s
    INNER JOIN ced c ON c.cae = s.ipi_name_number
    GROUP BY s.atlas_id, s.ipi_name_number
)
SELECT DISTINCT
    s.atlas_id,
    s.numero_link,
    s.ipi_name_number AS cedente_cae,
    c.percentual_cessao_mr / NULLIF(n.n_links, 0) AS parcela_mr_m360
FROM migracao_stg.sbacem_import_staging s
INNER JOIN ced c ON c.cae = s.ipi_name_number
INNER JOIN nlinks n ON n.atlas_id = s.atlas_id AND n.cae = s.ipi_name_number;

COMMENT ON VIEW migracao_stg.vw_parcela_cessao_por_link IS 'Parcela igualitária da cessão MR por link do cedente (N links distintos na obra).';


-- =============================================================================
-- 8) Aplicar cessão: reduz MR do cedente no staging
-- =============================================================================

UPDATE migracao_stg.sbacem_import_staging s
SET mr_pct = GREATEST(0, s.mr_pct - v.parcela_mr_m360)
FROM migracao_stg.vw_parcela_cessao_por_link v
WHERE s.atlas_id = v.atlas_id
  AND s.numero_link = v.numero_link
  AND s.ipi_name_number = v.cedente_cae;


-- =============================================================================
-- FIM do fluxo staging. Próximo passo (outro arquivo / manual): INSERT em
-- pessoas/obras/obra_integrante quando o DDL estiver fechado.
-- =============================================================================
