# Feature Specification: Importação de obras MDB com titulares (060) e editora Música 360

**Feature Branch**: `001-import-obras-mdb-titular`  
**Created**: 2026-04-04  
**Status**: Draft  
**Input**: User description: "Nova rodada de importação de obras a partir do catálogo MDB (`mdb.sbacem`) para o cadastro de obras do tenant, com percentuais corretos e preenchimento dos vínculos que definem quem é administrado/editado pela editora; inclusão da Música 360 nas obras; uso conjunto de `mdb.titular` e `mdb.titular2` para participantes cuja editoração é atribuída à sociedade **060**, garantindo o **mesmo tipo de vínculo** e a **regra de cessão de percentuais** já acordada para esse cenário (detalhes formais podem ser reexplicados pelo negócio na fase de validação)."

## Clarifications

### Session 2026-04-04

- Q: Qual obra exemplar usar para amarrar regras de importação a um caso concreto? → A: **Obra aleatória `AW0MTYO2` (“ME ENCONTREI”)** extraída de `mdb.sbacem` em produção (amostragem `ORDER BY random() LIMIT 1`), documentada abaixo como referência de validação e smoke test.
- Q: O que significa o `percentual` em `mdb.titular` / `mdb.titular2` em relação à Música 360 e à `sbacem`? → A: É **o quanto o titular cede para a Música 360** no **eixo mecânico (MR)**. No **PR/SR**, o titular mantém a quota da `sbacem` (salvo outra regra); a **Música 360** entra como integrante com **MR = cessão**, **PR/SR = 0**. *Exemplo:* **30%** PR e **30%** MR na `sbacem`, cessão **15%** → titular **30%** PR, **15%** MR; M360 **0** PR, **15%** MR.
- Q: Como ficam **obra**, **integrantes**, **links** (`chain`) e **controles**? → A: Vide **Formato alvo — `AW0MTYO2`** abaixo. **`chain_id` / `chain`** = vínculo na fonte; **mesmo `chain_id`** = mesmo grupo. **Obra `controlada` = true**. **`controle_mr`** na obra = **soma do MR** das participações **Música 360**; **M360** só **MR**, recebendo do **titular cedente** (`mdb.titular`).
- Q: PR/SR/MR na obra vs linha M360 e representação de direitos? → A: **Música 360 representa só MR** na integração; **`controle_mr` da obra** = soma MR das linhas M360; **PR/SR** seguem participantes (SR espelha PR); **cessão** em `titular` afeta **apenas MR** do cedente.
- Q: Qual `cod_categoria` (papel CWR) gravar na linha **Música 360**? → A: Quando existir **pelo menos um** integrante com papel **Editor** (**`E`**, `ip_role` **E** na `sbacem`) **no mesmo `link` numérico** que a linha M360 (spec **002**), a M360 MUST usar **`cod_categoria` = `SE`** (Sub-editor). **Sem** **E** no mesmo link, MUST usar **`E`**. No desenho **agregado** abaixo (uma BOCA **E** + uma M360), a M360 entra como **SE** por estar no víncio do cedente editor.

### Obra exemplar — `AW0MTYO2` (“ME ENCONTREI”)

Fonte: `mdb.sbacem` + cruzamento por `ipi_name_number` = `cae` em `mdb.titular` / `mdb.titular2` (produção, sessão de clarificação).

**Resumo na `mdb.sbacem` (10 linhas, cadeias A–J):**

- Cinco autores/compositores (**CA**), cadeias A–E, com `per_own` / `mec_own` entre **14%** e **15%** e sociedades de performance variando (**ABRAMUS (201)**, **UBC (093)**).
- Editoras (**E**): **BOCA DO ORIENTE** (`ipi_name_number` **00802972439**) repetida nas cadeias **F, G, H** com **6%** PR/MR e **`per_soc` / `mec_soc` = SBACEM (066)**; **UNKNOWN PUBLISHER** (`00288936892`) nas cadeias **I, J** com **5%** e **NS (099)**.

**`mdb.titular` (para CAEs que aparecem nesta obra):**

| CAE | Nome (resumo) | `percentual` |
|-----|----------------|--------------|
| 00802972439 | BOCA DO ORIENTE … | **15%** |

Apenas o CAE da editora com vínculo **SBACEM (066)** na `sbacem` possui linha em `titular` neste exemplo; os autores CA não retornam join com `titular`.

**`mdb.titular2`:** nenhuma linha para os CAEs desta obra neste snapshot.

