-- Query 5 — Marcar controlado=true nos titulares administrados
-- Tenant: 38 | Configuração: 61

BEGIN;

WITH titulares AS (
    SELECT oi.id
    FROM obras.obra_integrante oi
    JOIN obras.obra o     ON o.id = oi.id_obra
    JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
    JOIN mdb.titular t    ON t.cae = p.codigo
    WHERE o.id_tenant      = 38
      AND o.id_configuracao = 61
)
UPDATE obras.obra_integrante oi
SET controlado = true
FROM titulares t
WHERE oi.id = t.id;

COMMIT;
