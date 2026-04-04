-- Query 6 — Verificação: integrantes controlados vs não controlados
-- Tenant: 38 | Configuração: 61

SELECT
    COUNT(*) FILTER (WHERE oi.controlado = true)  AS integrantes_controlados,
    COUNT(*) FILTER (WHERE oi.controlado = false) AS integrantes_nao_controlados
FROM obras.obra_integrante oi
JOIN obras.obra o ON o.id = oi.id_obra
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;
