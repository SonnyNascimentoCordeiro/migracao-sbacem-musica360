# Research — Arquivo SQL único (staging)

**Feature**: `003-consolidated-migration-sql`  
**Date**: 2026-04-04

## 1. Fonte da verdade: único vs modular

- **Decision**: O arquivo **`migracao_staging_um_arquivo.sql`** é o **artefato de execução** preferido pelo operador. Os scripts em `sql/`, `staging/`, `ddl/` permanecem como **desenvolvimento e diff legível**; alterações de negócio entram primeiro nos modulares e são **copiadas** para o único (ou geradas por script de build, se o time adotar).
- **Rationale**: Pedido explícito de simplicidade; modulares preservam revisão em PR.
- **Alternatives considered**: Só arquivo único (sem modulares) — pior para code review; só modulares — rejeitado pelo usuário.

## 2. Geração automática futura

- **Decision**: Opcional: `python scripts/migracao/build_um_arquivo.py` concatenando lista em `SEQUENCIA_EXECUCAO.txt` — **não obrigatório** na v1.
- **Rationale**: Evita deriva manual; pode ser fase 2.
- **Alternatives considered**: `cat` em Makefile — viável em Unix; Windows prefere Python/PowerShell.

## 3. Paridade

- **Decision**: Ordem no único = passos 1–8 de `SEQUENCIA_EXECUCAO.txt` (bloco principal, sem opcionais de carga destino).
- **Rationale**: Uma sequência documentada.
- **Alternatives considered**: Incluir validações no mesmo arquivo — rejeitado (mantém arquivo focado em mutação; validações podem ser segundo arquivo ou comentadas no final).

## 4. Ferramenta de execução

- **Decision**: Compatível com **psql** e **DBeaver**; evitar meta-comandos `\i` exclusivos do psql no corpo do script.
- **Rationale**: Usuários mistos.
- **Alternatives considered**: Apenas psql — menos inclusivo.