**Rascunho de regras derivadas do exemplar (sujeitas a confirmação de negócio):**

- **DR-EX-001**: Participantes da obra no destino devem refletir as **linhas da `sbacem`** (incluindo `ip_role`, `per_own`, `mec_own`, sociedades em texto), com política explícita para **múltiplas cadeias** com o **mesmo** `ipi_name_number` e papel (**F/G/H**): deduplicar ou manter sequência conforme contrato com o cliente.
- **DR-EX-002**: O **`percentual`** em **`mdb.titular`** / **`titular2`** é a **cessão de MR** à Música 360: **`MR_titular = MR_sbacem_agregado − cessão`**, **`MR_M360 = cessão`**, **`PR/SR` do titular** seguem a `sbacem` (M360 **0** em PR/SR). Agregação **F+G+H** → **18%** MR e **18%** PR antes da cessão; **UNKNOWN** mantém linhas **I** e **J** (ou agregar por política).
- **DR-EX-003**: Se **`mdb.titular2`** trouxer o mesmo CAE que `titular`, o processo MUST aplicar o **mesmo tratamento de vínculo e cessão** que para `titular` (requisito já alinhado à User Story 4); neste exemplar, `titular2` está vazio e não testa o caso duplo.

**Uso recomendado:** manter `AW0MTYO2` como **caso de regressão** nas evidências **FR-006** (relatório ou consultas) após cada importação.

### Formato alvo — `AW0MTYO2` (“ME ENCONTREI”) após importação

**Regras aplicadas neste desenho:** `chain_id` + `chain` = **link** (mesmo `chain_id` = mesmo grupo). **Cessão** (`mdb.titular`) só **desconta MR** do cedente; **M360** só **MR**; **SR = PR** por linha (padrão legado Woodstock). **BOCA** F+G+H **agregada** num único integrante (**18%** PR, **18%** MR antes da cessão). **`titular2`** vazio neste caso.

**`obras.obra` (uma linha)**

| `codigo` | `titulo` | `controlada` | `controle_pr` | `controle_mr` | `controle_sr` |
|----------|----------|--------------|---------------|---------------|---------------|
| AW0MTYO2 | ME ENCONTREI | **true** | **0** | **15** | **0** |

*`controle_mr` = soma do MR da(s) linha(s) **Música 360** (aqui **15**). PR/SR na obra **0** neste modelo; ajustar no plano se o produto exigir outro preenchimento.*

**`obras.obra_integrante` (formato lógico — ordem = `sequencia`)**

| `sequencia` | **link** `chain_id` | `chain` (fonte) | Participante | `cod_categoria` | PR % | MR % | SR % | Cedente / nota |
|-------------|---------------------|-----------------|--------------|-----------------|------|------|------|----------------|
| 1 | A | *(vazio)* | VINICIUS … | CA | 14 | 14 | 14 | — |
| 2 | B | *(vazio)* | ITALO … | CA | 14 | 14 | 14 | — |
| 3 | C | *(vazio)* | ALEX … | CA | 14 | 14 | 14 | — |
| 4 | D | *(vazio)* | IAASEN … | CA | 15 | 15 | 15 | — |
| 5 | E | *(vazio)* | ENZO … | CA | 15 | 15 | 15 | — |
| 6 | F‒H | *(vazio)* | BOCA DO ORIENTE … | E | **18** | **3** | **18** | MR remanescente após cessão **15%** a M360 |
| 7 | *(novo)* | — | **Música 360** | **SE** | **0** | **15** | **0** | Sub-editor (SE) face ao **E** cedente; MR recebido de **00802972439** (BOCA) — **FR-010** |
| 8 | I | *(vazio)* | UNKNOWN PUBLISHER | E | 5 | 5 | 5 | — |
| 9 | J | *(vazio)* | UNKNOWN PUBLISHER | E | 5 | 5 | 5 | — |

**Conferência:** ΣPR = **100%**; ΣMR = **100%**; ΣSR = **100%** (SR espelha PR).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Catálogo de obras alinhado à fonte MDB (Priority: P1)

Como responsável pela migração do repertório, quero que cada obra representada na fonte MDB passe a existir no cadastro de obras do ambiente de destino com os mesmos identificadores de negócio e metadados essenciais (título, identificadores externos quando houver), para que o cliente possa operar sobre um acervo consistente com o extrato oficial.

