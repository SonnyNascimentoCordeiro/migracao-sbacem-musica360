-- T010: Esqueleto — inserir obras.obra (tenant 38, id_configuracao 61).
-- AJUSTAR colunas obrigatórias e defaults ao DDL real.

/*
INSERT INTO obras.obra (
    id_tenant,
    id_configuracao,
    codigo,
    titulo,
    iswc,
    situacao,
    cod_tipo_versao,
    cancelada,
    retida,
    gravada,
    instrumental,
    importado,
    nacional,
    criacao
)
SELECT DISTINCT ON (s.atlas_id)
    38,
    61,
    s.atlas_id,
    MAX(s0.original_title) AS titulo,
    MAX(s0.iswc) AS iswc,
    'L'::CHAR AS situacao,
    'ORI'::VARCHAR AS cod_tipo_versao,
    FALSE, FALSE, FALSE, FALSE,
    TRUE,
    TRUE,  -- nacional: confirmar com negócio
    NOW()
FROM migracao_stg.sbacem_import_staging s
JOIN mdb.sbacem s0 ON s0.atlas_id = s.atlas_id
GROUP BY s.atlas_id;
*/

SELECT 'TODO: alinhar colunas (nacional, controlada inicial, etc.) e título/ISWC agregados por atlas_id.' AS status;
