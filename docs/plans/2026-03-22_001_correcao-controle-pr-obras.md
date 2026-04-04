# Plano: Correção do Controle PR das Obras Importadas

**Feature:** correcao-controle-pr-obras
**Data:** 2026-03-22
**Status:** Executado

## Contexto

Durante a importação do catálogo SBACEM para o tenant 38 (M360), o campo `controle_pr` das obras foi preenchido incorretamente. O valor correto deve refletir o percentual de execução pública (PR) da editora **MUSICA 360** (id=2405890) como integrante da obra — e não o somatório dos demais integrantes controlados.

## Análise do Estado Atual

- **121.854 obras** do tenant 38 estavam com `controle_pr` incorreto
- Exemplo identificado: obra "2018" (codigo=`AW0K5YDW`) com `controle_pr = 75`, sendo que a MUSICA 360 possui `percentual_pr = 0` nessa obra
- O campo `controlado = true` nos integrantes está correto — o problema era exclusivamente no `controle_pr` da obra

## Decisão Arquitetural

O `controle_pr` da obra deve ser igual ao somatório do `percentual_pr` dos integrantes onde `id_pessoa = 2405890` (MUSICA 360). Na maioria das obras importadas da SBACEM, esse valor é 0, pois a editora entra como AM (Administrator) sem percentual de PR.

## Fase 1 — Correção do campo controle_pr

**Objetivo:** Atualizar `controle_pr` de todas as obras do tenant 38 com o valor correto (percentual PR da MUSICA 360).

### Tarefas

- [x] Identificar escala do problema (121.854 obras afetadas)
- [x] Validar lógica do UPDATE com exemplo concreto (obra AW0K5YDW)
- [x] Gerar e executar script SQL de correção

### SQL Executado

```sql
UPDATE obras.obra o
SET controle_pr = (
    SELECT COALESCE(SUM(oi.percentual_pr), 0)
    FROM obras.obra_integrante oi
    WHERE oi.id_obra = o.id
    AND oi.id_pessoa = 2405890
)
WHERE o.id_tenant = 38;
```

### Verificação

- Após execução, `controle_pr` das obras do tenant 38 deve refletir 0% para obras onde a MUSICA 360 não tem percentual PR
- Verificar na tela de Cadastro de Obras: campo "Controle execução pública" deve mostrar 0%

---

## Arquivos Modificados / Criados

| Arquivo | Fase | Operação |
|---|---|---|
| `docs/plans/2026-03-22_001_correcao-controle-pr-obras.md` | 1 | Criado |
