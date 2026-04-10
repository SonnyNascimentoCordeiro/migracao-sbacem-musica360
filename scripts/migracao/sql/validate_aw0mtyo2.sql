-- T023: Conferências para AW0MTYO2 (staging + pós-condições lógicas).
-- Após carga no Woodstock, repetir somas sobre obras.obra_integrante.

-- Staging: três links distintos no grupo A–H e parcelas M360 esperadas (15% / N_links BOCA).
SELECT 'staging_links' AS check_name, COUNT(DISTINCT numero_link) AS distinct_links
FROM migracao_stg.sbacem_import_staging
WHERE atlas_id = 'AW0MTYO2'
  AND chain_id IN ('A','B','C','F','G','H');

SELECT 'staging_parcela' AS check_name, v.*
FROM migracao_stg.vw_parcela_cessao_por_link v
WHERE v.atlas_id = 'AW0MTYO2'
ORDER BY v.numero_link;

-- Pós-carga (descomentar quando integrantes existirem):
/*
SELECT o.codigo, o.controlada, o.controle_mr,
       SUM(oi.percentual_mr) FILTER (WHERE p.id = :id_m360) AS sum_mr_m360
FROM obras.obra o
LEFT JOIN obras.obra_integrante oi ON oi.id_obra = o.id
LEFT JOIN pessoas.pessoa p ON p.id = oi.id_pessoa
WHERE o.id_tenant = 38 AND o.codigo = 'AW0MTYO2'
GROUP BY o.id, o.codigo, o.controlada, o.controle_mr;
*/
