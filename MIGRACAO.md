# Migração SBACEM → Woodstock
**Tenant:** 38 | **Configuração:** 61 | **Referência:** M360
**Data de execução:** 2026-03-16

---

## Resultado Final

| Tabela | Qtd importada |
|---|---|
| `pessoas.pessoa` | 32.914 |
| `pessoas.pessoa_de_para` | 32.913 |
| `obras.obra` | 125.522 |
| `obras.obra_de_para` | 125.522 |
| `obras.obra_integrante` | 302.575 |
| `obras.obra_titulo` | 9.551 |

---

## Contexto

- **Fonte:** `mdb.sbacem` (302.585 linhas brutas)
- **Parceiro SBACEM criado:** `pessoas.parceiro.id = 128` (tenant 38)
- **Editora pré-existente:** MUSICA 360 — `pessoas.pessoa.id = 2405890`, `codigo = '2'`
- **Campo `ignorar`** adicionado em `mdb.sbacem`: 10 registros marcados para não importar

---

## Decisões Tomadas

| Decisão | Valor aplicado |
|---|---|
| `pessoa.codigo` | `ipi_name_number` |
| `obra.codigo` | `atlas_id` |
| `pessoa.tipo` | `'J'` se todos os roles são editoriais (E, ES, AM, PA, SE, AQ), senão `'F'` |
| `obra.nacional` | `true` |
| `obra.controlada` | `true` quando MUSICA 360 (`ipi=01328827822`) é integrante |
| `obra_integrante.controlado` | `true` quando `id_pessoa = 2405890` (MUSICA 360) |
| `percentual_sr` | mesmo valor de `per_own` |
| `obra_integrante.link` | `1` |
| `obra_integrante.cod_territorio` | `76` (Brasil) |
| `obra_titulo.cod_tipo_titulo` | `'AT'` (títulos alternativos) |
| `obra.registro` | `CURRENT_DATE` (data da importação) |
| MUSICA 360 nos integrantes | reutiliza `id=2405890` — não cria duplicata |

---

## Scripts Executados (em ordem)

### 1. Criar parceiro SBACEM
```sql
INSERT INTO pessoas.parceiro (id, id_tenant, descricao, criacao)
VALUES (nextval('pessoas.parceiro_seq'), 38, 'SBACEM', now())
RETURNING id;
-- id retornado: 128
```

### 2. Inserir pessoas
```sql
INSERT INTO pessoas.pessoa (
    id_tenant, codigo, nome, tipo,
    autor, editor, ip_name, ip_base,
    importado, ativo, excluido, criacao
)
SELECT
    38,
    ipi_name_number                                                      AS codigo,
    (array_agg(UPPER(ip_name) ORDER BY ip_name))[1]                     AS nome,
    CASE WHEN bool_and(ip_role IN ('E','ES','AM','PA','SE','AQ'))
         THEN 'J' ELSE 'F' END                                           AS tipo,
    bool_or(ip_role IN ('CA','C','A','AR','SA','AD','TR'))               AS autor,
    bool_or(ip_role IN ('E','ES','AM','PA','SE','AQ'))                   AS editor,
    ipi_name_number                                                      AS ip_name,
    NULLIF((array_agg(ipi_base_number ORDER BY ip_name))[1], '')         AS ip_base,
    true, true, false, now()
FROM mdb.sbacem
WHERE ipi_name_number IS NOT NULL
  AND ipi_name_number <> ''
  AND ipi_name_number <> '01328827822'  -- MUSICA 360 já existe
  AND (ignorar IS NULL OR ignorar = false)
GROUP BY ipi_name_number
ORDER BY ipi_name_number;
```

