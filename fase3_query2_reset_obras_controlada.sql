-- Query 2 — Reset obra.controlada
-- Zera o flag controlada em todas as obras do tenant
-- Tenant: 38 | Configuração: 61

BEGIN;

UPDATE obras.obra
SET controlada = false
WHERE id_tenant      = 38
  AND id_configuracao = 61;

COMMIT;