**Why this priority**: Sem obras criadas/atualizadas corretamente, nenhum outro ajuste de titularidade ou percentual tem onde se apoiar.

**Independent Test**: Dado um conjunto de obras presentes na fonte MDB, após o processo é possível localizar cada uma no cadastro de obras pelo identificador de negócio acordado e comparar título e dados principais com a fonte.

**Acceptance Scenarios**:

1. **Given** uma obra com identificador único na fonte MDB, **When** o processo de importação é executado para o recorte acordado, **Then** existe exatamente um registro correspondente no cadastro de obras do tenant alvo para esse identificador.
2. **Given** obras que não constam na fonte MDB do job atual, **When** o processo é executado com política de substituição do catálogo SBACEM já definida pelo projeto, **Then** o resultado obedece a essa política (por exemplo remoção prévia ou coexistência), sem obras “órfãs” de regra.

---

### User Story 2 - Percentuais e vínculos editoriais corretos (Priority: P1)

Como gestor editorial, quero que os percentuais de participação e os vínculos que indicam **quem é administrado ou editado pela editora** reflitam as regras do extrato MDB e da sociedade, para que relatórios, repasses e controles contratuais não distorçam titularidade nem editoração.

**Why this priority**: Erro de percentual ou de “quem edita quem” gera risco direto de compliance e de confiança do cliente.

**Independent Test**: Para uma amostra de obras (incluindo casos com vários titulares), os percentuais no cadastro de destino conferem com a fonte MDB após aplicadas as regras de cessão acordadas; os vínculos editoriais esperados aparecem nas telas ou relatórios de verificação definidos pelo projeto.

**Acceptance Scenarios**:

1. **Given** uma obra com várias linhas de participação na fonte, **When** a importação é concluída, **Then** a soma e a distribuição dos percentuais por tipo acordado (performance, mecânica, etc.) batem com a regra de negócio validada em amostra.
2. **Given** um participante que deve constar como sob administração/editoração da editora conforme regra do projeto, **When** a obra é consultada após a importação, **Then** o vínculo editorial esperado está explícito e auditável (mesmo significado para usuários de negócio em todas as obras equivalentes).

---

### User Story 3 - Música 360 como participante nas obras (Priority: P2)

Como operador do catálogo M360, quero que a **Música 360** apareça nas obras conforme a regra do projeto (por exemplo como editora ou titular administrado), para que o repertório no sistema reflita a operação real da editora no conjunto de obras importadas.

**Why this priority**: Garante que o tenant represente a editora corretamente nas obras, condição comum para controle e contratos.

**Independent Test**: Em obras do recorte importado, a Música 360 consta como participante onde a regra de negócio exige, com papel e percentuais coerentes com o desenho aprovado.

**Acceptance Scenarios**:

1. **Given** uma obra elegível pela regra de inclusão da Música 360, **When** a importação termina, **Then** a Música 360 figura na lista de participantes da obra com o papel acordado.
2. **Given** uma obra onde a Música 360 não deve aparecer segundo a regra, **When** a importação termina, **Then** ela não é incluída indevidamente.
3. **Given** um titular com **30%** PR e **30%** MR na `sbacem` e **15%** de cessão em `mdb.titular` (MR) para o mesmo CAE, **When** a importação termina, **Then** o titular permanece com **30%** PR e passa a **15%** MR, e a Música 360 aparece com **0%** PR e **15%** MR (salvo exceção quando **cessão > MR agregado**).
4. **Given** uma linha Música 360 no **mesmo `link`** que um integrante **E** (Editor) da `sbacem`, **When** a importação termina, **Then** o `cod_categoria` da M360 é **`SE`**; **Given** uma M360 **sem** **E** no mesmo link, **Then** o `cod_categoria` é **`E`** (**FR-010**).

---

### User Story 4 - Titulares em `titular` e `titular2` sob sociedade 060 (Priority: P2)

Como analista de dados musicais, quero que participantes identificados nas tabelas de titulares do MDB — inclusive quando aparecem em **mais de uma tabela de titulares** — recebam **o mesmo tratamento de vínculo** quando a editoração é atribuída à sociedade **060**, e que a **regra de cessão de percentuais** seja aplicada de forma uniforme, para não haver divergência entre fontes equivalentes.

**Why this priority**: Duplicidade de fonte (`titular` vs `titular2`) sem regra única gera percentuais ou vínculos divergentes entre obras similares.

