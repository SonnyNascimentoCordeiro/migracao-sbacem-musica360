# Feature Specification: Conversão de links de cadeia (MDB) para link numérico no catálogo

**Feature Branch**: `002-chain-link-numeric`  
**Created**: 2026-04-04  
**Status**: Draft  
**Input**: User description: (1) **Seq** não define víncio editorial; **link** sim; **`chain`** na editora aponta ao **`chain_id` do titular**; mesma editora em várias linhas (F→A, G→B, H→C) com **links distintos** 1,2,3; nome do titular visível na linha editorial. (2) **Música 360:** para cada **titular controlado** identificado em **`mdb.titular`** e **`mdb.titular2`**, **incluir Música 360** na obra com o **mesmo número de `link`** que o **titular** (participação da obra correspondente ao CAE/IPI). **Percentuais** (cessão MR, PR/SR, `controlada`, `controle_mr` na obra) permanecem conforme **spec 001** — não contradizer essa regra."

## Glossário — semântica na fonte MDB (`mdb.sbacem`)

| Conceito (fonte) | Significado de negócio |
|------------------|-------------------------|
| **`chain_id`** | Letra (ou código) que **identifica aquela linha** na cadeia da obra. |
| **`chain`** | Na linha de uma **editora**, valor que **igual ao `chain_id` de outra linha** = aquela editora **edita o titular** da linha cujo `chain_id` coincide. **Vazio** = sem referência explícita a titular nesta linha. |

## O que **não** é critério de víncio

- **`sequencia` / `seq` (ordem na tela ou insert):** não determina **quem edita quem**; serve no máximo a **ordenação** ou convenções de UI. A **regra editorial** vem só de **`chain` → `chain_id` do titular** + **link numérico** no destino.

## Conversão — link numérico no destino (Woodstock)

| Conceito (destino) | Significado de negócio |
|--------------------|-------------------------|
| **Link** | Inteiro **compartilhado** pelo **titular** e pela(s) linha(s) **editora(s)** que, na fonte, apontam para ele via **`chain`**. |
| **Uma editora, várias linhas** | Quando o mesmo IPI/nome de editora aparece em **várias linhas** com **`chain`** distintos (F→A, G→B, H→C), são **várias participações distintas**, cada uma com **link diferente** correspondente ao **titular** editado. |
| **Nome do titular na participação editorial** | O cadastro/exibição MUST deixar claro **qual titular** aquela linha editorial representa (ex.: “BOCA — edita **VINICIUS …**”). |
| **Titular controlado** | Participante da obra cujo **CAE/IPI** aparece em **`mdb.titular` ou `mdb.titular2`** com a política de **cessão / controle** da spec **001** (inclui tratamento idêntico entre as duas tabelas quando o mesmo CAE existir nas duas). |
| **Música 360 na obra** | Participação **adicional** por **titular controlado**; **obrigatoriamente o mesmo `link`** que a linha desse titular na obra (o víncio visual e contratual fica no mesmo grupo que o titular). Se no **mesmo link** existir **Editor (`E`)**, a M360 usa **`cod_categoria` = `SE`** (Sub-editor); caso contrário **`E`** — spec **001**, **FR-010**. |

**Algoritmo de negócio (alto nível — plano técnico detalha ordem e colisões):**

1. Para cada linha com **`chain` preenchido**, localizar a linha da mesma obra cujo **`chain_id` = `chain`**. Isso forma o **par titular–editora**; titular e editora recebem o **mesmo `link`**.  
2. **Numerar links** de forma **estável e quase sequencial** (ex.: ordenar pares pelo `chain_id` do titular em ordem A,B,C… e atribuir 1, 2, 3…).  
3. Linhas **titulares** cujo `chain_id` **não** é valor de **`chain`** em nenhuma outra linha (ninguém “os edita” no extrato) recebem **um link inteiro cada**, **distinto** dos pares e entre si (continuando a sequência ou por política documentada).  
4. Linhas **editoras** com **`chain` vazio** seguem **política de fallback** (exceção, link isolado, ou enriquecimento manual) — **FR-004**.  
5. **Titular controlado (`titular` / `titular2`):** para cada CAE listado com cessão aplicável, após resolver a **linha de participação** na obra com esse `ipi_name_number` (ou equivalente), **inserir Música 360** com **o mesmo `link`** dessa linha. Gravar **`cod_categoria` = `SE`** se houver **`E`** no mesmo link; senão **`E`** (**FR-010** / spec **001**). **Percentuais MR** da M360 e remanescente do titular seguem **spec 001** (cessão só em **MR**; PR/SR do titular pela `sbacem`; obra **`controlada`** e **`controle_mr`** conforme 001).  
6. Se um **mesmo CAE** aparece em **várias linhas** na obra com **links diferentes** (ex.: três linhas BOCA em links 1, 2, 3), o plano técnico MUST definir **rateio da cessão** entre linhas M360 ou **uma única** linha M360 — **desde que** cada linha M360 mantenha **link idêntico** ao do **titular do grupo** que está sendo controlado em cada víncio (ver exemplo abaixo).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Par titular–editora com mesmo link (Priority: P1)

