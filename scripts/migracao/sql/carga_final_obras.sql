-- =============================================================================
-- CARGA FINAL — obras.obra + obras.obra_titulo + obras.obra_integrante
-- Tenant 38 / Configuração 61 / M360
-- =============================================================================
-- EXECUÇÃO:
--   CALL mdb.carga_final_obras();
-- =============================================================================

SET client_encoding = 'UTF8';

-- Função auxiliar para converter percentual com segurança
CREATE OR REPLACE FUNCTION mdb.migracao_to_float(v TEXT) RETURNS float AS $$
BEGIN
    RETURN REPLACE(v, ',', '.')::float;
EXCEPTION WHEN others THEN
    RETURN 0;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- Procedure principal
CREATE OR REPLACE PROCEDURE mdb.carga_final_obras()
LANGUAGE plpgsql AS $$
DECLARE
    v_obra_id   BIGINT;
    v_atlas_id  VARCHAR;
    v_link      INTEGER;
    v_seq       INTEGER;
    v_mr_cedido FLOAT;
    v_ipi       VARCHAR;
    v_ipi_base  VARCHAR;
    v_per_own   FLOAT;
    v_mec_own   FLOAT;
    v_pct_tit   FLOAT;
    v_ip_role   VARCHAR;
    v_pessoa_id BIGINT;
    v_numero_link INTEGER;