### 3. Inserir obras
```sql
INSERT INTO obras.obra (
    id_tenant, id_configuracao, codigo, titulo, iswc,
    situacao, cod_tipo_versao,
    cancelada, retida, gravada, instrumental,
    controlada, importado, nacional,
    registro, criacao
)
SELECT
    38, 61,
    atlas_id                                                              AS codigo,
    LEFT((array_agg(original_title ORDER BY original_title))[1], 200)    AS titulo,
    NULLIF((array_agg(NULLIF(iswc,'') ORDER BY iswc NULLS LAST))[1], '') AS iswc,
    'L', 'ORI',
    false, false, false, false,
    bool_or(ipi_name_number = '01328827822')                             AS controlada,
    true, true,
    CURRENT_DATE, now()
FROM mdb.sbacem
WHERE atlas_id IS NOT NULL
  AND atlas_id <> ''
  AND (ignorar IS NULL OR ignorar = false)
GROUP BY atlas_id
ORDER BY atlas_id;
```

### 4. Inserir obra_de_para
```sql
INSERT INTO obras.obra_de_para (id, id_obra, id_parceiro, codigo, criacao)
SELECT
    nextval('obras.obra_de_para_seq'),
    o.id,
    128,
    o.codigo,
    now()
FROM obras.obra o
WHERE o.id_tenant = 38
  AND o.importado = true;
```

### 5. Inserir obra_integrante
```sql
INSERT INTO obras.obra_integrante (
    id_obra, id_pessoa,
    link, cod_territorio,
    cod_categoria, controlado,
    percentual_pr, percentual_mr, percentual_sr,
    sequencia, criacao
)
SELECT
    o.id                                                                     AS id_obra,
    COALESCE(p.id, 2405890)                                                  AS id_pessoa,
    1                                                                        AS link,
    76                                                                       AS cod_territorio,
    s.ip_role                                                                AS cod_categoria,
    (COALESCE(p.id, 2405890) = 2405890)                                      AS controlado,
    REPLACE(s.per_own, ',', '.')::float                                      AS percentual_pr,
    REPLACE(s.mec_own, ',', '.')::float                                      AS percentual_mr,
    REPLACE(s.per_own, ',', '.')::float                                      AS percentual_sr,
    ROW_NUMBER() OVER (PARTITION BY s.atlas_id ORDER BY s.ip_role, s.ipi_name_number) AS sequencia,
    now()                                                                    AS criacao
FROM mdb.sbacem s
JOIN obras.obra o
    ON o.codigo = s.atlas_id AND o.id_tenant = 38
LEFT JOIN pessoas.pessoa p
    ON p.codigo = s.ipi_name_number AND p.id_tenant = 38
WHERE (s.ignorar IS NULL OR s.ignorar = false)
  AND (p.id IS NOT NULL OR s.ipi_name_number = '01328827822');
```

### 6. Inserir pessoa_de_para
```sql
INSERT INTO pessoas.pessoa_de_para (id, id_pessoa, id_parceiro, codigo, criacao)
SELECT
    nextval('pessoas.pessoa_de_para_seq'),
    p.id,
    128,
    p.codigo,
    now()
FROM pessoas.pessoa p
WHERE p.id_tenant = 38
  AND p.id <> 2405890;
```

### 7. Inserir obra_titulo (títulos alternativos)
```sql
INSERT INTO obras.obra_titulo (id, id_obra, titulo, cod_tipo_titulo, ativo, criacao)
SELECT
    nextval('obras.obra_titulo_seq'),
    o.id,
    LEFT(TRIM(t.titulo), 200),
    'AT',
    true,
    now()
FROM mdb.sbacem s
JOIN obras.obra o ON o.codigo = s.atlas_id AND o.id_tenant = 38
JOIN LATERAL (
    SELECT TRIM(unnest(string_to_array(s.alternate_titles, '|'))) AS titulo
) t ON t.titulo <> ''
WHERE s.alternate_titles IS NOT NULL AND s.alternate_titles <> ''
  AND (s.ignorar IS NULL OR s.ignorar = false)
GROUP BY o.id, t.titulo;
```

---

## Observações

- Os 10 registros marcados com `mdb.sbacem.ignorar = true` têm `ipi_name_number = '00000000000'` (IPI inválido/nome vazio) — pendente de contato com a SBACEM para esclarecimento.
- `obra_titulo` ficou com 9.551 registros (vs 21.243 linhas na fonte) pois o `GROUP BY` eliminou títulos duplicados que repetiam em múltiplas linhas da mesma obra.
- `pessoa_de_para` tem 32.913 registros (uma a menos que `pessoa`) pois MUSICA 360 não foi importada via SBACEM.

