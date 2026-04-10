# Quickstart — Plano de execução da importação

**Objetivo**: implementar a importação `mdb.sbacem` + `mdb.titular` / `mdb.titular2` → Woodstock com **links numéricos**, **cessão MR**, **Música 360** (**SE**/**E**) e **isolamento tenant 38**.

## Pré-requisitos

1. Ler `specs/001-import-obras-mdb-titular/spec.md` e `specs/002-chain-link-numeric/spec.md`.
2. Confirmar DDL: coluna (ou estratégia) para **`link`** em integrante — ver `research.md`.
3. Obter `id_pessoa` da **Música 360** no tenant 38 e `id_parceiro` para de/para.
4. Revisar `scripts/remover_obras_sbacem.sql` (rollback) e duplicar padrão para novas fases se necessário.

## Passos recomendados

### 1. Prova em amostra

- Fixar **1 obra**: `AW0MTYO2` (referência nas specs).
- Validar manualmente a **tabela de composição** (link, PR/MR/SR, SE na M360).
- Queries: contagens por `atlas_id`, soma de percentuais.

### 2. Staging

- Criar tabela temporária ou schema `staging` com colunas: `atlas_id`, `chain_id`, `chain`, `link`, `ipi`, `role`, `pr`, `mr`, `sr`, `flags`.
- Popular a partir de `mdb.sbacem` com normalização de decimais (`REPLACE(..., ',', '.')`).

### 3. Algoritmo de link

- Implementar ordenação da spec **002** (pares → titulares soltos → editoras sem chain).
- Preencher `link` em todas as linhas da obra.

### 4. Cessão e M360

- Join `titular`/`titular2` por CAE = `ipi_name_number`.
- Rateio **igual** da cessão entre **N** links do mesmo cedente (default).
- Inserir linhas M360; definir **SE** vs **E** por link.

### 5. Carga no destino

- Transação por lote (ex.: 500 obras) ou COPY + commit, conforme performance (&lt;10 min / 125k obras — constituição).
- Cada INSERT com `id_tenant = 38` e `id_configuracao = 61` explícitos.

### 6. Verificação (obrigatória)

- Cardinalidade: obras fonte vs destino.
- `AW0MTYO2`: `controlada`, `controle_mr = 15`, 3× M360 com link 1–3 e **SE**, ΣMR = 100%.
- Amostra aleatória de 10 obras.

## Artefatos a versionar

- Scripts SQL e/ou `migracao/*.py` com parâmetros de tenant em cabeçalho.
- `report/` ou stdout com CSV de exceções (`CHAIN_DANGLING`, etc.).

## Próximo comando Speckit

- `/speckit.tasks` a partir deste `plan.md` para gerar `tasks.md` com itens executáveis.
