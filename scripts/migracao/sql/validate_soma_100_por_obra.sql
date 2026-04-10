-- T024: Obras com soma PR/MR/SR diferente de 100 (±0.02 tolerância opcional).
-- Executar **após** carga completa incluindo linhas M360 em obras.obra_integrante.

/*
WITH agg AS (
    SELECT
        o.codigo,
        o.id,
        SUM(oi.percentual_pr) AS s_pr,
        SUM(oi.percentual_mr) AS s_mr,
        SUM(oi.percentual_sr) AS s_sr
    FROM obras.obra o
    JOIN obras.obra_integrante oi ON oi.id_obra = o.id
    WHERE o.id_tenant = 38
    GROUP BY o.id, o.codigo
)
SELECT *
FROM agg
WHERE ABS(s_pr - 100) > 0.02
   OR ABS(s_mr - 100) > 0.02
   OR ABS(s_sr - 100) > 0.02;
*/

SELECT 'TODO: descomentar após confirmar nomes de colunas percentual_* e política de tolerância.' AS status;