---

## Fase 2 — Titulares Administrados (2026-03-22)

### Contexto

Após revisão do catálogo digital, foram identificados os titulares administrados pela MUSICA 360. A lista foi importada em `mdb.titular` (1.163 registros) e `mdb.titular2` (5 registros especiais).

### Resultado

| Tabela | Registros atualizados |
|---|---|
| `obras.obra_integrante` (controlado) | 50.656 |
| `obras.obra` (controlada) | 40.655 |

### Tabelas auxiliares

| Tabela | Qtd | Descrição |
|---|---|---|
| `mdb.titular` | 1.163 | Titulares administrados — 1.158 com 15%, 5 com `'Música 360'` |
| `mdb.titular2` | 5 | Mesmos 5 com percentuais específicos: CAIO DJAY=40%, HC MUSIC=60%, JAMIL=25%, RIMAS STUDIO=60%, SOM VIVO=60% |

**Join key:** `mdb.titular.cae = mdb.sbacem.ipi_name_number = pessoas.pessoa.codigo`

### Decisões Tomadas

| Decisão | Valor aplicado |
|---|---|
| Titulares a atualizar | Apenas os que constam em `mdb.titular` (via `cae = pessoa.codigo`) |
| Participantes fora de `mdb.titular` | Ignorados — não sofrem alteração |
| `obra_integrante.controlado` | `true` para todos os titulares de `mdb.titular` |
| `obra_integrante.percentual_pr/mr/sr/base` | Valor numérico de `mdb.titular.percentual` (ex: 15); para os 5 especiais, usa `mdb.titular2.percentual` |
| `obra_integrante.link` | Herdado do link da MUSICA 360 (id=2405890) na mesma obra; mantém original se M360 não estiver na obra |
| `obra.controlada` | `true` para toda obra com ao menos um titular de `mdb.titular` |
| `cod_categoria` da MUSICA 360 | Mantido como `'AM'` (Administrator) — correto, pois há outra editora na obra |
| Percentuais da MUSICA 360 | Mantidos como vieram da fonte — não alterados nesta fase |

### Script

Arquivo: `fase2_titulares_controlados.sql`

```sql
WITH m360_links AS (
    SELECT id_obra, link AS m360_link
    FROM obras.obra_integrante
    WHERE id_pessoa = 2405890
),
titular_pct AS (
    SELECT t.cae,
           REPLACE(
               CASE WHEN t2.percentual IS NOT NULL THEN t2.percentual
                    ELSE t.percentual
               END, '%', '')::float AS pct
    FROM mdb.titular t
    LEFT JOIN mdb.titular2 t2 ON t2.cae = t.cae
),
titulares AS (
    SELECT
        oi.id,
        COALESCE(ml.m360_link, oi.link) AS novo_link,
        tp.pct
    FROM obras.obra_integrante oi
    JOIN obras.obra o        ON o.id = oi.id_obra
    JOIN pessoas.pessoa p    ON p.id = oi.id_pessoa AND p.id_tenant = 38
    JOIN titular_pct tp      ON tp.cae = p.codigo
    LEFT JOIN m360_links ml  ON ml.id_obra = oi.id_obra
    WHERE o.id_tenant = 38
      AND o.id_configuracao = 61
)
UPDATE obras.obra_integrante oi
SET
    controlado      = true,
    link            = t.novo_link,
    percentual_pr   = t.pct,
    percentual_mr   = t.pct,
    percentual_sr   = t.pct,
    percentual_base = t.pct
FROM titulares t
WHERE oi.id = t.id;

UPDATE obras.obra o
SET controlada = true
WHERE o.id_tenant = 38
  AND o.id_configuracao = 61
  AND EXISTS (
      SELECT 1
      FROM obras.obra_integrante oi
      JOIN pessoas.pessoa p ON p.id = oi.id_pessoa AND p.id_tenant = 38
      JOIN mdb.titular t ON t.cae = p.codigo
      WHERE oi.id_obra = o.id
  );
```
