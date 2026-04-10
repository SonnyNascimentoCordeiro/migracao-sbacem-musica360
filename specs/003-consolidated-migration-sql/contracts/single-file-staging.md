# Contract: execução do arquivo único de staging

## Entrada

| Requisito | Obrigatório |
|-----------|-------------|
| Banco com `mdb.sbacem` populada | sim |
| `mdb.titular` e `mdb.titular2` existentes (podem estar vazias) | sim |
| Permissões DDL/DML em `migracao_stg` | sim |

## Saída (invariantes)

1. Após sucesso, `migracao_stg.sbacem_import_staging` tem **≥1** linha se a fonte tem dados.
2. Para obras com pares `chain` válidos, `numero_link` **não** permanece `NULL` em todas as linhas da obra.
3. **Nenhuma** linha em `obras.*` ou `pessoas.*` é `DELETE` por este script.

## Erros

- Falha de permissão, objeto ausente (`mdb.sbacem`), ou tipo inválido em `titular.percentual` → execução interrompida (`ON_ERROR_STOP=1` no psql).

## Comando

```text
psql -h HOST -p PORT -U USER -d DB -v ON_ERROR_STOP=1 -f migracao_staging_um_arquivo.sql
```
