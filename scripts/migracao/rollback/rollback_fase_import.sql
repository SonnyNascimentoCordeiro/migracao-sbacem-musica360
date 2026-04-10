-- T025: Rollback por fase (COMENTADO — revisar FKs antes de executar).
-- Alinhado à constituição: reversão explícita, sem CASCADE implícito em produção sem análise.

/*
BEGIN;

-- Fase M360 + integrantes
-- DELETE FROM obras.obra_integrante oi
-- USING obras.obra o
-- WHERE oi.id_obra = o.id AND o.id_tenant = 38 AND o.importado = TRUE;

-- Obras importadas
-- DELETE FROM obras.obra o
-- WHERE o.id_tenant = 38 AND o.id_configuracao = 61 AND o.importado = TRUE;

-- Pessoas importadas (cuidado: compartilhamento com outras obras)
-- DELETE FROM pessoas.pessoa p
-- WHERE p.id_tenant = 38 AND p.importado = TRUE;

-- De/para
-- DELETE FROM obras.obra_de_para WHERE ...;
-- DELETE FROM pessoas.pessoa_de_para WHERE ...;

COMMIT;
*/

SELECT 'TODO: descomentar e ajustar predicados (importado, intervalo de id, lote).' AS status;