**Independent Test**: Para titulares presentes só em uma tabela e para titulares espelhados ou complementares entre tabelas, o resultado final de vínculo e percentual é o mesmo sempre que a regra de negócio declara equivalência para a sociedade 060.

**Acceptance Scenarios**:

1. **Given** o mesmo participante ou situação descrita em `titular` e em `titular2` com papel de editoração pela sociedade 060, **When** a importação roda, **Then** o cadastro de destino não apresenta vínculos ou percentuais conflitantes entre os dois casos.
2. **Given** apenas uma das tabelas contém o titular para uma obra, **When** a importação roda, **Then** o participante ainda é tratado corretamente segundo a regra única definida para 060.

---

### Edge Cases

- Obra na fonte MDB **sem** linhas de titular nas tabelas consultadas: definir comportamento (bloquear obra, importar sem titulares, ou escalar para revisão manual).
- **Percentuais que não fecham 100%** ou valores ausentes/inválidos na fonte: regra de arredondamento ou rejeição com relatório de exceções.
- **Mesmo identificador de obra** com linhas conflitantes na fonte: critério de desempate ou agregação documentado.
- Participante com **múltiplos papéis** na mesma obra: não duplicar vínculos indevidamente nem somar percentuais duas vezes.
- **Mesmo participante e papel** em **várias cadeias** (`chain_id` distintos) na `sbacem` — ex.: editora repetida em F, G, H no exemplar `AW0MTYO2`: definir se gera um único integrante agregado, vários com sequência, ou outra regra contratual.
- Conjunto MDB **parcial** (subconjunto de obras) vs catálogo já existente: política explícita de substituição ou convivência.
- **Cessão MR em `titular` maior que o MR agregado** do mesmo participante na `sbacem`: não subtrair sem decisão — **relatório de exceção** ou agregação **F+G+H** (vide **AW0MTYO2**).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O processo MUST criar ou atualizar registros de obra no cadastro de destino para cada obra do recorte definido na fonte MDB (`sbacem`), preservando o identificador de negócio acordado entre fonte e destino.
- **FR-002**: O processo MUST calcular e gravar percentuais de participação no destino de acordo com as regras de cessão e formatação acordadas com o negócio (incluindo tratamento de separadores decimais e valores não numéricos da fonte).
- **FR-003**: O processo MUST preencher os vínculos ou flags que determinam **quem é administrado ou editado pela editora**, de forma que o resultado seja auditável e consistente entre obras equivalentes.
- **FR-004**: O processo MUST incluir a **Música 360** nas obras quando houver cessão em `mdb.titular`/`titular2`, com **MR = cessão** e **PR/SR = 0** na linha da M360 e **`cod_categoria`** conforme **FR-010**; MUST gravar a obra como **`controlada = true`** e **`controle_mr`** = **soma do MR** das participações **Música 360** (PR/SR em nível obra **0** neste desenho, salvo ajuste de produto).
- **FR-005**: O processo MUST considerar conjuntamente os dados de **`mdb.titular`** e **`mdb.titular2`** ao montar titularidade para obras com editoração atribuída à sociedade **060**, aplicando o **mesmo modelo de vínculo** e a **mesma regra de cessão de percentuais** para situações que o negócio considera equivalentes entre essas fontes.
- **FR-006**: O processo MUST produzir evidências de verificação (relatório ou consultas de contagem) que permitam comparar quantidade de obras na fonte vs destino e listar exceções (obras sem titular, percentuais inválidos, etc.).
- **FR-007**: O processo MUST ser executável de forma repetível no mesmo ambiente, com resultado previsível dado o mesmo snapshot da fonte MDB e as mesmas regras de parâmetros (tenant, configuração, recorte).
- **FR-008**: Quando `mdb.titular` (e `mdb.titular2` com o **mesmo significado**) trouxer **`percentual`** de cessão para o CAE do cedente, o processo MUST aplicar a cessão **somente no eixo MR**: **(1)** **Música 360** integrante com **MR = cessão**, **PR = SR = 0**; **(2)** cedente com **PR (e SR)** iguais à `sbacem` e **MR = MR_sbacem_agregado − cessão** quando **cessão ≤ MR agregado**; **(3)** se **cessão > MR** por **linha** isolada, **agregar** MR do mesmo CAE+papel na obra ou **exceção** documentada.
- **FR-009**: O processo MUST preservar o **link** da fonte: **`chain_id`** e **`chain`** da `mdb.sbacem` de forma **auditável** no destino (campo, nota ou agrupamento explícito — ex.: coluna auxiliar, `sequencia` por cadeia, ou metadado de importação), de modo que participantes com o **mesmo `chain_id`** permaneçam identificáveis como **mesmo grupo**.
- **FR-010**: O processo MUST gravar **`cod_categoria`** da **Música 360** como **`SE`** (Sub-editor, CWR) quando existir **pelo menos um** integrante da obra com **`cod_categoria` = `E`** (origem `ip_role` **E** na `mdb.sbacem`) **no mesmo `link` numérico** que a linha M360 (definição de **link** na spec **002**). Se **não** houver **E** nesse link, MUST gravar **`E`**. No modelo **agregado** (sem repartir BOCA por link), MUST tratar como **SE** quando o cedente da cessão for participante **E** na obra.

