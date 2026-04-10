-- T027: Contagem atlas_id distintos: mdb.sbacem vs obras.obra (tenant 38, config 61).

SELECT 'fonte' AS lado, COUNT(DISTINCT atlas_id) AS obras_distintas
FROM mdb.sbacem

UNION ALL

SELECT 'destino' AS lado, COUNT(*) AS obras_distintas
FROM obras.obra
WHERE id_tenant = 38
  AND id_configuracao = 61;
