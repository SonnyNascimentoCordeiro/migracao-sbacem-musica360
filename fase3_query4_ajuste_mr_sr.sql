-- Query 4 — Ajuste proporcional MR e SR
-- Titulares perdem X% de MR/SR, Musica 360 ganha esse mesmo valor por obra
-- Aplica mdb.titular (15%) e mdb.titular2 (percentuais específicos)
-- Tenant: 38 | Configuração: 61

BEGIN;

-- Captura os valores ANTES da redução para usar no ganho da Musica 360
CREATE TEMP TABLE perdas_titular AS
SELECT
    oi.id                                                               AS integrante_id,
    oi.id_obra,
    ROUND((oi.percentual_mr * (
        REPLACE(
            CASE WHEN t2.percentual IS NOT NULL THEN t2.percentual
                 ELSE t.percentual
            END, '%', '')::float / 100
    ))::numeric, 2)                                                     AS perda_mr,
    ROUND((oi.percentual_sr * (
        REPLACE(
            CASE WHEN t2.percentual IS NOT NULL THEN t2.percentual
                 ELSE t.percentual
            END, '%', '')::float / 100
    ))::numeric, 2)                                                     AS perda_sr
FROM obras.obra_integrante oi
JOIN obras.obra o     ON o.id = oi.id_obra
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
LEFT JOIN mdb.titular2 t2 ON t2.cae = t.cae
WHERE o.id_tenant      = 38
  AND o.id_configuracao = 61;

-- Reduz MR e SR dos titulares
UPDATE obras.obra_integrante oi
SET
    percentual_mr = oi.percentual_mr - pt.perda_mr,
    percentual_sr = oi.percentual_sr - pt.perda_sr
FROM perdas_titular pt
WHERE oi.id = pt.integrante_id;

-- Soma os ganhos por obra e repassa para a Musica 360
WITH ganhos AS (
    SELECT id_obra,
           SUM(perda_mr) AS ganho_mr,
           SUM(perda_sr) AS ganho_sr
    FROM perdas_titular
    GROUP BY id_obra
)
UPDATE obras.obra_integrante oi
SET
    percentual_mr = oi.percentual_mr + g.ganho_mr,
    percentual_sr = oi.percentual_sr + g.ganho_sr
FROM ganhos g
WHERE oi.id_obra   = g.id_obra
  AND oi.id_pessoa = 2405890;

DROP TABLE perdas_titular;

COMMIT;
