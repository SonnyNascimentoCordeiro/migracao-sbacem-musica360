# Quickstart — arquivo único `migracao_staging_um_arquivo.sql`

## 1. Conferir pré-requisitos

- PostgreSQL acessível; banco `woodstock` (ou outro) com schema `mdb` e tabela `mdb.sbacem` com dados.
- Usuário com permissão para `CREATE SCHEMA`, `CREATE TABLE`, `CREATE VIEW`, `TRUNCATE`, `UPDATE` em `migracao_stg`.

## 2. Executar

```powershell
cd c:\Users\Gumercindo\IdeaProjects\migracao_reoertorio_sbacem\scripts\migracao
$env:PGPASSWORD = "senha"
psql -h SEU_HOST -p 5432 -U backstage -d woodstock -v ON_ERROR_STOP=1 -f migracao_staging_um_arquivo.sql
```

DBeaver: abrir o arquivo → executar como script completo.

## 3. Verificar (exemplos)

```sql
SELECT COUNT(*) FROM migracao_stg.sbacem_import_staging;

SELECT atlas_id, COUNT(*), COUNT(DISTINCT numero_link)
FROM migracao_stg.sbacem_import_staging
GROUP BY atlas_id
ORDER BY COUNT(*) DESC
LIMIT 5;

SELECT * FROM migracao_stg.sbacem_import_staging
WHERE atlas_id = 'AW0MTYO2'
ORDER BY numero_link, chain_id;
```

## 4. Reexecutar

Seguro: o script faz `TRUNCATE` + recriação da tabela de staging no início do bloco correspondente — **perde apenas o staging**, não o cadastro Woodstock.
