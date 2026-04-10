-- T011/T018: Esqueleto — integrantes a partir do staging (antes das linhas M360).
-- Incluir numero_link e documentação de ref_titular_nome → ver doc/display_nome_titular.md
--
-- Percentuais: usar pr_pct, mr_pct, sr_pct já ajustados após 08_apply_cessao_cedente.sql (cessão MR).

/*
INSERT INTO obras.obra_integrante (
    id_obra,
    id_pessoa,
    cod_categoria,
    percentual_pr,
    percentual_mr,
    percentual_sr,
    sequencia,
    numero_link,
    controlado,
    criacao
)
SELECT
    o.id AS id_obra,
    p.id AS id_pessoa,
    s.ip_role AS cod_categoria,  -- ou mapa formal: ver doc/role_map_sbacem_to_categoria.md
    s.pr_pct,
    s.mr_pct,
    s.sr_pct,
    ROW_NUMBER() OVER (PARTITION BY s.atlas_id ORDER BY s.source_row) AS sequencia,
    s.numero_link,
    FALSE,
    NOW()
FROM migracao_stg.sbacem_import_staging s
JOIN obras.obra o
  ON o.codigo = s.atlas_id AND o.id_tenant = 38
JOIN pessoas.pessoa p
  ON p.ip_name = s.ipi_name_number AND p.id_tenant = 38;
*/

SELECT 'TODO: mapear ip_role → cod_categoria; confirmar coluna numero_link no DDL; propagar ref_titular_nome conforme display_nome_titular.md.' AS status;
