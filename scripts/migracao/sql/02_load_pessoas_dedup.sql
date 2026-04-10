-- T009: Esqueleto — deduplicar pessoas por ipi_name_number no tenant 38.
-- AJUSTAR nomes de colunas (pessoas.pessoa) ao DDL real antes de executar.
--
-- Pseudocódigo:
-- 1) SELECT DISTINCT ipi_name_number, MAX(ip_name), agregar autor/editor por IPI a partir do staging.
-- 2) INSERT INTO pessoas.pessoa (id_tenant=38, nome=UPPER(...), ip_name=IPI, importado=true, ...)
-- 3) codigo: próximo livre por tenant (sequência ou MAX+1).

SELECT 'TODO: revisar DDL pessoas.pessoa, sequência de codigo e ON CONFLICT; popular a partir do DISTINCT ipi_name_number do staging.' AS status;
