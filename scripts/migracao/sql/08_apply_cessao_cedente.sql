-- T020: Desconta MR do cedente em cada linha do staging no mesmo (atlas_id, link, CAE).

UPDATE migracao_stg.sbacem_import_staging s
SET mr_pct = GREATEST(0, s.mr_pct - v.parcela_mr_m360)
FROM migracao_stg.vw_parcela_cessao_por_link v
WHERE s.atlas_id = v.atlas_id
  AND s.numero_link = v.numero_link
  AND s.ipi_name_number = v.cedente_cae;
