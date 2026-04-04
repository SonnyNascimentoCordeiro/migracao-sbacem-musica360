-- Query 2 — Verificação prévia: obras a marcar como controladas
-- Tenant: 38 | Configuração: 61

SELECT COUNT(DISTINCT o.id) AS obras_a_controlar
FROM obras.obra o
JOIN obras.obra_integrante oi ON oi.id_obra = o.id
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;