Como migrador, quero que cada par **titular + linha editorial que aponta para ele** receba o **mesmo número de link**, para refletir fielmente o MDB.

**Why this priority**: É o núcleo da conversão.

**Independent Test**: Obra com F→A, G→B, H→C produz três links distintos; em cada par, titular e editora têm o mesmo inteiro.

**Acceptance Scenarios**:

1. **Given** titular `chain_id=A` e linha editora com `chain=A`, **When** a importação atribui links, **Then** **ambas** têm **link 1** (se forem o primeiro par na ordem acordada).  
2. **Given** a mesma editora em três linhas com `chain` A, B e C, **When** a importação conclui, **Then** existem **três participações editoriais** com **links 1, 2 e 3** (ou ordem equivalente), **não** um único link para as três.

---

### User Story 2 - Nome do titular visível na linha editorial (Priority: P1)

Como usuário do catálogo, quero ver **qual titular** cada linha editorial trata, para não confundir três linhas da mesma editora.

**Why this priority**: Três linhas “BOCA” sem contexto são ambíguas.

**Independent Test**: Cada linha editorial exibe ou associa o **nome do titular** referenciado pelo `chain`.

**Acceptance Scenarios**:

1. **Given** linha F com `chain=A`, **When** consulto a participação no destino, **Then** identifico o titular **VINICIUS** (ou nome da linha A) como **editado por** aquela linha.

---

### User Story 3 - Titulares sem editor e fallback (Priority: P2)

Como operador, quero que titulares **sem** nenhuma linha com `chain` apontando para eles recebam **link próprio** e que linhas editoras **sem** `chain` tenham tratamento explícito.

**Why this priority**: Evita vínculos falsos.

**Independent Test**: D e E sem referência recebem links únicos; relatório cobre editoras sem `chain` se política exigir.

**Acceptance Scenarios**:

1. **Given** `chain_id=D` e nenhuma linha com `chain=D`, **When** importação termina, **Then** o titular D tem link **não compartilhado** com F/G/H.

---

### User Story 4 - Música 360 por titular controlado (Priority: P1)

Como gestor do catálogo M360, quero que **cada titular** que constar em **`mdb.titular` ou `mdb.titular2`** como sujeito à cessão/controle gere **uma participação Música 360** na obra, com o **mesmo link** desse titular e **percentuais** coerentes com a spec **001**, para que controle mecânico e víncio editorial fiquem alinhados.

**Why this priority**: Sem M360 por titular controlado, a cessão documentada nas tabelas `titular`/`titular2` não aparece no destino por víncio correto.

**Independent Test**: Obra onde três autores têm entrada em `titular2` gera três linhas M360 com links iguais aos três autores respectivos; MR fecha conforme regra de cessão.

**Acceptance Scenarios**:

1. **Given** CAE do titular presente em `mdb.titular` com cessão MR, **When** a obra é importada, **Then** existe linha **Música 360** com **mesmo link** que a participação desse titular e **MR** da cessão conforme **001**.  
2. **Given** o mesmo CAE em `titular` e `titular2`, **When** a importação aplica a regra, **Then** **não** há tratamento divergente entre as duas fontes para o mesmo víncio (mesma lógica de link e cessão).

---

### Edge Cases

