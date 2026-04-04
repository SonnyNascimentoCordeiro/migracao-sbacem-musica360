-- Query 1 — Verificação prévia: integrantes a atualizar
-- Tenant: 38 | Configuração: 61

SELECT COUNT(*) AS integrantes_a_atualizar
FROM obras.obra_integrante oi
JOIN obras.obra o     ON o.id = oi.id_obra
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;
