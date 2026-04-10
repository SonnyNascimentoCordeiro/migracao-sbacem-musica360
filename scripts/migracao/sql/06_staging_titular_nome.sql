-- T017: Nome do titular referenciado pela linha editorial (FR-005).

UPDATE migracao_stg.sbacem_import_staging s
SET ref_titular_nome = t.ip_name
FROM migracao_stg.sbacem_import_staging t
WHERE s.atlas_id = t.atlas_id
  AND NULLIF(TRIM(s.chain), '') IS NOT NULL
  AND NULLIF(TRIM(t.chain_id), '') = NULLIF(TRIM(s.chain), '');
