# Contract: pipeline de importação MDB → Woodstock

**Versão**: 1.0  
**Audiência**: implementação (SQL/Python) e QA

## Entradas

| Nome | Tipo | Obrigatório | Descrição |
|------|------|-------------|-----------|
| `sbacem_rows` | conjunto de linhas | sim | Mesmo grão que `mdb.sbacem` por `atlas_id` |
| `titular_by_cae` | mapa CAE → `percentual` (cessão MR) | sim | União lógica `titular` + `titular2` sem duplicar cessão (**FR-008**) |
| `tenant_id` | int | sim | **38** |
| `config_id` | int | sim | **61** |
| `id_pessoa_m360` | bigint | sim | FK da editora Música 360 no tenant |
| `id_parceiro` | int/bigint | sim | Para `obra_de_para` / `pessoa_de_para` |

## Saídas

| Nome | Tipo | Descrição |
|------|------|-----------|
| `obras` | registros | 1 por `atlas_id` distinto no lote |
| `obra_integrantes` | registros | 1 por linha `sbacem` (política multi-link) + N linhas M360 |
| `de_paras` | registros | cruzamento atlas_id / IPI |
| `report` | artefato | contagens, exceções, obras com chain inválido |

## Invariantes (MUST)

1. **I1**: Todo integrante gerado a partir da `sbacem` preserva mapeamento auditável de `chain_id` e, se aplicável, **`link`** inteiro (**FR-009**).
2. **I2**: Para cada par editorial resolvido (`chain` → `chain_id` titular), **link(titular) = link(editora)**.
3. **I3**: Para cada titular controlado com cessão, existe **≥1** linha M360 com **MR** somando à cessão (rateio conforme plano) e **link(M360) = link(titular daquele grupo)**.
4. **I4**: `cod_categoria` M360 ∈ {`SE`, `E`} conforme presença de `E` no link (**FR-010**).
5. **I5**: `obra.controle_mr = SUM(percentual_mr)` onde participante é M360.
6. **I6**: Nenhum registro com `id_tenant ≠ 38`.

## Erros reportáveis (SHOULD classificar)

| Código | Condição |
|--------|----------|
| `CHAIN_DANGLING` | `chain` preenchido sem `chain_id` correspondente na obra |
| `CESSAO_EXCEDE_MR` | cessão > MR agregado do CAE |
| `SOMA_PERCENTUAL` | Σ PR/MR/SR ≠ 100% após arredondamento |
| `TITULAR_SEM_SBacem` | CAE em titular sem linha na obra |

## Ordem de execução (SHOULD)

1. Resolver links por obra (grafo `chain` / `chain_id`).
2. Calcular cessão e MR/PR/SR por linha.
3. Inserir/atualizar pessoas (dedup IPI).
4. Inserir obras + de_para.
5. Inserir integrantes + de_para.
6. Rodar queries de verificação (constituição — Verification Phase).