### Key Entities *(include if feature involves data)*

- **Obra (fonte MDB)**: conjunto de linhas por identificador de obra; título principal, possíveis títulos alternativos, metadados de obra.
- **Obra (cadastro destino)**: registro único por identificador de negócio no tenant; vínculo com participantes e flags de controle editorial.
- **Titular MDB (`titular` / `titular2`)**: por CAE; **`percentual`** = **cedido à Música 360 no eixo MR** (quota PR vem só da `sbacem`).
- **Participante / integrante (destino)**: pessoa ou entidade ligada à obra com papéis e percentuais; inclui a editora Música 360 quando aplicável.
- **Sociedade 060**: critério de negócio que agrupa titulares cuja editoração e cessão seguem a mesma regra entre as duas tabelas de titulares.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Para uma amostra aleatória ou estratificada de pelo menos **50 obras** do recorte importado, **100%** dos percentuais auditados conferem com a fonte MDB após aplicação das regras de cessão documentadas (tolerância de arredondamento acordada, se houver, documentada à parte).
- **SC-002**: **100%** das obras do recorte MDB possuem registro correspondente no cadastro de obras do tenant alvo, ou aparecem explicitamente em relatório de exceção com motivo classificado (ex.: dado inválido, obra sem titular).
- **SC-003**: Em **100%** dos casos de teste definidos para titulares sob sociedade **060** presentes em `titular` e `titular2`, o vínculo editorial e os percentuais resultantes são **idênticos** quando o negócio classifica os casos como equivalentes.
- **SC-004**: Em **100%** das obras do conjunto de teste onde a Música 360 deve constar, ela aparece como participante; em **100%** das obras do conjunto onde não deve constar, ela não aparece.
- **SC-005**: O time de migração conclui a verificação pós-importação (contagens + amostra de titulares) em **uma única sessão de trabalho** sem necessidade de correção manual em massa além das exceções já previstas no relatório.
- **SC-006**: A obra **`AW0MTYO2`** no destino tem **`controlada`**, **`controle_mr` = 15**, integrantes e **links `chain_id`** conforme **Formato alvo** na spec; somas **PR/MR/SR** fecham **100%**; linha **Música 360** com **`cod_categoria` = `SE`** quando houver **E** cedente no víncio (**FR-010**).

## Assumptions

- O **tenant** e a **configuração** de destino seguem os já utilizados no projeto de migração M360 (identificadores conhecidos pela equipe); alterações exigem atualização explícita desta especificação.
- **`mdb.titular` / `titular2`.`percentual`** = **cessão de MR** à M360; **PR/SR** do cedente **inalterados** na `sbacem`; **M360** só **MR**; **obra** **controlada** com **`controle_mr`** = soma MR M360; **`chain_id`/`chain`** = vínculo entre participantes (**confirmado** sessão 2026-04-04).
- O código **060** refere-se à sociedade/editoração indicada no MDB como referência do projeto (SBACEM no contexto brasileiro); se a nomenclatura interna diferir (066 vs 060), o número efetivo usado na fonte será o parâmetro de negócio durante a implementação.
- A **Música 360** corresponde à editora padrão já cadastrada no tenant de destino; seu identificador interno é conhecido pela equipe técnica e não precisa constar nesta especificação voltada a stakeholders.
- **`SE` vs `E` na M360:** **SE** evita duplicar o papel **Editor** no mesmo **link** quando já existe linha **E** (alinhado ao CWR: sub-editor em relação ao editor).
- O snapshot da fonte MDB usado no job é **consistente** (carga prévia validada); inconsistências de arquivo são tratadas como exceções reportadas, não silenciadas.
