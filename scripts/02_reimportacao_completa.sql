-- =============================================================================
-- REIMPORTAÇÃO COMPLETA DO CATÁLOGO SBACEM → WOODSTOCK (Tenant 38 - M360)
-- Data: 2026-03-22
-- Referência: docs/plans/2026-03-22_002_reimportacao-completa-sbacem.md
-- =============================================================================
-- ATENÇÃO: Executar em uma transação. Revisar antes de commitar.
-- psql -h <host> -U backstage -d woodstock -f 02_reimportacao_completa.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- FASE 1 — LIMPEZA (preserva MUSICA 360, id=2405890)
-- =============================================================================

-- 1.1 Remover de-para de obras
DELETE FROM obras.obra_de_para
WHERE id_obra IN (SELECT id FROM obras.obra WHERE id_tenant = 38);

-- 1.2 Remover títulos alternativos
DELETE FROM obras.obra_titulo
WHERE id_obra IN (SELECT id FROM obras.obra WHERE id_tenant = 38);

-- 1.3 Remover integrantes
DELETE FROM obras.obra_integrante
WHERE id_obra IN (SELECT id FROM obras.obra WHERE id_tenant = 38);

-- 1.4 Remover obras
DELETE FROM obras.obra WHERE id_tenant = 38;

-- 1.5 Remover de-para de pessoas (exceto MUSICA 360)
DELETE FROM pessoas.pessoa_de_para
WHERE id_pessoa IN (
    SELECT id FROM pessoas.pessoa WHERE id_tenant = 38 AND id != 2405890
);

-- 1.6 Remover pessoas importadas (exceto MUSICA 360)
DELETE FROM pessoas.pessoa
WHERE id_tenant = 38
AND id != 2405890
AND importado = true;

-- =============================================================================
-- FASE 2 — PESSOAS
-- Deduplica por ipi_name_number. Código = ipi_name_number.
-- tipo: J se role in (E, ES, AM, PA, SE, AQ), F caso contrário.
-- autor: true se role in (CA, C, A, AR, SA, AD, TR)
-- editor: true se role in (E, ES, AM, PA, SE, AQ)
-- =============================================================================

INSERT INTO pessoas.pessoa (
    id_tenant, codigo, nome, tipo, autor, editor,
    ip_name, ip_base, ativo, importado, excluido
)
SELECT DISTINCT ON (s.ipi_name_number)
    38,
    s.ipi_name_number,
    UPPER(s.ip_name),
    CASE WHEN bool_or(s.ip_role IN ('E','ES','AM','PA','SE','AQ')) OVER (PARTITION BY s.ipi_name_number)
              AND NOT bool_or(s.ip_role IN ('CA','C','A','AR','SA','AD','TR')) OVER (PARTITION BY s.ipi_name_number)
         THEN 'J' ELSE 'F' END,
    bool_or(s.ip_role IN ('CA','C','A','AR','SA','AD','TR')) OVER (PARTITION BY s.ipi_name_number),
    bool_or(s.ip_role IN ('E','ES','AM','PA','SE','AQ')) OVER (PARTITION BY s.ipi_name_number),
    s.ipi_name_number,
    s.ipi_base_number,
    true,
    true,
    false
FROM mdb.sbacem s
WHERE s.ipi_name_number IS NOT NULL
  AND s.ipi_name_number != ''
ORDER BY s.ipi_name_number, s.ip_name;

-- De-para pessoas (ipi_name_number → id da pessoa recém inserida)
INSERT INTO pessoas.pessoa_de_para (id_pessoa, id_parceiro, codigo)
SELECT p.id, 128, p.ip_name
FROM pessoas.pessoa p
WHERE p.id_tenant = 38
  AND p.importado = true
  AND p.id != 2405890;

-- =============================================================================
-- FASE 3 — OBRAS
-- Código sequencial a partir de 1.
-- =============================================================================

-- codigo da obra = atlas_id (simplifica todas as fases seguintes)
INSERT INTO obras.obra (
    id_tenant, id_configuracao, codigo, titulo, iswc,
    situacao, cod_tipo_versao, cancelada, retida, gravada,
    instrumental, importado, nacional, registro, controle_pr, controle_mr, controle_sr, criacao
)
WITH controles AS (
    SELECT
        s.atlas_id,
        COALESCE(SUM(
            REPLACE(s.per_own, ',', '.')::float
            * REPLACE(t.percentual, '%', '')::float / 100.0
        ), 0) AS controle_mr
    FROM mdb.sbacem s
    JOIN mdb.titular t ON t.cae = s.ipi_name_number AND t.percentual ~ '^[0-9]+%$'
    WHERE s.ip_role IN ('CA','C','A','AR','SA','AD','TR')
    GROUP BY s.atlas_id
)
SELECT DISTINCT ON (s.atlas_id)
    38,
    61,
    s.atlas_id,
    s.original_title,
    NULLIF(TRIM(s.iswc), ''),
    'L',
    'ORI',
    false,
    false,
    false,
    false,
    true,
    true,
    CURRENT_DATE,
    0,
    COALESCE(c.controle_mr, 0),
    COALESCE(c.controle_mr, 0),
    NOW()
