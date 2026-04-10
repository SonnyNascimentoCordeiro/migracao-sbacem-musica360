-- T006: Popular staging a partir de mdb.sbacem (normalização decimal BR → ponto).
-- SR espelha PR na carga inicial (padrão legado Woodstock / spec 001).

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
