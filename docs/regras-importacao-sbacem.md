# Regras de Importação SBACEM → Woodstock (Tenant 38 / M360)

**Tenant:** 38 | **Configuração:** 61 | **Musica 360:** id_pessoa=2405890

---

## 1. Obras (`obras.obra`)

| Campo | Valor |
|---|---|
| `id_tenant` | 38 |
| `id_configuracao` | 61 |
| `codigo` | `atlas_id` (chave de lookup) |
| `titulo` | `original_title` |
| `iswc` | `iswc` (null se vazio) |
| `situacao` | `'L'` |
| `cod_tipo_versao` | `'ORI'` |
| `cancelada` | `false` |
| `retida` | `false` |
| `gravada` | `false` |
| `instrumental` | `false` |
| `importado` | `true` |
| `nacional` | `true` |
| `registro` | `CURRENT_DATE` |
| `controlada` | `true` se há M360 na obra |
| `controle_pr` | `0` |
| `controle_mr` | soma `coleta_mr` do M360 |
| `controle_sr` | soma `coleta_sr` do M360 |

---

## 2. Títulos Alternativos (`obras.obra_titulo`)

- Inserir apenas `alternate_titles` (não o título principal)
- Separador `|` — cada parte vira 1 linha
- `cod_tipo_titulo = 'AL'`
- `ativo = true`

---

## 3. Links Editoriais (`link` em `obra_integrante`)

- Editor tem campo `chain` apontando para `chain_id` do(s) autor(es)
- `chain` pode ter múltiplos valores separados por ` | ` (ex: `"E | F"`)
- Cada par autor+editor recebe um `link` sequencial único por obra
- Editor com `chain = "E | F"` gera **duas linhas** — uma por alvo (link 2 com JOAO, link 3 com ROBESON)
- Participantes sem par recebem link sequencial próprio (após os pares)
- **Todos** os participantes têm link preenchido

---

## 4. Integrantes Base (`obras.obra_integrante`)

### Lookup de pessoa
```
pessoas.pessoa.ip_name = mdb.sbacem.ipi_name_number AND id_tenant = 38
```

### Campos fixos
- `cod_territorio = '76'` (Brasil)

### Percentuais de propriedade
| Campo | Valor |
|---|---|
| `percentual_pr` | `per_own` |
| `percentual_mr` | Ver regra abaixo |
| `percentual_sr` | `= percentual_mr` |
| `percentual_base` | `per_own` |

### Regra do `percentual_mr`
- **Não controlado:** `percentual_mr = mec_own`
- **Titular cedente:** `percentual_mr = GREATEST(0, mec_own - LEAST(mec_own, pct_titular))`

### Percentuais de coleta
| Campo | Controlado | Não controlado |
|---|---|---|
| `coleta_pr` | `per_own` | `per_own` |
| `coleta_mr` | `0` | `0` |
| `coleta_sr` | `0` | `0` |

### Controlado
- `controlado = true` se o participante está em `mdb.titular`
- Lookup: `mdb.titular.ipi = mdb.sbacem.ipi_base_number` (LIMIT 1)

---

## 5. Titular Cedente (`mdb.titular`)

- `mdb.titular.ipi = mdb.sbacem.ipi_base_number` (LIMIT 1)
- Campo `percentual` é numérico (ex: `"15"` — sem `%`)
- MR cedido ao M360: `LEAST(mec_own, pct_titular)`
- MR que sobra ao titular: `GREATEST(0, mec_own - LEAST(mec_own, pct_titular))`
- Se `mec_own < pct_titular` → titular fica com 0%, M360 leva tudo que tinha

---

## 6. Musica 360 (`id_pessoa = 2405890`)

### Inserção
- Inserido **uma vez por link** onde há titular cedente
- Nunca inserido mais de uma vez no mesmo link

### Categoria (`cod_categoria`)
- `'AM'` se já existe `E` no mesmo link
- `'E'` caso contrário

### Percentuais de propriedade
| Campo | Valor |
|---|---|
| `percentual_pr` | `0` |
| `percentual_mr` | `LEAST(mec_own, pct_titular)` (soma se múltiplos cedentes no link) |
| `percentual_sr` | `= percentual_mr` |
| `percentual_base` | `0` |

### Percentuais de coleta
| Campo | Valor |
|---|---|
| `coleta_pr` | `0` (sempre) |
| `coleta_mr` | soma `coleta_pr` dos controlados do **mesmo link** |
| `coleta_sr` | `= coleta_mr` |

### Outros
- `controlado = true` sempre
- `cod_territorio = '76'`

---

## 7. Percentuais de Distribuição (fonomecanico + sincronizacao)

> Esses campos refletem como os direitos são distribuídos entre os participantes.

### Musica 360 como `E` (controlado é CA/autor)
- Fonte: `mdb.titular.percentual`
- Valor direto → `fonomecanico = sincronizacao = pct_titular`

### Musica 360 como `AM` (controlado é E/editora)
- Fonte: `mdb.titular2.percentual`
- Valor proporcional: `percentual_base_editora * (pct_titular2 / 100)`

### Controlados (autor ou editora)
```
fonomecanico = sincronizacao = ROUND((percentual_base / controle_mr_obra) * 100 - pct_m360, 2)
```
- Nunca negativo (usar `MAX(0, valor)`)

### Não controlados
- `fonomecanico = sincronizacao = 0`

### execucao_publica
- `0` para todos (M360 não participa de execução pública)

---

## 8. Controle da Obra

Após inserir todos os integrantes:

```
obras.obra.controlada  = true  (se há M360)
obras.obra.controle_mr = SUM(coleta_mr) WHERE id_pessoa = 2405890
obras.obra.controle_sr = SUM(coleta_sr) WHERE id_pessoa = 2405890
```

---

## 9. Fontes de Dados

| Tabela | Uso |
|---|---|
| `mdb.sbacem` | Fonte principal — obras e participantes |
| `mdb.titular` | Titulares cedentes (autores/editores controlados pelo M360) |
| `mdb.titular2` | Editoras administradas pelo M360 (para distribuição proporcional) |
| `pessoas.pessoa` | Lookup de id_pessoa por ip_name (id_tenant=38) |

---

## 10. Regras de Segurança

- **Somente tenant 38** — nunca inserir em outro tenant
- **Não usar `obra_de_para` nem `pessoa_de_para`** — lookup direto pelas tabelas
- **Limpeza manual** — executar SQL de limpeza antes de reimportar (não automático)

---

## 11. Script e Procedure Legados

- Procedure: `mdb.carga_final_obras()` (SQL puro, substituída pelo programa Java)
- Script: `scripts/migracao/sql/carga_final_obras.sql`
- Programa Java: `scripts/importacao/` (Spring Boot + JDBI)

---

## 12. Modos de Execução (programa Java)

```bash
# Preview sem inserir no banco
GET http://localhost:8090/importacao/preview/{atlas_id}

# Importar obra específica
POST http://localhost:8090/importacao/obra/{atlas_id}

# Importar todas as obras
POST http://localhost:8090/importacao/todas

# Interface visual
http://localhost:8090/index.html
```
