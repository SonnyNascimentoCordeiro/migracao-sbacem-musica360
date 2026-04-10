# Research — Importação MDB com links, cessão e Música 360

**Feature**: `002-chain-link-numeric` (complementa `001-import-obras-mdb-titular`)  
**Date**: 2026-04-04

## 1. Rateio da cessão MR quando um CAE tem várias linhas editoriais em links distintos

- **Decision**: Para **uma única** linha em `mdb.titular` / `titular2` com **`percentual` = cessão total** e **N** linhas na obra do **mesmo CAE cedente** em **N links** distintos (ex.: BOCA F→A, G→B, H→C), distribuir o MR da **M360** em **N** linhas com **partes iguais** (`cessão / N`), com **ajuste de arredondamento** na última linha para ΣMR M360 = cessão exata.
- **Rationale**: Default explícito na spec **002**; determinístico; fácil de auditar; fecha com regra **FR-008** (titular+titular2 sem duplicar cessão).
- **Alternatives considered**: Rateio proporcional ao MR de cada linha `sbacem` do cedente; uma única linha M360 (rejeitada — viola “mesmo link que o titular” por grupo).

## 2. MR remanescente do cedente (editor) após cessão

- **Decision**: Para cada **linha** do cedente na `sbacem`, **`MR_linha_destino = MR_linha_fonte − parcela_atribuída_à_M360_daquele_link`**, onde a soma das parcelas nas N linhas = **cessão total**. **PR e SR** da linha seguem a `sbacem` (cessão só MR).
- **Rationale**: Alinhado à **FR-008** / spec **001**; ΣMR da obra permanece 100% quando Σ parcelas M360 = cessão.
- **Alternatives considered**: Agregar cedente em um único integrante (spec 001 agregado) — alternativa válida para outro “modo” de importação, não para o modelo multi-link da **002**.

## 3. Persistência do `link` numérico no Woodstock

- **Decision**: Na **Fase de implementação**, **confirmar no DDL** se `obras.obra_integrante` (ou tabela satélite) já possui coluna para **grupo editorial / link**. Se **não** existir: proposta de **`numero_link` (integer)** ou reutilização de campo existente aprovada pelo time — **nunca inferir víncio só por `sequencia`** (**FR-003**).
- **Rationale**: Spec **001** **FR-009** exige auditabilidade de `chain_id`/`chain`; o inteiro de link é derivado e deve ser **gravado** ou **reconstruível** de forma determinística.
- **Alternatives considered**: Armazenar só `chain_id` texto por linha — possível, mas o produto pediu **link numérico**; tabela `obra_integrante_metadado` chaveada por `id_obra_integrante`.

## 4. Editoras com `chain` vazio (fallback)

- **Decision**: Atribuir **link exclusivo** por linha (ordenação determinística: ex. lexicográfica por `chain_id`, depois ordem de leitura), **registrar em relatório de importação** o código `chain_id` e o fato “sem par editorial na fonte”.
- **Rationale**: **FR-004** da spec **002**; evita fundir UNKNOWN com titular sem evidência.
- **Alternatives considered**: Rejeitar obra — possível flag de negócio futura; não é default sem stakeholder.

## 5. `cod_categoria` da Música 360

- **Decision**: **`SE`** se existir **`E`** no **mesmo link**; senão **`E`** (**FR-010**, specs **001** e **002**).
- **Rationale**: Evita dois “editores” no mesmo grupo lógico; alinhado CWR Sub-editor.
- **Alternatives considered**: Sempre `E` — rejeitado pelo negócio (pedido explícito).

## 6. Ordem dos links para titulares sem editor e para editoras órfãs

- **Decision**: **Passo 1**: numerar links para todos os **pares** `(titular chain_id = T, editora com chain=T)` na ordem **lexicográfica de T**. **Passo 2**: titulares cujo `chain_id` não aparece como `chain` de ninguém recebem o **próximo** inteiro disponível, ordenados por `chain_id`. **Passo 3**: linhas editoriais com `chain` vazio recebem **próximos** inteiros, ordenadas por `chain_id` da própria linha.
- **Rationale**: Determinístico, reproduzível, compatível com exemplo AW0MTYO2 (A,B,C → 1,2,3; D,E → 4,5; I,J → 6,7).
- **Alternatives considered**: Ordenar por ordem de arquivo — menos estável entre cargas.

## 7. Tecnologia de execução do job

- **Decision**: **SQL** (CTEs/staging tables) **ou** **Python** (pandas/psycopg2) gerando batches de INSERT, conforme preferência do time; ambos válidos se respeitarem tenant **38** / config **61** e transações por fase.
- **Rationale**: Repositório já usa Python para carga `mdb.sbacem`; importação Woodstock tende a SQL volumoso com validações.
- **Alternatives considered**: Apenas ETL externo — fora do escopo do repo atual.