BEGIN

    RAISE NOTICE 'Passo 1: Inserindo obras...';

    INSERT INTO obras.obra (
        id_tenant, id_configuracao, codigo, titulo, iswc,
        situacao, cod_tipo_versao, cancelada, retida, gravada,
        instrumental, importado, nacional, registro,
        controlada, controle_pr, controle_mr, controle_sr, criacao
    )
    SELECT
        38, 61,
        s.atlas_id,
        MAX(s.original_title),
        MAX(NULLIF(TRIM(s.iswc), '')),
        'L', 'ORI', false, false, false, false, true, true,
        CURRENT_DATE, false, 0, 0, 0, NOW()
    FROM mdb.sbacem s
    WHERE s.ignorar IS DISTINCT FROM true
    GROUP BY s.atlas_id;

    RAISE NOTICE 'Passo 1 concluído: % obras inseridas', (SELECT COUNT(*) FROM obras.obra WHERE id_tenant = 38);

    -- =========================================================================
    RAISE NOTICE 'Passo 2: Inserindo títulos alternativos...';

    INSERT INTO obras.obra_titulo (id_obra, titulo, cod_tipo_titulo, cod_idioma, ativo, criacao)
    SELECT
        o.id,
        TRIM(alt.titulo),
        'AL', NULL, true, NOW()
    FROM (
        SELECT DISTINCT
            atlas_id,
            TRIM(UNNEST(STRING_TO_ARRAY(alternate_titles, '|'))) AS titulo
        FROM mdb.sbacem
        WHERE alternate_titles IS NOT NULL
          AND TRIM(alternate_titles) <> ''
          AND ignorar IS DISTINCT FROM true
    ) alt
    JOIN obras.obra o ON o.codigo = alt.atlas_id AND o.id_tenant = 38
    WHERE TRIM(alt.titulo) <> '';

    RAISE NOTICE 'Passo 2 concluído.';

    -- =========================================================================
    RAISE NOTICE 'Passo 3: Inserindo integrantes base...';

    INSERT INTO obras.obra_integrante (
        id_obra, id_pessoa, cod_territorio, cod_categoria,
        controlado, percentual_pr, percentual_mr, percentual_sr, percentual_base,
        coleta_pr, coleta_mr, coleta_sr,
        link, sequencia, criacao
    )
    WITH pares AS (
        SELECT
            e.atlas_id,
            e.chain_id  AS chain_id_editor,
            a.chain_id  AS chain_id_autor
        FROM mdb.sbacem e
        JOIN mdb.sbacem a ON a.atlas_id = e.atlas_id AND a.chain_id = e.chain
        WHERE e.chain IS NOT NULL
          AND e.ignorar IS DISTINCT FROM true
          AND a.ignorar IS DISTINCT FROM true
    ),
    links AS (
        SELECT
            atlas_id, chain_id_editor, chain_id_autor,
            ROW_NUMBER() OVER (PARTITION BY atlas_id ORDER BY chain_id_autor) AS numero_link
        FROM pares
    ),
    chain_link AS (
        SELECT atlas_id, chain_id_editor AS chain_id, numero_link FROM links
        UNION ALL
        SELECT atlas_id, chain_id_autor  AS chain_id, numero_link FROM links
    ),
    chain_com_link AS (
        SELECT DISTINCT atlas_id, chain_id FROM chain_link
    ),
    sem_par AS (
        SELECT
            s.atlas_id,
            s.chain_id,
            (SELECT COUNT(*) FROM links l WHERE l.atlas_id = s.atlas_id) +
            ROW_NUMBER() OVER (PARTITION BY s.atlas_id ORDER BY s.chain_id) AS numero_link
        FROM mdb.sbacem s
        WHERE s.ignorar IS DISTINCT FROM true
          AND NOT EXISTS (
              SELECT 1 FROM chain_com_link cl
              WHERE cl.atlas_id = s.atlas_id AND cl.chain_id = s.chain_id
          )
    ),
    todos_links AS (
        SELECT atlas_id, chain_id, numero_link FROM chain_link
        UNION ALL
        SELECT atlas_id, chain_id, numero_link FROM sem_par
    )
    SELECT
        o.id,
        p.id,
        '76',
        s.ip_role,
        CASE WHEN t.percentual IS NOT NULL THEN true ELSE false END,
        mdb.migracao_to_float(s.per_own),
        CASE
            WHEN t.percentual IS NOT NULL
            THEN GREATEST(0,
                mdb.migracao_to_float(s.mec_own)
                - LEAST(
                    mdb.migracao_to_float(s.mec_own),
                    mdb.migracao_to_float(REPLACE(t.percentual, '%', ''))
                )
            )
            ELSE mdb.migracao_to_float(s.mec_own)
        END,
        -- percentual_sr = espelho do percentual_mr
        CASE
            WHEN t.percentual IS NOT NULL
            THEN GREATEST(0,
                mdb.migracao_to_float(s.mec_own)
                - LEAST(
                    mdb.migracao_to_float(s.mec_own),
                    mdb.migracao_to_float(REPLACE(t.percentual, '%', ''))
                )
            )
            ELSE mdb.migracao_to_float(s.mec_own)
        END,
        mdb.migracao_to_float(s.per_own),
        -- coleta = espelho do percentual
        mdb.migracao_to_float(s.per_own),
        CASE
            WHEN t.percentual IS NOT NULL
            THEN GREATEST(0,
                mdb.migracao_to_float(s.mec_own)
                - LEAST(
                    mdb.migracao_to_float(s.mec_own),
                    mdb.migracao_to_float(REPLACE(t.percentual, '%', ''))
                )
            )
            ELSE mdb.migracao_to_float(s.mec_own)
        END,
        -- coleta_sr = espelho do coleta_mr
        CASE
            WHEN t.percentual IS NOT NULL
            THEN GREATEST(0,
                mdb.migracao_to_float(s.mec_own)
                - LEAST(
                    mdb.migracao_to_float(s.mec_own),
                    mdb.migracao_to_float(REPLACE(t.percentual, '%', ''))
                )
            )
            ELSE mdb.migracao_to_float(s.mec_own)
        END,
        tl.numero_link,
        ROW_NUMBER() OVER (PARTITION BY s.atlas_id ORDER BY tl.numero_link, s.chain_id),
        NOW()
    FROM mdb.sbacem s
    JOIN todos_links tl   ON tl.atlas_id = s.atlas_id AND tl.chain_id = s.chain_id
    JOIN obras.obra o     ON o.codigo = s.atlas_id AND o.id_tenant = 38
    JOIN pessoas.pessoa p ON p.ip_name = s.ipi_name_number AND p.id_tenant = 38
    LEFT JOIN LATERAL (
        SELECT percentual FROM mdb.titular WHERE ipi = s.ipi_base_number LIMIT 1
    ) t ON true
    WHERE s.ignorar IS DISTINCT FROM true;

    RAISE NOTICE 'Passo 3 concluído.';

    -- =========================================================================
    RAISE NOTICE 'Passo 4: Inserindo Musica 360...';

    INSERT INTO obras.obra_integrante (
        id_obra, id_pessoa, cod_territorio, cod_categoria,
        controlado, percentual_pr, percentual_mr, percentual_sr, percentual_base,
        coleta_pr, coleta_mr, coleta_sr,
        link, sequencia, criacao
    )
    SELECT
        oi.id_obra,
        2405890,
        '76',
        CASE
            WHEN EXISTS (
                SELECT 1 FROM obras.obra_integrante oi2
                WHERE oi2.id_obra = oi.id_obra
                  AND oi2.link = oi.link
                  AND oi2.cod_categoria = 'E'
                  AND oi2.id_pessoa <> 2405890
            ) THEN 'AM'
            ELSE 'E'
        END,
        true,
        0,
        LEAST(
            mdb.migracao_to_float(s.mec_own),
            mdb.migracao_to_float(REPLACE(t.percentual, '%', ''))
        ),
        0, 0,
        -- coleta = espelho do percentual (M360 tem pr=0, mr=cedido, sr=0)
        0,
        LEAST(
            mdb.migracao_to_float(s.mec_own),
            mdb.migracao_to_float(REPLACE(t.percentual, '%', ''))
        ),
        0,
        oi.link,
        oi.sequencia + 500,
        NOW()
    FROM (
        -- uma linha por (obra, link) onde há titular cedente — evita duplicatas do M360
        SELECT DISTINCT ON (oi.id_obra, oi.link)
            oi.id_obra, oi.link, oi.sequencia, p.ip_name, o.codigo
        FROM obras.obra_integrante oi
        JOIN obras.obra o     ON o.id = oi.id_obra AND o.id_tenant = 38
        JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
        WHERE oi.controlado = true
          AND oi.id_pessoa <> 2405890
        ORDER BY oi.id_obra, oi.link, oi.sequencia
    ) oi
    JOIN obras.obra o      ON o.id = oi.id_obra AND o.id_tenant = 38
    JOIN LATERAL (
        SELECT ipi_base_number, mec_own
        FROM mdb.sbacem
        WHERE ipi_name_number = oi.ip_name AND atlas_id = oi.codigo
          AND ignorar IS DISTINCT FROM true
        LIMIT 1
    ) s ON true
    JOIN LATERAL (
        SELECT percentual FROM mdb.titular WHERE ipi = s.ipi_base_number LIMIT 1
    ) t ON true;

    RAISE NOTICE 'Passo 4 concluído.';

    -- =========================================================================
    RAISE NOTICE 'Passo 5: Atualizando controlada e controle_mr...';

    UPDATE obras.obra o
    SET
        controlada  = true,
        controle_mr = sub.total_mr,
        controle_sr = sub.total_sr
    FROM (
        SELECT id_obra, SUM(percentual_mr) AS total_mr, SUM(percentual_sr) AS total_sr
        FROM obras.obra_integrante
        WHERE id_pessoa = 2405890
        GROUP BY id_obra
    ) sub
    WHERE o.id = sub.id_obra
      AND o.id_tenant = 38;

    RAISE NOTICE 'Passo 5 concluído. Carga finalizada!';

END;
$$;

-- Executar:
-- CALL mdb.carga_final_obras();
