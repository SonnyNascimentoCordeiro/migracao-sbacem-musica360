-- =============================================================================
-- Remoção de obras SBACEM (tenant 38, configuração 61 — M360)
-- =============================================================================
-- Rollback por fases (integrantes / de_para / pessoas) quando existir carga
-- completa via pipeline: ver `scripts/migracao/rollback/rollback_fase_import.sql`
-- e `scripts/migracao/README.md`.
-- =============================================================================
-- Com CASCADE nas filhas de obras.obra, em ambiente ainda sem vínculos em
-- tabelas com ON DELETE RESTRICT (autorizações, catálogo, distribuição,
-- fonogramas, etc.), basta o DELETE abaixo.
--
-- Se o PostgreSQL retornar erro de violação de FK, aí será preciso apagar
-- ou atualizar manualmente a tabela apontada na mensagem de erro antes da obra.
--
-- Não remove pessoas — ver scripts/02_reimportacao_completa.sql se precisar.
-- =============================================================================

BEGIN;

DELETE FROM obras.obra o
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61;

COMMIT;
