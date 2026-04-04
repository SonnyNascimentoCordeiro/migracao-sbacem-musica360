-- Query 4 — UPDATE obras.obra: marcar controlada = true
-- Toda obra que tiver ao menos um titular administrado
-- Tenant: 38 | Configuração: 61

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
