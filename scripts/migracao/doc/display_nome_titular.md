# Exibição do nome do titular na linha editorial (FR-005)

O staging calcula `ref_titular_nome` em `sql/06_staging_titular_nome.sql` (JOIN `chain` = `chain_id` do titular na mesma obra).

## Destino Woodstock

- Se `obras.obra_integrante` possuir coluna de **observação**, **descrição** ou metadado de UI, gravar `ref_titular_nome` nela na carga (`04_load_integrantes_sbacem_base.sql`).
- Caso contrário, manter apenas no **staging** e expor via view de leitura ou enriquecimento na API — decisão de produto.

## Formato sugerido para telas

`BOCA DO ORIENTE — edita «{ref_titular_nome}»`
