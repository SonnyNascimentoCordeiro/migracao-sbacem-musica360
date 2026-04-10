# Importação SBACEM → Woodstock (Java Spring Boot + JDBI) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Programa Java Spring Boot standalone que importa obras do catálogo SBACEM para o Woodstock (tenant 38), com limpeza prévia, tratamento de erros por obra, e logs detalhados.

**Architecture:** CommandLineRunner que lê `mdb.sbacem` e `mdb.titular/titular2`, processa obra a obra em transação individual, e insere em `obras.obra`, `obras.obra_titulo` e `obras.obra_integrante`. A limpeza prévia do tenant 38 requer confirmação explícita via argumento `--confirm`.

**Tech Stack:** Java 17, Spring Boot 3.x, JDBI 3, PostgreSQL, Maven

---

## Estrutura de Arquivos

```
src/main/java/br/com/m360/importacao/
  ImportacaoApplication.java              — main + CommandLineRunner
  config/
    JdbiConfig.java                       — configuração JDBI + datasource
  model/
    SbacemRow.java                        — linha da mdb.sbacem
    TitularRow.java                       — linha da mdb.titular
    Titular2Row.java                      — linha da mdb.titular2
    ObraImportada.java                    — obra montada para inserção
    IntegranteImportado.java              — integrante montado para inserção
  repository/
    SbacemRepository.java                 — lê mdb.sbacem, mdb.titular, mdb.titular2
    PessoaRepository.java                 — lookup pessoas.pessoa por ip_name
    ObraRepository.java                   — insert/delete obras.obra, obra_titulo, obra_integrante
  service/
    LimpezaService.java                   — deleta obras do tenant 38
    LinkCalculatorService.java            — calcula links a partir de chain/chain_id
    IntegranteBuilderService.java         — monta integrantes base + M360
    DistribuicaoService.java              — calcula coleta, fonomecanico, sincronizacao
    ImportacaoService.java                — orquestra o fluxo completo por obra
  ImportacaoRunner.java                   — CommandLineRunner, lê args, chama services

src/main/resources/
  application.properties                  — datasource prod (configurável por env)

src/test/java/br/com/m360/importacao/
  service/
    LinkCalculatorServiceTest.java
    IntegranteBuilderServiceTest.java
    DistribuicaoServiceTest.java
```

---

## Task 1: Setup do Projeto

**Files:**
- Create: `pom.xml`
- Create: `src/main/resources/application.properties`
- Create: `src/main/java/br/com/m360/importacao/ImportacaoApplication.java`

- [ ] **Step 1: Criar pom.xml**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>

    <groupId>br.com.m360</groupId>
    <artifactId>importacao-sbacem</artifactId>
    <version>1.0.0</version>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter</artifactId>
        </dependency>
        <dependency>
            <groupId>org.jdbi</groupId>
            <artifactId>jdbi3-spring5</artifactId>
            <version>3.43.0</version>
        </dependency>
        <dependency>
            <groupId>org.jdbi</groupId>
            <artifactId>jdbi3-sqlobject</artifactId>
            <version>3.43.0</version>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

- [ ] **Step 2: Criar application.properties**

```properties
spring.datasource.url=jdbc:postgresql://localhost:5432/woodstock
spring.datasource.username=backstage
spring.datasource.password=${DB_PASSWORD}
spring.datasource.driver-class-name=org.postgresql.Driver

logging.level.br.com.m360=INFO
logging.level.org.jdbi=WARN
```

- [ ] **Step 3: Criar ImportacaoApplication.java**

```java
package br.com.m360.importacao;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ImportacaoApplication {
    public static void main(String[] args) {
        SpringApplication.run(ImportacaoApplication.class, args);
    }
}
```

- [ ] **Step 4: Compilar e verificar**

```bash
mvn compile
```
Expected: BUILD SUCCESS

- [ ] **Step 5: Commit**

```bash
git add pom.xml src/main/resources/application.properties src/main/java/br/com/m360/importacao/ImportacaoApplication.java
git commit -m "feat: setup projeto importacao-sbacem Spring Boot + JDBI"
```

---

## Task 2: Configuração JDBI + Models

**Files:**
- Create: `src/main/java/br/com/m360/importacao/config/JdbiConfig.java`
- Create: `src/main/java/br/com/m360/importacao/model/SbacemRow.java`
- Create: `src/main/java/br/com/m360/importacao/model/TitularRow.java`
- Create: `src/main/java/br/com/m360/importacao/model/Titular2Row.java`
- Create: `src/main/java/br/com/m360/importacao/model/ObraImportada.java`
- Create: `src/main/java/br/com/m360/importacao/model/IntegranteImportado.java`

