-- T004: Verificar se existe coluna para persistir o link numérico (spec 002 / research.md).
-- Sugestão de nome: numero_link (integer). Ajustar o nome na cláusula WHERE se o time padronizar outro.

SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type
FROM information_schema.columns c
WHERE c.table_schema = 'obras'
  AND c.table_name = 'obra_integrante'
  AND c.column_name IN ('numero_link', 'link', 'nr_link', 'cod_link');

-- Se o resultado for vazio, abrir alteração de DDL antes da carga que depende de link persistido.
-- ALTER TABLE obras.obra_integrante ADD COLUMN numero_link INTEGER NULL;
