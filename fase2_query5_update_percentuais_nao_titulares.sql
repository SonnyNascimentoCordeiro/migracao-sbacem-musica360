-- Query 5 — UPDATE obra_integrante: ajuste proporcional dos não-titulares
-- Redistribui o restante (100 - soma titulares) proporcionalmente
-- entre os participantes que NÃO são titulares administrados
-- Tenant: 38 | Configuração: 61

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