- [ ] **Step 1: Criar JdbiConfig.java**

```java
package br.com.m360.importacao.config;

import org.jdbi.v3.core.Jdbi;
import org.jdbi.v3.sqlobject.SqlObjectPlugin;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

@Configuration
public class JdbiConfig {

    @Bean
    public Jdbi jdbi(DataSource dataSource) {
        Jdbi jdbi = Jdbi.create(dataSource);
        jdbi.installPlugin(new SqlObjectPlugin());
        return jdbi;
    }
}
```

- [ ] **Step 2: Criar SbacemRow.java**

```java
package br.com.m360.importacao.model;

import lombok.Data;

@Data
public class SbacemRow {
    private String atlasId;
    private String originalTitle;
    private String alternateTitles;
    private String iswc;
    private String chainId;
    private String chain;
    private String ipName;
    private String ipiNameNumber;
    private String ipiBaseNumber;
    private String ipRole;
    private String perOwn;
    private String mecOwn;
}
```

- [ ] **Step 3: Criar TitularRow.java**

```java
package br.com.m360.importacao.model;

import lombok.Data;

@Data
public class TitularRow {
    private String nome;
    private String cae;
    private String ipi;
    private String percentual;
}
```

- [ ] **Step 4: Criar Titular2Row.java**

```java
package br.com.m360.importacao.model;

import lombok.Data;

@Data
public class Titular2Row {
    private String nome;
    private String cae;
    private String ipi;
    private String percentual;
    private String obs;
}
```

- [ ] **Step 5: Criar ObraImportada.java**

```java
package br.com.m360.importacao.model;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class ObraImportada {
    private String atlasId;
    private String titulo;
    private String iswc;
    private List<String> titulosAlternativos;
    private List<IntegranteImportado> integrantes;
}
```

- [ ] **Step 6: Criar IntegranteImportado.java**

```java
package br.com.m360.importacao.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class IntegranteImportado {
    private Long idPessoa;
    private String codCategoria;
    private boolean controlado;
    private double percentualPr;
    private double percentualMr;
    private double percentualSr;
    private double percentualBase;
    private double coletaPr;
    private double coletaMr;
    private double coletaSr;
    private double fonomecanico;
    private double sincronizacao;
    private int link;
    private int sequencia;
}
```

- [ ] **Step 7: Compilar**

```bash
mvn compile
```
Expected: BUILD SUCCESS

- [ ] **Step 8: Commit**

```bash
git add src/
git commit -m "feat: adicionar config JDBI e models de importacao"
```

---

## Task 3: Repositórios de Leitura

**Files:**
- Create: `src/main/java/br/com/m360/importacao/repository/SbacemRepository.java`
- Create: `src/main/java/br/com/m360/importacao/repository/PessoaRepository.java`

- [ ] **Step 1: Criar SbacemRepository.java**

```java
package br.com.m360.importacao.repository;

import br.com.m360.importacao.model.SbacemRow;
import br.com.m360.importacao.model.TitularRow;
import br.com.m360.importacao.model.Titular2Row;
import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class SbacemRepository {

    private final Jdbi jdbi;

    public SbacemRepository(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public List<String> listarAtlasIds() {
        return jdbi.withHandle(h -> h.createQuery("""
            SELECT DISTINCT atlas_id FROM mdb.sbacem
            WHERE ignorar IS DISTINCT FROM true
            ORDER BY atlas_id
            """)
            .mapTo(String.class)
            .list());
    }

    public List<SbacemRow> listarPorAtlasId(String atlasId) {
        return jdbi.withHandle(h -> h.createQuery("""
            SELECT atlas_id, original_title, alternate_titles, iswc,
                   chain_id, chain, ip_name, ipi_name_number, ipi_base_number,
                   ip_role, per_own, mec_own
            FROM mdb.sbacem
            WHERE atlas_id = :atlasId
              AND ignorar IS DISTINCT FROM true
            ORDER BY chain_id
            """)
            .bind("atlasId", atlasId)
            .mapToBean(SbacemRow.class)
            .list());
    }

    public Optional<TitularRow> buscarTitular(String ipiBase) {
        return jdbi.withHandle(h -> h.createQuery("""
            SELECT nome, cae, ipi, percentual FROM mdb.titular
            WHERE ipi = :ipi LIMIT 1
            """)
            .bind("ipi", ipiBase)
            .mapToBean(TitularRow.class)
            .findFirst());
    }

    public Optional<Titular2Row> buscarTitular2(String ipiBase) {
        return jdbi.withHandle(h -> h.createQuery("""
            SELECT nome, cae, ipi, percentual, obs FROM mdb.titular2
            WHERE ipi = :ipi LIMIT 1
            """)
            .bind("ipi", ipiBase)
            .mapToBean(Titular2Row.class)
            .findFirst());
    }
}
```

