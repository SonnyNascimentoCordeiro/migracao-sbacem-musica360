-- =============================================================
-- Migração SBACEM → Woodstock — Fase 2: Titulares Administrados
-- Tenant: 38 | Configuração: 61 | Data: 2026-03-22
--
-- Objetivo: marcar titulares administrados (mdb.titular) como
-- controlados, atualizar link e percentuais.
--
-- Ordem de execução:
--   Query 1  — verificação: integrantes a atualizar
--   Query 2  — verificação: obras a controlar
--   Query 3  — UPDATE obra_integrante (titulares: controlado, link, percentuais)
--   Query 4  — UPDATE obras.obra (controlada = true)
--   Query 5  — UPDATE obra_integrante (não-titulares: ajuste proporcional para 100%)
--   Query 6  — verificação: integrantes controlados vs não controlados
--   Query 7  — verificação: obras controladas vs não controladas
--   Query 8  — verificação: amostra de titulares após update
-- =============================================================


-- -------------------------------------------------------------
-- Query 1 — Verificação prévia: integrantes a atualizar
-- -------------------------------------------------------------
SELECT COUNT(*) AS integrantes_a_atualizar
FROM obras.obra_integrante oi
JOIN obras.obra o     ON o.id = oi.id_obra
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;


-- -------------------------------------------------------------
-- Query 2 — Verificação prévia: obras a marcar como controladas
-- -------------------------------------------------------------
SELECT COUNT(DISTINCT o.id) AS obras_a_controlar
FROM obras.obra o
JOIN obras.obra_integrante oi ON oi.id_obra = o.id
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;


-- -------------------------------------------------------------
-- Query 3 — UPDATE obra_integrante: titulares administrados
-- Atualiza controlado, link e percentuais fixos de mdb.titular
-- -------------------------------------------------------------
BEGIN;

WITH m360_links AS (
    SELECT id_obra, link AS m360_link
    FROM obras.obra_integrante
    WHERE id_pessoa = 2405890
),
titular_pct AS (
    SELECT t.cae,
           REPLACE(
               CASE WHEN t2.percentual IS NOT NULL THEN t2.percentual
                    ELSE t.percentual
               END, '%', '')::float AS pct
    FROM mdb.titular t
    LEFT JOIN mdb.titular2 t2 ON t2.cae = t.cae
),
titulares AS (
    SELECT
        oi.id,
        COALESCE(ml.m360_link, oi.link) AS novo_link,
        tp.pct
    FROM obras.obra_integrante oi
    JOIN obras.obra o        ON o.id = oi.id_obra
    JOIN pessoas.pessoa p    ON p.id = oi.id_pessoa AND p.id_tenant = 38
    JOIN titular_pct tp      ON tp.cae = p.codigo
    LEFT JOIN m360_links ml  ON ml.id_obra = oi.id_obra
    WHERE o.id_tenant = 38
      AND o.id_configuracao = 61
)
UPDATE obras.obra_integrante oi
SET
    controlado      = true,
    link            = t.novo_link,
    percentual_pr   = t.pct,
    percentual_mr   = t.pct,
    percentual_sr   = t.pct,
    percentual_base = t.pct
FROM titulares t
WHERE oi.id = t.id;

COMMIT;


-- -------------------------------------------------------------
-- Query 4 — UPDATE obras.obra: marcar controlada = true
-- Toda obra que tiver ao menos um titular administrado
-- -------------------------------------------------------------
BEGIN;

UPDATE obras.obra o
SET controlada = true
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61
  AND EXISTS (
      SELECT 1
      FROM obras.obra_integrante oi
      JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
      JOIN mdb.titular t    ON t.cae = p.codigo
      WHERE oi.id_obra = o.id
  );

COMMIT;


-- -------------------------------------------------------------
-- Query 5 — UPDATE obra_integrante: ajuste proporcional dos não-titulares
-- Redistribui o restante (100 - soma titulares) proporcionalmente
-- entre os participantes que NÃO são titulares administrados
-- -------------------------------------------------------------
BEGIN;

