-- T008: Uma cessão MR por CAE (FR-008): união mdb.titular + mdb.titular2 com MAX como desempate conservador.
-- Ajuste nomes de colunas se o DDL real de mdb.titular diferir (ex.: percentual como text/varchar).

CREATE OR REPLACE VIEW migracao_stg.vw_cessao_mr_por_cae AS
SELECT
    cae,
    MAX(cessao_numeric) AS percentual_cessao_mr
FROM (
    SELECT
        TRIM(t.cae) AS cae,
        REPLACE(TRIM(t.percentual::TEXT), ',', '.')::DOUBLE PRECISION AS cessao_numeric
    FROM mdb.titular t
    WHERE TRIM(COALESCE(t.cae, '')) <> ''

    UNION ALL

    SELECT
        TRIM(t2.cae) AS cae,
        REPLACE(TRIM(t2.percentual::TEXT), ',', '.')::DOUBLE PRECISION AS cessao_numeric
    FROM mdb.titular2 t2
    WHERE TRIM(COALESCE(t2.cae, '')) <> ''
) u
WHERE cae IS NOT NULL AND cae <> ''
GROUP BY cae;

COMMENT ON VIEW migracao_stg.vw_cessao_mr_por_cae IS 'Cessão total de MR (%) à M360 por CAE/IPI; titular + titular2 unificados.';
