-- Query 1 — Reset obra_integrante
-- Restaura percentuais originais do mdb.sbacem
-- PR=0 para Musica 360, controlado=false para todos exceto Musica 360
-- Tenant: 38 | Configuração: 61

BEGIN;

WITH sbacem_pct AS (
    SELECT DISTINCT ON (o.id, COALESCE(p.id, 2405890), s.ip_role)
        o.id                                                    AS id_obra,
        COALESCE(p.id, 2405890)                                 AS id_pessoa,
        s.ip_role,
        ROUND(REPLACE(s.per_own,  ',', '.')::numeric, 2)       AS per_own,
        ROUND(REPLACE(s.mec_own,  ',', '.')::numeric, 2)       AS mec_own
    FROM mdb.sbacem s
    JOIN obras.obra o  ON o.codigo = s.atlas_id
                      AND o.id_tenant = 38
                      AND o.id_configuracao = 61
    LEFT JOIN pessoas.pessoa p ON p.codigo = s.ipi_name_number
                               AND p.id_tenant = 38
    WHERE s.ipi_name_number IS NOT NULL
      AND s.ipi_name_number <> ''
      AND (s.ignorar IS NULL OR s.ignorar = false)
)
UPDATE obras.obra_integrante oi
SET
    percentual_pr   = CASE WHEN oi.id_pessoa = 2405890 THEN 0
                           ELSE sv.per_own END,
    percentual_mr   = sv.mec_own,
    percentual_sr   = sv.per_own,
    percentual_base = sv.per_own,
    controlado      = (oi.id_pessoa = 2405890)
FROM sbacem_pct sv
WHERE oi.id_obra       = sv.id_obra
  AND oi.id_pessoa     = sv.id_pessoa
  AND oi.cod_categoria = sv.ip_role;

COMMIT;