- **`chain`** referencia `chain_id` **inexistente** na obra: inconsistência reportada.  
- **Vários editores** com `chain` apontando para o **mesmo** titular: **mesmo link** para titular e **todos** esses editores (confirmar com negócio).  
- **Mesmo `chain_id` duplicado** em duas linhas titulares: regra de desempate antes de resolver `chain`.  
- **Música 360** com **vários links** para o **mesmo CAE** (várias linhas editoriais): rateio de cessão MR ou linha única — **decisão no plano** (item **6** do algoritmo).  
- **Titular em `titular`/`titular2`** **sem** linha correspondente na `sbacem` da obra: exceção ou política de criação de participante — documentar.
- **M360** no link **sem** linha **E** (cenário raro): `cod_categoria` **`E`** por **FR-010**; validar no plano se exige relatório.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Para cada linha com **`chain` não vazio**, o processo MUST resolver o **titular** pela linha com `chain_id = chain` e MUST gravar o **mesmo link numérico** no titular e na linha editorial.  
- **FR-002**: O processo MUST **numerar links** de forma **quase sequencial** por obra, com ordem **determinística** documentada (ex.: ordem lexicográfica do `chain_id` do titular no par).  
- **FR-003**: O processo MUST **não** usar **`sequencia`/`seq`** como substituto da regra de **`chain` + link** para definir víncio editorial.  
- **FR-004**: Linhas com **`chain` vazio** MUST seguir política de fallback aprovada (link isolado, exceção, ou manual).  
- **FR-005**: Cada participação editorial MUST permitir identificar o **nome do titular** vinculado (via `chain` resolvido).  
- **FR-006**: Para cada participante da obra classificado como **titular controlado** (CAE em **`mdb.titular` ou `mdb.titular2`** conforme spec **001**), o processo MUST inserir **Música 360** com **`link` idêntico** ao dessa participação.  
- **FR-007**: Os **percentuais** (incluindo **cessão MR**, **PR/SR** do titular, flags **`controlada`** e **`controle_mr`** na obra) MUST obedecer integralmente à **spec 001**; esta spec **002** só fixa **links e pares chain** sem alterar a matemática de cessão.  
- **FR-008**: Quando **`titular` e `titular2`** trouxerem o **mesmo CAE**, o processo MUST aplicar **uma única** lógica de cessão e **um único** conjunto de linhas M360 por titular na obra (sem duplicar cessão por causa da dupla tabela).  
- **FR-009**: Validar existência do `chain_id` referenciado em **`chain`**.  
- **FR-010**: O **`cod_categoria`** da **Música 360** MUST seguir **spec 001**, **FR-010**: **`SE`** quando existir **`E`** no **mesmo `link`**; **`E`** quando não houver **`E`** nesse link.

### Key Entities *(include if feature involves data)*

- **Par editorial**: (titular `chain_id` T, linha editora L onde `chain=T`).  
- **Participação destino**: **link** inteiro + dados do participante; **sem** depender de seq para víncio.  
- **Grupo de link**: conjunto de linhas que compartilham o mesmo inteiro **por** par ou regra de multi-editor.  
- **Titular controlado + M360**: par lógico (titular na obra, M360) com **mesmo link** e MR da **cessão** das tabelas `titular` / `titular2`.

## Exemplo — obra **`AW0MTYO2`** (“ME ENCONTREI”) — dados reais (`chain` preenchido)

Fonte conforme extrato (imagem / MDB): F→A, G→B, H→C; A–E titulares com `chain` vazio; I,J UNKNOWN com `chain` vazio.

**Ordem de numeração de links (exemplo):** pares por titular A,B,C → **1,2,3**; titulares sem editor D,E → **4,5**; UNKNOWN I,J → **6,7**. *(A ordem exata D/E/I/J pode ser ajustada no plano desde que seja determinística.)*

**Tabela — víncio (sem usar `seq` como regra de negócio)**

| `chain_id` | `chain` | Participante (exibição sugerida) | **Link** |
|------------|---------|-----------------------------------|----------|
| A | *(vazio)* | VINICIUS GUIMARAES … (titular) | **1** |
| F | A | BOCA DO ORIENTE … — edita **VINICIUS** | **1** |
| B | *(vazio)* | ITALO LOPES PICOLI (titular) | **2** |
| G | B | BOCA … — edita **ITALO** | **2** |
| C | *(vazio)* | ALEX LOUREIRO … (titular) | **3** |
| H | C | BOCA … — edita **ALEX** | **3** |
| D | *(vazio)* | IAASEN … (titular, sem editor referenciando D) | **4** |
| E | *(vazio)* | ENZO … (titular, sem editor referenciando E) | **5** |
| I | *(vazio)* | UNKNOWN PUBLISHER | **6** |
| J | *(vazio)* | UNKNOWN PUBLISHER | **7** |

