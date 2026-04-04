-- Query 3 — UPDATE obra_integrante: titulares administrados
-- Atualiza controlado, link e percentuais fixos de mdb.titular
-- Tenant: 38 | Configuração: 61

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