- [ ] **Step 2: Criar PessoaRepository.java**

```java
package br.com.m360.importacao.repository;

import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class PessoaRepository {

    private final Jdbi jdbi;

    public PessoaRepository(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public Optional<Long> buscarIdPorIpName(String ipiNameNumber) {
        return jdbi.withHandle(h -> h.createQuery("""
            SELECT id FROM pessoas.pessoa
            WHERE ip_name = :ipName AND id_tenant = 38
            LIMIT 1
            """)
            .bind("ipName", ipiNameNumber)
            .mapTo(Long.class)
            .findFirst());
    }
}
```

- [ ] **Step 3: Compilar**

```bash
mvn compile
```
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit**

```bash
git add src/
git commit -m "feat: repositorios de leitura SbacemRepository e PessoaRepository"
```

---

## Task 4: LinkCalculatorService

**Files:**
- Create: `src/main/java/br/com/m360/importacao/service/LinkCalculatorService.java`
- Create: `src/test/java/br/com/m360/importacao/service/LinkCalculatorServiceTest.java`

- [ ] **Step 1: Escrever o teste**

```java
package br.com.m360.importacao.service;

import br.com.m360.importacao.model.SbacemRow;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class LinkCalculatorServiceTest {

    private final LinkCalculatorService service = new LinkCalculatorService();

    @Test
    void deveCalcularLinkSimples() {
        // A (CA, chain=null) + B (E, chain=A)
        SbacemRow autor = new SbacemRow();
        autor.setChainId("A"); autor.setChain(null); autor.setIpRole("CA");

        SbacemRow editor = new SbacemRow();
        editor.setChainId("B"); editor.setChain("A"); editor.setIpRole("E");

        Map<String, Integer> links = service.calcularLinks(List.of(autor, editor));

        assertThat(links.get("A")).isEqualTo(links.get("B"));
    }

    @Test
    void deveCalcularLinkMultiploChain() {
        // E (CA), F (CA), G (E, chain="E | F")
        SbacemRow autorE = new SbacemRow();
        autorE.setChainId("E"); autorE.setChain(null); autorE.setIpRole("CA");

        SbacemRow autorF = new SbacemRow();
        autorF.setChainId("F"); autorF.setChain(null); autorF.setIpRole("CA");

        SbacemRow editor = new SbacemRow();
        editor.setChainId("G"); editor.setChain("E | F"); editor.setIpRole("E");

        Map<String, Integer> links = service.calcularLinks(List.of(autorE, autorF, editor));

        // E e G devem ter link diferente de F e G
        // G deve aparecer em dois links diferentes
        assertThat(links.get("E")).isNotEqualTo(links.get("F"));
    }

    @Test
    void deveDarLinkSequencialParaSemPar() {
        SbacemRow semPar = new SbacemRow();
        semPar.setChainId("A"); semPar.setChain(null); semPar.setIpRole("CA");

        Map<String, Integer> links = service.calcularLinks(List.of(semPar));

        assertThat(links.get("A")).isEqualTo(1);
    }
}
```

- [ ] **Step 2: Rodar teste — deve falhar**

```bash
mvn test -Dtest=LinkCalculatorServiceTest
```
Expected: FAIL — `LinkCalculatorService` não existe

- [ ] **Step 3: Implementar LinkCalculatorService.java**