WITH titular_sums AS (
    SELECT
        oi.id_obra,
        ROUND(SUM(oi.percentual_pr)::numeric,   4) AS sum_pr,
        ROUND(SUM(oi.percentual_mr)::numeric,   4) AS sum_mr,
        ROUND(SUM(oi.percentual_sr)::numeric,   4) AS sum_sr,
        ROUND(SUM(oi.percentual_base)::numeric, 4) AS sum_base
    FROM obras.obra_integrante oi
    JOIN obras.obra o     ON o.id = oi.id_obra
    JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
    JOIN mdb.titular t    ON t.cae = p.codigo
    WHERE o.id_tenant = 38
      AND o.id_configuracao = 61
    GROUP BY oi.id_obra
),
non_titular_sums AS (
    SELECT
        oi.id_obra,
        ROUND(SUM(oi.percentual_pr)::numeric,   4) AS sum_pr,
        ROUND(SUM(oi.percentual_mr)::numeric,   4) AS sum_mr,
        ROUND(SUM(oi.percentual_sr)::numeric,   4) AS sum_sr,
        ROUND(SUM(oi.percentual_base)::numeric, 4) AS sum_base
    FROM obras.obra_integrante oi
    JOIN obras.obra o     ON o.id = oi.id_obra
    JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
    WHERE o.id_tenant = 38
      AND o.id_configuracao = 61
      AND NOT EXISTS (SELECT 1 FROM mdb.titular t WHERE t.cae = p.codigo)
    GROUP BY oi.id_obra
),
ajustes AS (
    SELECT
        oi.id,
        CASE WHEN nts.sum_pr   > 0
             THEN ROUND((oi.percentual_pr   / nts.sum_pr   * GREATEST(0, 100 - ts.sum_pr))::numeric,   2)
             ELSE oi.percentual_pr   END AS new_pr,
        CASE WHEN nts.sum_mr   > 0
             THEN ROUND((oi.percentual_mr   / nts.sum_mr   * GREATEST(0, 100 - ts.sum_mr))::numeric,   2)
             ELSE oi.percentual_mr   END AS new_mr,
        CASE WHEN nts.sum_sr   > 0
             THEN ROUND((oi.percentual_sr   / nts.sum_sr   * GREATEST(0, 100 - ts.sum_sr))::numeric,   2)
             ELSE oi.percentual_sr   END AS new_sr,
        CASE WHEN nts.sum_base > 0
             THEN ROUND((oi.percentual_base / nts.sum_base * GREATEST(0, 100 - ts.sum_base))::numeric, 2)
             ELSE oi.percentual_base END AS new_base
    FROM obras.obra_integrante oi
    JOIN obras.obra o         ON o.id = oi.id_obra
    JOIN pessoas.pessoa p     ON p.id = oi.id_pessoa AND p.id_tenant = 38
    JOIN titular_sums ts      ON ts.id_obra = oi.id_obra
    JOIN non_titular_sums nts ON nts.id_obra = oi.id_obra
    WHERE o.id_tenant = 38
      AND o.id_configuracao = 61
      AND NOT EXISTS (SELECT 1 FROM mdb.titular t WHERE t.cae = p.codigo)
)
UPDATE obras.obra_integrante oi
SET
    percentual_pr   = a.new_pr,
    percentual_mr   = a.new_mr,
    percentual_sr   = a.new_sr,
    percentual_base = a.new_base
FROM ajustes a
WHERE oi.id = a.id;

COMMIT;


-- -------------------------------------------------------------
-- Query 6 — Verificação: integrantes controlados vs não controlados
-- -------------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE oi.controlado = true)  AS integrantes_controlados,
    COUNT(*) FILTER (WHERE oi.controlado = false) AS integrantes_nao_controlados
FROM obras.obra_integrante oi
JOIN obras.obra o ON o.id = oi.id_obra
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;


-- -------------------------------------------------------------
-- Query 7 — Verificação: obras controladas vs não controladas
-- -------------------------------------------------------------
SELECT
    COUNT(*) FILTER (WHERE controlada = true)  AS obras_controladas,
    COUNT(*) FILTER (WHERE controlada = false) AS obras_nao_controladas
FROM obras.obra
WHERE id_tenant = 38
  AND id_configuracao = 61;


-- -------------------------------------------------------------
-- Query 8 — Verificação: amostra de titulares após update
-- -------------------------------------------------------------
SELECT p.nome, p.codigo, oi.cod_categoria, oi.controlado,
       oi.link, oi.percentual_pr, oi.percentual_mr, oi.percentual_sr, oi.percentual_base
FROM obras.obra_integrante oi
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
JOIN obras.obra o     ON o.id = oi.id_obra
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61
LIMIT 20;
