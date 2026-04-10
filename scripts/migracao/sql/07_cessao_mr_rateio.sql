-- T019: View com parcela de MR da M360 por (obra, link, CAE cedente).
-- Rateio: cessão total / COUNT(DISTINCT numero_link) do mesmo CAE na obra (research.md).

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