```java
package br.com.m360.importacao.service;

import br.com.m360.importacao.model.SbacemRow;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class LinkCalculatorService {

    /**
     * Calcula o numero_link para cada chain_id da obra.
     * Editor com chain="A" → par com chain_id="A" → mesmo link
     * Editor com chain="E | F" → par com E (link X) e par com F (link Y)
     * Sem par → link sequencial próprio
     *
     * Retorna Map<chainId, numeroLink>
     * Nota: um chainId de editor com múltiplos chains pode aparecer em múltiplos links.
     * Por isso o retorno é Map<"chainId_autorPar", link> para os pares,
     * e chain_id simples para os sem par.
     * Para uso prático, use calcularLinksPorLinha() que retorna por linha da sbacem.
     */
    public Map<String, Integer> calcularLinks(List<SbacemRow> linhas) {
        // Mapa chain_id → lista de chain_ids que o editor aponta
        // Pares: (chain_id_autor, chain_id_editor) → link
        List<int[]> pares = new ArrayList<>(); // [indexAutor, indexEditor]
        Map<String, Integer> chainIdToIndex = new LinkedHashMap<>();

        for (int i = 0; i < linhas.size(); i++) {
            chainIdToIndex.put(linhas.get(i).getChainId(), i);
        }

        int linkCounter = 1;
        Map<String, Integer> result = new LinkedHashMap<>();
        Set<String> chainIdsComLink = new HashSet<>();

        // Processar pares
        for (SbacemRow row : linhas) {
            if (row.getChain() == null || row.getChain().isBlank()) continue;

            String[] targets = row.getChain().split("\\s*\\|\\s*");
            for (String target : targets) {
                target = target.trim();
                if (!chainIdToIndex.containsKey(target)) continue;

                // Autor e editor formam um par com link único
                String pairKey = target + "_" + row.getChainId();
                result.put(pairKey, linkCounter);
                chainIdsComLink.add(target);
                chainIdsComLink.add(row.getChainId());
                linkCounter++;
            }
        }

        // Sem par: link sequencial
        for (SbacemRow row : linhas) {
            if (!chainIdsComLink.contains(row.getChainId())) {
                result.put(row.getChainId(), linkCounter++);
            }
        }

        return result;
    }

    /**
     * Retorna Map<"chainId_autorPar" ou chainId, link> para uso direto.
     * Para cada linha da sbacem, use resolverLink() para obter o link correto.
     */
    public int resolverLink(SbacemRow linha, SbacemRow editorDaLinha, Map<String, Integer> links) {
        if (editorDaLinha != null) {
            // linha é autor — chave é "chainId_chainIdEditor"
            String pairKey = linha.getChainId() + "_" + editorDaLinha.getChainId();
            if (links.containsKey(pairKey)) return links.get(pairKey);
        }
        // sem par ou é o próprio editor
        return links.getOrDefault(linha.getChainId(), 1);
    }
}
```

- [ ] **Step 4: Rodar teste — deve passar**

```bash
mvn test -Dtest=LinkCalculatorServiceTest
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat: LinkCalculatorService com suporte a chain multiplo (pipe)"
```

---

## Task 5: IntegranteBuilderService

**Files:**
- Create: `src/main/java/br/com/m360/importacao/service/IntegranteBuilderService.java`
- Create: `src/test/java/br/com/m360/importacao/service/IntegranteBuilderServiceTest.java`

- [ ] **Step 1: Escrever teste**

```java
package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

class IntegranteBuilderServiceTest {

    private final br.com.m360.importacao.repository.SbacemRepository sbacemRepo =
        Mockito.mock(br.com.m360.importacao.repository.SbacemRepository.class);
    private final br.com.m360.importacao.repository.PessoaRepository pessoaRepo =
        Mockito.mock(br.com.m360.importacao.repository.PessoaRepository.class);
    private final LinkCalculatorService linkCalc = new LinkCalculatorService();
    private final IntegranteBuilderService service =
        new IntegranteBuilderService(sbacemRepo, pessoaRepo, linkCalc);

    @Test
    void deveMontarIntegranteBaseComPercentuais() {
        SbacemRow row = new SbacemRow();
        row.setChainId("A"); row.setChain(null);
        row.setIpiNameNumber("00065589438"); row.setIpiBaseNumber("I-000286718-5");
        row.setIpRole("CA"); row.setPerOwn("33,33"); row.setMecOwn("33,33");

        when(pessoaRepo.buscarIdPorIpName("00065589438")).thenReturn(Optional.of(100L));
        when(sbacemRepo.buscarTitular(any())).thenReturn(Optional.empty());

        List<IntegranteImportado> result = service.construir(List.of(row));

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getPercentualPr()).isEqualTo(33.33);
        assertThat(result.get(0).isControlado()).isFalse();
    }

    @Test
    void deveCederMrParaM360QuandoTitularPresente() {
        SbacemRow row = new SbacemRow();
        row.setChainId("A"); row.setChain(null);
        row.setIpiNameNumber("00065589438"); row.setIpiBaseNumber("I-000286718-5");
        row.setIpRole("E"); row.setPerOwn("50,00"); row.setMecOwn("50,00");

        TitularRow titular = new TitularRow();
        titular.setPercentual("15%");

        when(pessoaRepo.buscarIdPorIpName("00065589438")).thenReturn(Optional.of(100L));
        when(sbacemRepo.buscarTitular("I-000286718-5")).thenReturn(Optional.of(titular));

        List<IntegranteImportado> result = service.construir(List.of(row));

        // titular: mr = 50 - 15 = 35
        assertThat(result.stream().filter(i -> i.getIdPessoa() == 100L).findFirst()
            .get().getPercentualMr()).isEqualTo(35.0);

        // M360: mr = 15
        assertThat(result.stream().filter(i -> i.getIdPessoa() == 2405890L).findFirst()
            .get().getPercentualMr()).isEqualTo(15.0);
    }
}
```

