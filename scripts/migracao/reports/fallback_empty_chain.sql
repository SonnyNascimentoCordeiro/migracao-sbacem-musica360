-- T016: Auditoria — linhas que receberam link apenas na fase 2/3 (útil para revisar política FR-004).
-- Heurística: após carga completa, exportar obras com muitas linhas "somente fallback".

SELECT
    s.atlas_id,
    s.chain_id,
    s.chain,
    s.ip_name,
    s.numero_link,
    CASE
        WHEN NULLIF(TRIM(s.chain), '') IS NULL THEN 'EMPTY_CHAIN_ROW'
        ELSE 'OTHER'
    END AS bucket
FROM migracao_stg.sbacem_import_staging s
WHERE NULLIF(TRIM(s.chain), '') IS NULL
ORDER BY s.atlas_id, s.numero_link, s.chain_id;