FROM mdb.sbacem s
LEFT JOIN controles c ON c.atlas_id = s.atlas_id
ORDER BY s.atlas_id;

-- De-para obras (referência cruzada para uso futuro)
INSERT INTO obras.obra_de_para (id_obra, id_parceiro, codigo)
SELECT o.id, 128, o.codigo
FROM obras.obra o
WHERE o.id_tenant = 38;

-- =============================================================================
-- FASE 4 — TÍTULOS ALTERNATIVOS
-- =============================================================================

INSERT INTO obras.obra_titulo (id_obra, titulo, cod_tipo_titulo, ativo, criacao)
SELECT DISTINCT
    o.id,
    TRIM(alt.titulo),
    'AT',
    true,
    NOW()
FROM obras.obra o
JOIN mdb.sbacem s ON s.atlas_id = o.codigo
JOIN LATERAL unnest(string_to_array(s.alternate_titles, '|')) AS alt(titulo) ON true
WHERE o.id_tenant = 38
  AND TRIM(alt.titulo) != ''
  AND TRIM(alt.titulo) != s.original_title;

-- =============================================================================
-- FASE 5 — INTEGRANTES (autores e editoras da fonte, exceto MUSICA 360)
-- =============================================================================

-- link=1: autores controlados (têm a MUSICA 360 como editora)
-- link=N: autores não controlados (cada um com link próprio, sequencial a partir de 2)
INSERT INTO obras.obra_integrante (
    id_obra, id_pessoa, cod_categoria, controlado,
    percentual_pr, percentual_mr, percentual_sr,
    link, cod_territorio, sequencia, criacao
)
SELECT
    o.id,
    p.id,
    s.ip_role,
    (t.cae IS NOT NULL),
    REPLACE(s.per_own, ',', '.')::float,
    CASE WHEN t.cae IS NOT NULL
         THEN REPLACE(s.per_own, ',', '.')::float * (1 - REPLACE(t.percentual, '%', '')::float / 100.0)
         ELSE REPLACE(s.per_own, ',', '.')::float
    END,
    CASE WHEN t.cae IS NOT NULL
         THEN REPLACE(s.per_own, ',', '.')::float * (1 - REPLACE(t.percentual, '%', '')::float / 100.0)
         ELSE REPLACE(s.per_own, ',', '.')::float
    END,
    -- link=1 se controlado, senão link sequencial a partir de 2
    CASE WHEN t.cae IS NOT NULL THEN 1
         ELSE 1 + ROW_NUMBER() OVER (
             PARTITION BY o.id, (t.cae IS NOT NULL)
             ORDER BY s.ipi_name_number
         )
    END,
    '76',  -- Brasil
    ROW_NUMBER() OVER (PARTITION BY o.id ORDER BY (t.cae IS NOT NULL) DESC, s.ipi_name_number),
    NOW()
FROM mdb.sbacem s
JOIN obras.obra o ON o.codigo = s.atlas_id AND o.id_tenant = 38
JOIN pessoas.pessoa p ON p.ip_name = s.ipi_name_number AND p.id_tenant = 38
LEFT JOIN mdb.titular t ON t.cae = s.ipi_name_number AND t.percentual ~ '^[0-9]+%$'
WHERE s.ip_role NOT IN ('E','ES','AM','PA','SE','AQ');

-- =============================================================================
-- FASE 6 — MUSICA 360 em todas as obras
-- E: quando não há editora (E, ES, SE) na obra
-- AM: quando há outra editora
-- PR: sempre 0
-- MR/SR: soma dos percentuais cedidos pelos autores controlados
-- =============================================================================

