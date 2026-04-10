-- T005: Staging por linha da sbacem + colunas derivadas (link, nome titular referenciado).
-- Executar uma vez por ambiente (schema dedicado evita conflito com outros processos).

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