**Música 360 e `titular` / `titular2` (exemplo AW0MTYO2):** no snapshot já visto, só o CAE **00802972439** (BOCA) consta em **`mdb.titular`** com cessão **15%** MR. As **três** linhas BOCA têm **links 1, 2 e 3** distintos (cada uma com o autor A/B/C). **Regra desejada:** **uma linha Música 360 por `link`** em que há titular controlado — aqui **três** linhas M360 com **links 1, 2 e 3** respectivamente, **MR** rateado a partir da cessão total (**15%**) em partes **iguais (5% + 5% + 5%)** *ou* outra regra aprovada no plano, **desde que** a soma MR das M360 e o remanescente dos titulares feche **100%** conforme **001**. Se no futuro **autores** A/B/C também aparecerem em **`titular2`**, cada um recebe **M360** no **seu** link (1, 2 ou 3) com MR da **sua** cessão.

**Obra:** `controlada = true`, **`controle_mr`** = soma MR das M360 — spec **001**.

**Tabela complementar — só linhas Música 360 (exemplo AW0MTYO2, CAE BOCA em `titular`)**

Cada link **1–3** já contém **BOCA** como **E** → M360 com **`cod_categoria` = `SE`** (**FR-010**).

| Participante | **Link** | `cod_categoria` | MR % (ex.: rateio 15% ÷ 3) | PR / SR |
|--------------|----------|-----------------|----------------------------|---------|
| Música 360 (víncio Vinícius) | **1** | **SE** | **5** | **0** |
| Música 360 (víncio Italo) | **2** | **SE** | **5** | **0** |
| Música 360 (víncio Alex) | **3** | **SE** | **5** | **0** |

*Os **MR** dos autores A/B/C e das três BOCA devem ser recalculados para, com as três M360, manter **ΣMR = 100%** na obra — ver **001** (cessão por linha `sbacem` 6% cada + remanescente). O plano técnico fecha a planilha completa.*

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Em **100%** dos casos de teste com pares F/A, G/B, H/C, **três** inteiros de link distintos e **dois** registros por inteiro (titular + editora).  
- **SC-002**: **0** casos em que a mesma editora com três `chain` distintos receba **um único** link para as três linhas **sem** decisão documentada.  
- **SC-003**: **100%** das linhas editorais de teste exibem ou associam o **nome do titular** referenciado.  
- **SC-004**: Titulares D e E com links **≠** 1, 2 e 3 (não entram no grupo BOCA–A/B/C).  
- **SC-005**: Em **100%** dos casos de teste com titular controlado em `titular`/`titular2`, a linha **Música 360** existe, **`link` = link do titular** correspondente e **`cod_categoria`** = **`SE`** se houver **`E`** no mesmo link (**FR-010**).  
- **SC-006**: **Soma MR** de titulares + M360 + demais participantes = **100%** após aplicar **001** e links desta spec.

## Assumptions

- Ordem **4,5,6,7** para D, E, I, J é **exemplo**; pode ser outra ordem determinística.  
- Se `chain` listar **vários** titulares num único campo no futuro, o plano técnico define parsing — formato atual é **um** `chain_id` por linha.  
- Complementa **spec 001**; **percentuais e cessão** são **fonte da verdade** na **001**.  
- Rateio de **uma** cessão única em **vários links** (ex.: BOCA 15% em três linhas) é **parâmetro de plano**; default de exemplo: **partes iguais** por link M360.

## Clarifications

### Session 2026-04-04

- Q: Diferença `chain_id` / `chain` e conversão numérica? → A: **`chain` na editora** aponta para **`chain_id` do titular**; **mesmo link** no par; **seq irrelevante** para víncio.  
- Q: Vários BOCA na mesma obra? → A: **Uma linha por titular** editado; **links 1, 2, 3** com A, B, C no exemplo **AW0MTYO2**.  
- Q: (correção dados reais) → A: Tabela atualizada com **F→A, G→B, H→C**; removida agregação incorreta de coautores no mesmo link.  
- Q: Música 360, `titular`/`titular2`, link e percentual? → A: **Uma M360 por titular controlado** (CAE nas tabelas), **mesmo `link`** que o titular na obra; **MR/PR/SR e obra `controlada`/`controle_mr`** pela **spec 001**; `titular`+`titular2` mesmo CAE sem duplicar lógica (**FR-008**).  
- Q: Papel CWR da M360 com **E** no mesmo link? → A: **`cod_categoria` = `SE`** (Sub-editor); sem **E** no link, **`E`** — **FR-010** (spec **001**).
