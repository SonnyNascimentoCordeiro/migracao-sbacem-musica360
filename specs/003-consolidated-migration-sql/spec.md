# Feature Specification: Migração staging em um único arquivo SQL

**Feature Branch**: `003-consolidated-migration-sql`  
**Created**: 2026-04-04  
**Status**: Draft  
**Input**: User description: "eu quero os SQLs, apenas os SQLs para executar em um arquivo, essa migracao ficou muito complexa pra eu poder executar"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Executar preparação de dados sem vários passos manuais (Priority: P1)

Como operador da migração, quero aplicar **toda a sequência necessária** para montar o **staging** (cópia enriquecida da fonte com links e cessão MR) **de uma vez**, para reduzir erro de ordem e dependência de scripts auxiliares.

**Why this priority**: Sem isso, o risco de pular um arquivo ou rodar fora de ordem invalida o resultado e gera retrabalho.

**Independent Test**: Dado um banco com a fonte MDB carregada, após **uma única execução** do artefato combinado, o staging contém linhas populadas, links atribuídos e MR ajustado conforme as regras já acordadas nas specs **001**/**002**.

**Acceptance Scenarios**:

1. **Given** o operador possui credenciais no banco e a fonte `mdb.sbacem` (e titulares) disponível, **When** executa o **único arquivo** oficial da migração staging **uma vez**, **Then** o processo completa sem exigir abrir outros arquivos na mesma sessão para o mesmo fluxo.
2. **Given** a execução termina com sucesso, **When** o operador consulta o staging, **Then** existem registros por obra com `numero_link` preenchido e, quando aplicável, `ref_titular_nome` e MR do cedente reduzido pela cessão.

---

### User Story 2 - Confiança sobre o que o script altera (Priority: P1)

Como gestor de dados, quero que fique **explícito** que o script **não remove** dados de cadastro de obras ou pessoas no destino final, para autorizar execução em ambientes sensíveis com clareza.

**Why this priority**: Medo de `DELETE` indevido bloqueia adoção da migração.

**Independent Test**: Revisão do artefato (cabeçalho e operações) confirma que **não há** remoção de dados nas tabelas de negócio do Woodstock; apenas recriação/truncagem da **área de trabalho** `migracao_stg`.

**Acceptance Scenarios**:

1. **Given** o documento de entrega descreve o escopo do script, **When** a equipe de dados valida, **Then** confirma-se que alterações destrutivas limitam-se ao **staging** (`migracao_stg`), não a `obras`/`pessoas` de produção neste arquivo.

---

### User Story 3 - Manter paridade com a sequência já definida (Priority: P2)

Como responsável técnico, quero que o arquivo único seja **equivalente** à ordem já documentada em `SEQUENCIA_EXECUCAO.txt` / specs anteriores, para não haver duas “verdades” divergentes.

**Why this priority**: Duas ordens diferentes geram bugs difíceis de auditar.

**Independent Test**: Comparar a ordem lógica do arquivo único com a lista oficial de passos; devem coincidir para o escopo **staging** (até aplicar cessão MR).

**Acceptance Scenarios**:

1. **Given** a lista numerada de scripts antigos, **When** se compara com o arquivo consolidado, **Then** a sequência de operações é a mesma para o bloco staging.

---

### Edge Cases

- Falha no meio da execução: o banco pode ficar com staging parcialmente atualizado; política de **reexecução** do mesmo arquivo (que recria/trunca staging no início do bloco relevante) deve ser documentada no cabeçalho do artefato.
- Diferenças de DDL na fonte (`mdb.titular`): colunas distintas exigem ajuste pontual no arquivo único ou retorno aos scripts modulares.
- Execução em ferramenta gráfica vs. linha de comando: o artefato deve ser válido como **script SQL único** nos dois modos.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O projeto MUST fornecer **um único arquivo SQL** que execute, em sequência fixa, todas as etapas do **pipeline de staging** descrito nas especificações **002** (links, nome do titular referenciado, cessão MR no staging), sem depender de runner Python ou PowerShell para esse fluxo.
- **FR-002**: O arquivo MUST incluir, no cabeçalho, **instruções mínimas** de execução e **aviso de segurança** sobre o que é truncado/recriado (apenas `migracao_stg`).
- **FR-003**: O conteúdo MUST ser **equivalente** à concatenação ordenada dos scripts modulares já existentes para o escopo staging (paridade verificável).
- **FR-004**: A carga em **tabelas finais** de obras/pessoas (`INSERT` no cadastro Woodstock) permanece **fora** deste arquivo até o DDL estar fechado; o escopo deste entregável é explicitamente **até staging + views + ajuste MR no staging**.

### Key Entities

- **Artefato único**: arquivo SQL versionado, ponto de entrada para operadores.
- **Staging (`migracao_stg`)**: tabela e views de apoio à migração, recriáveis.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: **100%** dos passos do staging listados na sequência oficial aparecem **no mesmo arquivo**, na ordem correta, sem omissão.
- **SC-002**: Um novo operador consegue concluir o fluxo staging seguindo **apenas** o cabeçalho do arquivo e **uma** execução, sem consultar mais de **um** artefato SQL para esse bloco.
- **SC-003**: A revisão de impacto (dados de negócio) leva **menos de 5 minutos** porque o cabeçalho declara claramente o que é afetado.

## Assumptions

- A fonte MDB (`mdb.sbacem`, `mdb.titular`, `mdb.titular2`) está no **mesmo** banco que o schema `migracao_stg`.
- Operadores têm permissão para `CREATE SCHEMA`, `CREATE VIEW`, `TRUNCATE` e `UPDATE` em `migracao_stg`.
- Manutenção futura: alterações de regra devem atualizar **tanto** os scripts modulares **quanto** o arquivo único, ou gerar o único a partir dos modulares (processo a definir na implementação).
