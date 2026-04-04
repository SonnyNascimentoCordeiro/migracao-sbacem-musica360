-- Query 3 — INSERT Musica 360 nas obras que não a têm
-- Somente obras que possuem ao menos um titular de mdb.titular
-- Tenant: 38 | Configuração: 61

BEGIN;

INSERT INTO obras.obra_integrante (
    id_obra, id_pessoa,
    link, cod_territorio,
    cod_categoria, controlado,
    percentual_pr, percentual_mr, percentual_sr, percentual_base,
    sequencia, criacao
)
SELECT
    o.id,
    2405890,
    (SELECT COALESCE(MAX(oi2.link),      0) + 1 FROM obras.obra_integrante oi2 WHERE oi2.id_obra = o.id),
    76,
    'AM',
    true,
    0, 0, 0, 0,
    (SELECT COALESCE(MAX(oi2.sequencia), 0) + 1 FROM obras.obra_integrante oi2 WHERE oi2.id_obra = o.id),
    now()
FROM obras.obra o
WHERE o.id_tenant       = 38
  AND o.id_configuracao = 61
  AND EXISTS (
      SELECT 1
      FROM obras.obra_integrante oi
      JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
      JOIN mdb.titular t    ON t.cae = p.codigo
      WHERE oi.id_obra = o.id
  )
  AND NOT EXISTS (
      SELECT 1
      FROM obras.obra_integrante oi
      WHERE oi.id_obra   = o.id
        AND oi.id_pessoa = 2405890
  );

COMMIT;