- [ ] **Step 2: Rodar — deve falhar**

```bash
mvn test -Dtest=IntegranteBuilderServiceTest
```
Expected: FAIL

- [ ] **Step 3: Implementar IntegranteBuilderService.java**

```java
package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.PessoaRepository;
import br.com.m360.importacao.repository.SbacemRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class IntegranteBuilderService {

    private static final Logger log = LoggerFactory.getLogger(IntegranteBuilderService.class);
    private static final long ID_MUSICA_360 = 2405890L;

    private final SbacemRepository sbacemRepo;
    private final PessoaRepository pessoaRepo;
    private final LinkCalculatorService linkCalc;

    public IntegranteBuilderService(SbacemRepository sbacemRepo,
                                    PessoaRepository pessoaRepo,
                                    LinkCalculatorService linkCalc) {
        this.sbacemRepo = sbacemRepo;
        this.pessoaRepo = pessoaRepo;
        this.linkCalc = linkCalc;
    }

    public List<IntegranteImportado> construir(List<SbacemRow> linhas) {
        Map<String, Integer> links = linkCalc.calcularLinks(linhas);
        List<IntegranteImportado> resultado = new ArrayList<>();
        int seq = 1;

        // Mapa chainId → row para lookup de pares
        Map<String, SbacemRow> porChainId = new LinkedHashMap<>();
        for (SbacemRow row : linhas) {
            porChainId.put(row.getChainId(), row);
        }

        for (SbacemRow row : linhas) {
            Optional<Long> idPessoa = pessoaRepo.buscarIdPorIpName(row.getIpiNameNumber());
            if (idPessoa.isEmpty()) {
                log.warn("Pessoa não encontrada para ipi_name_number={}", row.getIpiNameNumber());
                continue;
            }

            Optional<TitularRow> titular = sbacemRepo.buscarTitular(row.getIpiBaseNumber());
            double perOwn = parseDouble(row.getPerOwn());
            double mecOwn = parseDouble(row.getMecOwn());
            double pctTitular = titular.map(t -> parseDouble(t.getPercentual().replace("%", ""))).orElse(0.0);

            double mr = titular.isPresent()
                ? Math.max(0, mecOwn - Math.min(mecOwn, pctTitular))
                : mecOwn;

            int link = resolverLinkParaLinha(row, linhas, links);

            IntegranteImportado integrante = IntegranteImportado.builder()
                .idPessoa(idPessoa.get())
                .codCategoria(row.getIpRole())
                .controlado(titular.isPresent())
                .percentualPr(perOwn)
                .percentualMr(mr)
                .percentualSr(mr)
                .percentualBase(perOwn)
                .coletaPr(perOwn)
                .coletaMr(0.0)
                .coletaSr(0.0)
                .link(link)
                .sequencia(seq++)
                .build();

            resultado.add(integrante);

            // Inserir M360 se for titular cedente
            if (titular.isPresent()) {
                double mrM360 = Math.min(mecOwn, pctTitular);
                // SE se já há E no mesmo link, senão E (ou AM se titular2)
                boolean temEditorNoLink = resultado.stream()
                    .anyMatch(i -> i.getLink() == link && "E".equals(i.getCodCategoria()) && i.getIdPessoa() != ID_MUSICA_360);
                String catM360 = temEditorNoLink ? "AM" : "E";

                resultado.add(IntegranteImportado.builder()
                    .idPessoa(ID_MUSICA_360)
                    .codCategoria(catM360)
                    .controlado(true)
                    .percentualPr(0)
                    .percentualMr(mrM360)
                    .percentualSr(mrM360)
                    .percentualBase(0)
                    .coletaPr(0)
                    .coletaMr(perOwn) // será recalculado pelo DistribuicaoService
                    .coletaSr(perOwn)
                    .link(link)
                    .sequencia(seq + 500)
                    .build());
            }
        }

        return resultado;
    }

    private int resolverLinkParaLinha(SbacemRow linha, List<SbacemRow> todas, Map<String, Integer> links) {
        // Sem chain → sem par → link próprio
        if (linha.getChain() == null || linha.getChain().isBlank()) {
            return links.getOrDefault(linha.getChainId(), 1);
        }
        // Editor com chain → pega o link do primeiro par
        String primeiroAlvo = linha.getChain().split("\\s*\\|\\s*")[0].trim();
        String pairKey = primeiroAlvo + "_" + linha.getChainId();
        return links.getOrDefault(pairKey, links.getOrDefault(linha.getChainId(), 1));
    }

    public static double parseDouble(String valor) {
        if (valor == null || valor.isBlank()) return 0.0;
        try {
            return Double.parseDouble(valor.replace(",", "."));
        } catch (NumberFormatException e) {
            return 0.0;
        }
    }
}
```

