# Plano: Reimportação Completa do Catálogo SBACEM

**Feature:** reimportacao-completa-sbacem
**Data:** 2026-03-22
**Status:** Aguardando execução

## Contexto

A importação inicial apresentou múltiplos problemas que tornam inviável corrigir pontualmente:
- `controle_pr/mr/sr` da obra calculado incorretamente (soma dos autores em vez do percentual da editora)
- MUSICA 360 entrou como `AM` em obras onde deveria ser `E`
- 84.867 obras sem a MUSICA 360 como participante (deveria estar em 100% das obras)
- Percentuais MR/SR dos autores deduzidos incorretamente da parte da editora

Decisão: apagar tudo e reimportar com as regras corretas.

## Regras de Negócio Definidas

### Pessoas
- Deduplica por `ipi_name_number`
- `codigo` = `ipi_name_number`
- `tipo`: `J` se somente roles de editor (E, ES, AM, PA, SE, AQ), `F` caso contrário
- `autor`: true se qualquer role in (CA, C, A, AR, SA, AD, TR)
- `editor`: true se qualquer role in (E, ES, AM, PA, SE, AQ)

### Autores (obra_integrante)
- **Controlado** = true se `ipi_name_number` está na `mdb.titular` (chave: `titular.cae`)
- **PR** = `per_own` da fonte (sempre)
- **MR/SR** = `per_own * (1 - taxa_titular)` se controlado; igual ao PR se não controlado

### MUSICA 360 (id=2405890) — entra em TODAS as obras
- **categoria**: `E` se não há outra editora (E, ES, SE) na obra; `AM` se há
- **PR**: sempre 0 (editora não representa execução pública)
- **MR/SR**: soma de `per_own * taxa_titular` dos autores controlados da obra
- **controlado**: sempre true
- ⚠️ **PENDENTE**: 88.926 obras não têm nenhum autor na `mdb.titular` — comportamento da MUSICA 360 nesses casos ainda não definido. Ver seção "Questões Pendentes".

### Controle da Obra
- `controle_pr`: sempre 0 (percentual PR da MUSICA 360)
- `controle_mr`: soma MR da MUSICA 360
- `controle_sr`: mesmo valor que MR

### Tabela de referência
- `mdb.titular`: chave `cae` = `ipi_name_number` da SBACEM
- `percentual` no formato `'15%'` → converter com `REPLACE('%','')::float / 100`

## Análise do Estado Atual (antes da reimportação)

| Situação | Qtd |
|---|---|
| Total de obras | 125.522 |
| Obras com MUSICA 360 | 40.655 |
| Obras SEM MUSICA 360 | 84.867 |
| Obras com controle_pr errado | 121.854 |
| Obras com controle_mr errado | 31.650 |
| Obras com controle_sr errado | 121.854 |

## Fase 1 — Limpeza

**Objetivo:** Remover todos os dados importados do tenant 38, preservando a MUSICA 360 (id=2405890).

### Tarefas
- [ ] Deletar `obras.obra_de_para` do tenant 38
- [ ] Deletar `obras.obra_titulo` do tenant 38
- [ ] Deletar `obras.obra_integrante` do tenant 38
- [ ] Deletar `obras.obra` do tenant 38
- [ ] Deletar `pessoas.pessoa_de_para` (exceto MUSICA 360)
- [ ] Deletar `pessoas.pessoa` importadas (exceto MUSICA 360)

### Verificação
Após limpeza: tenant 38 deve ter 0 obras e 1 pessoa (MUSICA 360).

---

## Fase 2 — Pessoas

**Objetivo:** Reimportar 32.915 pessoas distintas com regras corretas.

### Tarefas
- [ ] INSERT em `pessoas.pessoa` dedupondo por `ipi_name_number`
- [ ] INSERT em `pessoas.pessoa_de_para` com parceiro 128 (SBACEM)

### Verificação
`SELECT COUNT(*) FROM pessoas.pessoa WHERE id_tenant = 38` → ~32.916 (incluindo MUSICA 360)

---

## Fase 3 — Obras

**Objetivo:** Reimportar 125.522 obras com controles corretos.

### Tarefas
- [ ] INSERT em `obras.obra` com código sequencial e controles calculados
- [ ] INSERT em `obras.obra_de_para` com parceiro 128 (SBACEM), codigo = atlas_id

### Verificação
`SELECT COUNT(*) FROM obras.obra WHERE id_tenant = 38` → 125.522

---

## Fase 4 — Títulos Alternativos

**Objetivo:** Importar `alternate_titles` para `obras.obra_titulo` com tipo `AT`.

### Tarefas
- [ ] INSERT em `obras.obra_titulo` separando por `|`

---

## Fase 5 — Integrantes (autores e editoras da fonte)

**Objetivo:** Importar participantes com percentuais corretos.

### Tarefas
- [ ] INSERT em `obras.obra_integrante` com PR/MR/SR calculados conforme `mdb.titular`

---

## Fase 6 — MUSICA 360 em todas as obras

**Objetivo:** Garantir que a MUSICA 360 esteja em 100% das obras com categoria e percentuais corretos.

### Tarefas
- [ ] INSERT em `obras.obra_integrante` para MUSICA 360 em todas as obras do tenant 38

### Verificação
```sql
SELECT COUNT(*) FROM obras.obra o WHERE o.id_tenant = 38
AND NOT EXISTS (
    SELECT 1 FROM obras.obra_integrante oi
    WHERE oi.id_obra = o.id AND oi.id_pessoa = 2405890
);
-- Deve retornar 0
```

---

## Questões Pendentes

### Q1 — Obras sem autor controlado (88.926 obras)

**Situação:** 88.926 obras da SBACEM não possuem nenhum autor na `mdb.titular`. Ou seja, a MUSICA 360 não tem contrato de administração com nenhum autor dessas obras.

**Consulta para análise:**
```sql
-- Obras do tenant 38 sem a MUSICA 360 como participante (estado atual da base)
SELECT o.codigo, o.titulo, o.iswc,
       STRING_AGG(p.nome || ' (' || oi.cod_categoria || ')', ', ' ORDER BY oi.sequencia) AS participantes
FROM obras.obra o
JOIN obras.obra_integrante oi ON oi.id_obra = o.id
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa
WHERE o.id_tenant = 38
  AND NOT EXISTS (
      SELECT 1 FROM obras.obra_integrante oi2
      WHERE oi2.id_obra = o.id AND oi2.id_pessoa = 2405890
  )
GROUP BY o.id, o.codigo, o.titulo, o.iswc
ORDER BY o.codigo
LIMIT 50;
```

**Perguntas em aberto:**
- Essas obras deveriam estar no catálogo do tenant 38?
- A MUSICA 360 entra mesmo assim com 0% em tudo?
- Ou essas obras ficam em espera / são descartadas?

**Status:** ⏳ Aguardando resposta para prosseguir com a fase 6b do script.

---

## Arquivos Modificados / Criados

| Arquivo | Fase | Operação |
|---|---|---|
| `scripts/02_reimportacao_completa.sql` | Todas | Criado |
| `docs/plans/2026-03-22_002_reimportacao-completa-sbacem.md` | — | Criado |
