-- T022: Obra controlada + controle_mr = soma MR das linhas M360 (spec 001).

/*
UPDATE obras.obra o
SET
    controlada = TRUE,
    controle_mr = sub.tot_mr
FROM (
    SELECT
        oi.id_obra,
        SUM(oi.percentual_mr) AS tot_mr
    FROM obras.obra_integrante oi
    JOIN pessoas.pessoa p ON p.id = oi.id_pessoa
    WHERE p.id_tenant = 38
      AND p.id = :id_pessoa_m360::BIGINT
    GROUP BY oi.id_obra
) sub
WHERE o.id = sub.id_obra
  AND o.id_tenant = 38;
*/

SELECT 'TODO: descomentar; usar id da Música 360 (tenant 38) e colunas reais de controle_mr/controlada.' AS status;
