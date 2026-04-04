-- Query 7 — Verificação: obras controladas vs não controladas
-- Tenant: 38 | Configuração: 61

SELECT
    COUNT(*) FILTER (WHERE controlada = true)  AS obras_controladas,
    COUNT(*) FILTER (WHERE controlada = false) AS obras_nao_controladas
FROM obras.obra
WHERE id_tenant = 38
  AND id_configuracao = 61;