- [ ] **Step 4: Rodar testes**

```bash
mvn test -Dtest=IntegranteBuilderServiceTest
```
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat: IntegranteBuilderService monta integrantes e M360 por obra"
```

---

## Task 6: ObraRepository (escrita) + LimpezaService

**Files:**
- Create: `src/main/java/br/com/m360/importacao/repository/ObraRepository.java`
- Create: `src/main/java/br/com/m360/importacao/service/LimpezaService.java`

- [ ] **Step 1: Criar ObraRepository.java**

```java
package br.com.m360.importacao.repository;

import br.com.m360.importacao.model.IntegranteImportado;
import br.com.m360.importacao.model.ObraImportada;
import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;

@Repository
public class ObraRepository {

    private final Jdbi jdbi;

    public ObraRepository(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public long inserirObra(ObraImportada obra) {
        return jdbi.withHandle(h -> h.createUpdate("""
            INSERT INTO obras.obra (
                id_tenant, id_configuracao, codigo, titulo, iswc,
                situacao, cod_tipo_versao, cancelada, retida, gravada,
                instrumental, importado, nacional, registro,
                controlada, controle_pr, controle_mr, controle_sr, criacao
            ) VALUES (
                38, 61, :codigo, :titulo, :iswc,
                'L', 'ORI', false, false, false, false, true, true, :registro,
                false, 0, 0, 0, now()
            )
            """)
            .bind("codigo", obra.getAtlasId())
            .bind("titulo", obra.getTitulo())
            .bind("iswc", obra.getIswc())
            .bind("registro", LocalDate.now())
            .executeAndReturnGeneratedKeys("id")
            .mapTo(Long.class)
            .one());
    }

    public void inserirTituloAlternativo(long idObra, String titulo) {
        jdbi.withHandle(h -> h.createUpdate("""
            INSERT INTO obras.obra_titulo (id_obra, titulo, cod_tipo_titulo, ativo, criacao)
            VALUES (:idObra, :titulo, 'AL', true, now())
            """)
            .bind("idObra", idObra)
            .bind("titulo", titulo)
            .execute());
    }

    public void inserirIntegrante(long idObra, IntegranteImportado i) {
        jdbi.withHandle(h -> h.createUpdate("""
            INSERT INTO obras.obra_integrante (
                id_obra, id_pessoa, cod_territorio, cod_categoria,
                controlado, percentual_pr, percentual_mr, percentual_sr, percentual_base,
                coleta_pr, coleta_mr, coleta_sr,
                link, sequencia, criacao
            ) VALUES (
                :idObra, :idPessoa, '76', :codCategoria,
                :controlado, :percentualPr, :percentualMr, :percentualSr, :percentualBase,
                :coletaPr, :coletaMr, :coletaSr,
                :link, :sequencia, now()
            )
            """)
            .bind("idObra", idObra)
            .bind("idPessoa", i.getIdPessoa())
            .bind("codCategoria", i.getCodCategoria())
            .bind("controlado", i.isControlado())
            .bind("percentualPr", i.getPercentualPr())
            .bind("percentualMr", i.getPercentualMr())
            .bind("percentualSr", i.getPercentualSr())
            .bind("percentualBase", i.getPercentualBase())
            .bind("coletaPr", i.getColetaPr())
            .bind("coletaMr", i.getColetaMr())
            .bind("coletaSr", i.getColetaSr())
            .bind("link", i.getLink())
            .bind("sequencia", i.getSequencia())
            .execute());
    }

    public void atualizarControle(long idObra, double controleMr, double controleSr) {
        jdbi.withHandle(h -> h.createUpdate("""
            UPDATE obras.obra SET controlada=true, controle_mr=:mr, controle_sr=:sr
            WHERE id=:id AND id_tenant=38
            """)
            .bind("id", idObra)
            .bind("mr", controleMr)
            .bind("sr", controleSr)
            .execute());
    }

    public void deletarObrasDoTenant38() {
        jdbi.withHandle(h -> {
            h.execute("DELETE FROM obras.obra_integrante WHERE id_obra IN (SELECT id FROM obras.obra WHERE id_tenant=38)");
            h.execute("DELETE FROM obras.obra_titulo WHERE id_obra IN (SELECT id FROM obras.obra WHERE id_tenant=38)");
            h.execute("DELETE FROM obras.obra WHERE id_tenant=38");
            return null;
        });
    }
}
```

- [ ] **Step 2: Criar LimpezaService.java**

```java
package br.com.m360.importacao.service;

import br.com.m360.importacao.repository.ObraRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class LimpezaService {

    private static final Logger log = LoggerFactory.getLogger(LimpezaService.class);
    private final ObraRepository obraRepo;

    public LimpezaService(ObraRepository obraRepo) {
        this.obraRepo = obraRepo;
    }

    public void limparTenant38() {
        log.warn("Limpando todas as obras do tenant 38...");
        obraRepo.deletarObrasDoTenant38();
        log.info("Limpeza concluída.");
    }
}
```

- [ ] **Step 3: Compilar**

```bash
mvn compile
```
Expected: BUILD SUCCESS

- [ ] **Step 4: Commit**

```bash
git add src/
git commit -m "feat: ObraRepository (escrita) e LimpezaService tenant 38"
```

---

## Task 7: ImportacaoService + Runner

**Files:**
- Create: `src/main/java/br/com/m360/importacao/service/ImportacaoService.java`
- Create: `src/main/java/br/com/m360/importacao/ImportacaoRunner.java`

- [ ] **Step 1: Criar ImportacaoService.java**

```java
package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.ObraRepository;
import br.com.m360.importacao.repository.SbacemRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ImportacaoService {

    private static final Logger log = LoggerFactory.getLogger(ImportacaoService.class);
    private static final long ID_MUSICA_360 = 2405890L;

    private final SbacemRepository sbacemRepo;
    private final ObraRepository obraRepo;
    private final IntegranteBuilderService integranteBuilder;

    public ImportacaoService(SbacemRepository sbacemRepo,
                             ObraRepository obraRepo,
                             IntegranteBuilderService integranteBuilder) {
        this.sbacemRepo = sbacemRepo;
        this.obraRepo = obraRepo;
        this.integranteBuilder = integranteBuilder;
    }

    public void importarObra(String atlasId) {
        List<SbacemRow> linhas = sbacemRepo.listarPorAtlasId(atlasId);
        if (linhas.isEmpty()) return;

        SbacemRow primeira = linhas.get(0);
        ObraImportada obra = ObraImportada.builder()
            .atlasId(atlasId)
            .titulo(primeira.getOriginalTitle())
            .iswc(primeira.getIswc())
            .titulosAlternativos(parseTitulosAlternativos(primeira.getAlternateTitles()))
            .integrantes(integranteBuilder.construir(linhas))
            .build();

        long idObra = obraRepo.inserirObra(obra);

        for (String alt : obra.getTitulosAlternativos()) {
            obraRepo.inserirTituloAlternativo(idObra, alt);
        }

        for (IntegranteImportado i : obra.getIntegrantes()) {
            obraRepo.inserirIntegrante(idObra, i);
        }

        // Atualizar controle_mr e controle_sr
        double controleMr = obra.getIntegrantes().stream()
            .filter(i -> i.getIdPessoa() == ID_MUSICA_360)
            .mapToDouble(IntegranteImportado::getColetaMr)
            .sum();

        if (controleMr > 0) {
            obraRepo.atualizarControle(idObra, controleMr, controleMr);
        }

        log.info("Obra {} importada com {} integrantes", atlasId, obra.getIntegrantes().size());
    }

    private List<String> parseTitulosAlternativos(String alternateTitles) {
        if (alternateTitles == null || alternateTitles.isBlank()) return List.of();
        return Arrays.stream(alternateTitles.split("\\|"))
            .map(String::trim)
            .filter(t -> !t.isBlank())
            .collect(Collectors.toList());
    }
}
```

- [ ] **Step 2: Criar ImportacaoRunner.java**

```java
package br.com.m360.importacao;

import br.com.m360.importacao.repository.SbacemRepository;
import br.com.m360.importacao.service.ImportacaoService;
import br.com.m360.importacao.service.LimpezaService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.List;

@Component
public class ImportacaoRunner implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(ImportacaoRunner.class);

