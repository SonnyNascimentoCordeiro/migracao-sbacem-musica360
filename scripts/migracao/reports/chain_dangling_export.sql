-- T014: Relatório CHAIN_DANGLING — chain preenchido sem titular correspondente na mesma obra.
-- Copiar resultado para scripts/migracao/reports/ se desejado: \copy (query) TO 'chain_dangling.csv' CSV HEADER

SELECT
    s.atlas_id,
    s.chain_id,
    s.chain,
    s.ip_name,
    s.ipi_name_number,
    s.ip_role,
    'CHAIN_DANGLING' AS motivo
FROM migracao_stg.sbacem_import_staging s
WHERE NULLIF(TRIM(s.chain), '') IS NOT NULL
  AND NOT EXISTS (
        SELECT 1
        FROM migracao_stg.sbacem_import_staging t
        WHERE t.atlas_id = s.atlas_id
          AND NULLIF(TRIM(t.chain_id), '') = NULLIF(TRIM(s.chain), '')
  )
ORDER BY s.atlas_id, s.chain_id;
