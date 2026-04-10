-- T021: Inserir linhas Música 360 (MR = parcela; PR/SR = 0; SE se houver E no mesmo link).
-- PRÉ-REQUISITOS: view vw_parcela_cessao_por_link; coluna numero_link em obra_integrante; pessoa M360 no tenant 38.
-- Definir :id_pessoa_m360 antes de executar (psql \set id_pessoa_m360 2405890).

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
    o.id,
    :id_pessoa_m360::BIGINT,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM migracao_stg.sbacem_import_staging e
            WHERE e.atlas_id = v.atlas_id
              AND e.numero_link = v.numero_link
              AND e.ip_role = 'E'
        ) THEN 'SE'
        ELSE 'E'
    END,
    0,
    v.parcela_mr_m360,
    0,
    (SELECT COALESCE(MAX(oi.sequencia), 0) FROM obras.obra_integrante oi WHERE oi.id_obra = o.id)
      + ROW_NUMBER() OVER (PARTITION BY v.atlas_id ORDER BY v.numero_link),
    v.numero_link,
    FALSE,
    NOW()
FROM migracao_stg.vw_parcela_cessao_por_link v
JOIN obras.obra o ON o.codigo = v.atlas_id AND o.id_tenant = 38;
*/

SELECT 'TODO: descomentar INSERT após validar DDL e definir :id_pessoa_m360; conferir sequencia máxima por obra.' AS status;