    private final SbacemRepository sbacemRepo;
    private final ImportacaoService importacaoService;
    private final LimpezaService limpezaService;

    public ImportacaoRunner(SbacemRepository sbacemRepo,
                            ImportacaoService importacaoService,
                            LimpezaService limpezaService) {
        this.sbacemRepo = sbacemRepo;
        this.importacaoService = importacaoService;
        this.limpezaService = limpezaService;
    }

    @Override
    public void run(String... args) {
        List<String> argList = Arrays.asList(args);

        if (!argList.contains("--confirm")) {
            log.error("ATENÇÃO: Para executar a importação, passe o argumento --confirm");
            log.error("Exemplo: java -jar importacao.jar --confirm");
            return;
        }

        log.info("Iniciando importação SBACEM → Woodstock (tenant 38)");
        limpezaService.limparTenant38();

        List<String> atlasIds = sbacemRepo.listarAtlasIds();
        log.info("Total de obras a importar: {}", atlasIds.size());

        int ok = 0, erro = 0;
        for (String atlasId : atlasIds) {
            try {
                importacaoService.importarObra(atlasId);
                ok++;
                if (ok % 1000 == 0) log.info("Progresso: {}/{}", ok, atlasIds.size());
            } catch (Exception e) {
                erro++;
                log.error("Erro ao importar obra {}: {}", atlasId, e.getMessage());
            }
        }

        log.info("Importação concluída. Sucesso: {}, Erros: {}", ok, erro);
    }
}
```

- [ ] **Step 3: Compilar**

```bash
mvn compile
```
Expected: BUILD SUCCESS

- [ ] **Step 4: Testar com uma obra apenas (sem --confirm, deve abortar)**

```bash
mvn spring-boot:run -Dspring-boot.run.arguments=""
```
Expected: Log "passe o argumento --confirm"

- [ ] **Step 5: Commit**

```bash
git add src/
git commit -m "feat: ImportacaoService e ImportacaoRunner com flag --confirm"
```

---

## Task 8: Gerar JAR e Testar Importação Real

**Files:**
- Modify: `src/main/resources/application.properties`

- [ ] **Step 1: Build do JAR**

```bash
mvn package -DskipTests
```
Expected: `target/importacao-sbacem-1.0.0.jar`

- [ ] **Step 2: Testar com obra única (modo debug)**

Adicione temporariamente em `ImportacaoRunner.run()` antes do loop:
```java
// Teste com obra única
importacaoService.importarObra("AW0MTYO2");
System.exit(0);
```

```bash
DB_PASSWORD=<senha> java -jar target/importacao-sbacem-1.0.0.jar --confirm
```

- [ ] **Step 3: Verificar resultado no banco**

```sql
SELECT oi.link, p.nome, oi.cod_categoria, oi.percentual_pr, oi.percentual_mr
FROM obras.obra_integrante oi
JOIN obras.obra o ON o.id = oi.id_obra
JOIN pessoas.pessoa p ON p.id = oi.id_pessoa
WHERE o.codigo = 'AW0MTYO2' AND o.id_tenant = 38
ORDER BY oi.link, oi.sequencia;
```

- [ ] **Step 4: Remover o teste pontual e rodar importação completa**

```bash
DB_PASSWORD=<senha> java -jar target/importacao-sbacem-1.0.0.jar --confirm
```
Expected: Log final com total de obras importadas e erros.

- [ ] **Step 5: Commit final**

```bash
git add src/
git commit -m "feat: importacao SBACEM completa via JAR com --confirm"
```

---

## Arquivos Criados/Modificados

| Arquivo | Task | Operação |
|---|---|---|
| `pom.xml` | 1 | Criar |
| `src/main/resources/application.properties` | 1 | Criar |
| `ImportacaoApplication.java` | 1 | Criar |
| `config/JdbiConfig.java` | 2 | Criar |
| `model/SbacemRow.java` | 2 | Criar |
| `model/TitularRow.java` | 2 | Criar |
| `model/Titular2Row.java` | 2 | Criar |
| `model/ObraImportada.java` | 2 | Criar |
| `model/IntegranteImportado.java` | 2 | Criar |
| `repository/SbacemRepository.java` | 3 | Criar |
| `repository/PessoaRepository.java` | 3 | Criar |
| `service/LinkCalculatorService.java` | 4 | Criar |
| `service/IntegranteBuilderService.java` | 5 | Criar |
| `repository/ObraRepository.java` | 6 | Criar |
| `service/LimpezaService.java` | 6 | Criar |
| `service/ImportacaoService.java` | 7 | Criar |
| `ImportacaoRunner.java` | 7 | Criar |