-- 6a. Uma entrada da MUSICA 360 por autor controlado, com o mesmo link do autor
INSERT INTO obras.obra_integrante (
    id_obra, id_pessoa, cod_categoria, controlado,
    percentual_pr, percentual_mr, percentual_sr,
    link, cod_territorio, sequencia, criacao
)
SELECT
    oi_autor.id_obra,
    2405890,
    CASE WHEN EXISTS (
        SELECT 1 FROM obras.obra_integrante oi2
        WHERE oi2.id_obra = oi_autor.id_obra
          AND oi2.cod_categoria IN ('E','ES','SE')
    ) THEN 'AM' ELSE 'E' END,
    true,
    0,
    oi_autor.percentual_pr * (REPLACE(t.percentual, '%', '')::float / 100.0),
    oi_autor.percentual_pr * (REPLACE(t.percentual, '%', '')::float / 100.0),
    oi_autor.link,
    '76',
    (SELECT COALESCE(MAX(oi3.sequencia), 0) + 1
     FROM obras.obra_integrante oi3 WHERE oi3.id_obra = oi_autor.id_obra),
    NOW()
FROM obras.obra_integrante oi_autor
JOIN obras.obra o ON o.id = oi_autor.id_obra AND o.id_tenant = 38
JOIN pessoas.pessoa p ON p.id = oi_autor.id_pessoa
JOIN mdb.titular t ON t.cae = p.ip_name AND t.percentual ~ '^[0-9]+%$'
WHERE oi_autor.controlado = true
  AND oi_autor.id_pessoa != 2405890;

-- 6b. Obras sem nenhum autor controlado: MUSICA 360 entra com 0% em tudo
--     (garante que toda obra tenha a editora)
INSERT INTO obras.obra_integrante (
    id_obra, id_pessoa, cod_categoria, controlado,
    percentual_pr, percentual_mr, percentual_sr,
    link, cod_territorio, sequencia, criacao
)
SELECT
    o.id,
    2405890,
    CASE WHEN EXISTS (
        SELECT 1 FROM obras.obra_integrante oi2
        WHERE oi2.id_obra = o.id
          AND oi2.cod_categoria IN ('E','ES','SE')
    ) THEN 'AM' ELSE 'E' END,
    true,
    0, 0, 0,
    1,  -- link padrão
    '76',
    (SELECT COALESCE(MAX(oi3.sequencia), 0) + 1
     FROM obras.obra_integrante oi3 WHERE oi3.id_obra = o.id),
    NOW()
FROM obras.obra o
WHERE o.id_tenant = 38
  AND NOT EXISTS (
      SELECT 1 FROM obras.obra_integrante oi4
      WHERE oi4.id_obra = o.id AND oi4.id_pessoa = 2405890
  );

-- =============================================================================
-- VERIFICAÇÃO RÁPIDA (não remove, apenas exibe)
-- =============================================================================

SELECT 'obras' as entidade, COUNT(*) as total FROM obras.obra WHERE id_tenant = 38
UNION ALL
SELECT 'pessoas', COUNT(*) FROM pessoas.pessoa WHERE id_tenant = 38
UNION ALL
SELECT 'integrantes', COUNT(*) FROM obras.obra_integrante oi
    JOIN obras.obra o ON o.id = oi.id_obra WHERE o.id_tenant = 38
UNION ALL
SELECT 'obras_sem_musica360', COUNT(*) FROM obras.obra o WHERE o.id_tenant = 38
    AND NOT EXISTS (SELECT 1 FROM obras.obra_integrante oi WHERE oi.id_obra = o.id AND oi.id_pessoa = 2405890)
UNION ALL
SELECT 'obras_musica360_como_E', COUNT(DISTINCT oi.id_obra) FROM obras.obra_integrante oi
    JOIN obras.obra o ON o.id = oi.id_obra
    WHERE o.id_tenant = 38 AND oi.id_pessoa = 2405890 AND oi.cod_categoria = 'E'
UNION ALL
SELECT 'obras_musica360_como_AM', COUNT(DISTINCT oi.id_obra) FROM obras.obra_integrante oi
    JOIN obras.obra o ON o.id = oi.id_obra
    WHERE o.id_tenant = 38 AND oi.id_pessoa = 2405890 AND oi.cod_categoria = 'AM'
UNION ALL
SELECT 'entradas_musica360_total', COUNT(*) FROM obras.obra_integrante oi
    JOIN obras.obra o ON o.id = oi.id_obra
    WHERE o.id_tenant = 38 AND oi.id_pessoa = 2405890;

-- =============================================================================
-- ATENÇÃO: O script para aqui dentro da transação.
-- Verifique os resultados acima antes de decidir.
--
-- Para confirmar:  COMMIT;
-- Para desfazer:   ROLLBACK;
-- =============================================================================
