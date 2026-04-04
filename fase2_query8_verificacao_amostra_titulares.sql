-- Query 8 — Verificação: amostra de titulares após update
-- Tenant: 38 | Configuração: 61

SELECT p.nome, p.codigo, oi.cod_categoria, oi.controlado,
       oi.link, oi.percentual_pr, oi.percentual_mr, oi.percentual_sr, oi.percentual_base
FROM obras.obra_integrante oi
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
JOIN mdb.titular t    ON t.cae = p.codigo
JOIN obras.obra o     ON o.id = oi.id_obra
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61
LIMIT 20;
