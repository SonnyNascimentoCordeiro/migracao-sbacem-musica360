package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.PessoaRepository;
import br.com.m360.importacao.repository.SbacemRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

import static java.util.Collections.emptySet;

@Slf4j
@Service
public class IntegranteBuilderService {

    private static final long ID_MUSICA_360 = 2405890L;
    private static final String NOME_M360_LTDA = "MUSICA 360 LTDA";
    private static final String NOME_M360_EDITORA_LTDA = "MUSICA 360 EDITORA LTDA";

    private static final double PCT_DISTRIBUICAO_AUTOR_PF = 0.15;

    private static final Set<String> ROLES_AUTOR = Set.of(
            "CA", "C", "A", "AR", "SA", "AD", "TR");
    private static final Set<String> ROLES_EDITORA = Set.of(
            "E", "ES", "AM", "PA", "SE", "AQ");

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
        return construir(linhas, emptySet(), false);
    }

    /**
     * @param linksOndeJaExisteM360 links em que a obra Woodstock já tem linha M360 — não insere outra;
     *        mantém linha “virtual” só para distribuição, com {@code omitirInsercao=true}.
     */
    public List<IntegranteImportado> construir(List<SbacemRow> linhas, Set<Integer> linksOndeJaExisteM360) {
        return construir(linhas, linksOndeJaExisteM360, false);
    }

    public List<IntegranteImportado> construir(List<SbacemRow> linhas,
                                               Set<Integer> linksOndeJaExisteM360,
                                               boolean obraTemMusica360Existente) {
        Map<String, Integer> links = linkCalc.calcularLinks(linhas);
        List<IntegranteImportado> resultado = new ArrayList<>();
        boolean obraTemMusica360NaFonte = linhas.stream().anyMatch(r -> isMusica360Nome(r.getIpName()));
        int seq = 1;

        Map<Integer, Double> coletaPrPorLink = new HashMap<>();
        Map<Integer, Double> mrM360PorLink = new HashMap<>();
        Set<Integer> linksComEditoraControlada = new HashSet<>();

        for (SbacemRow row : linhas) {
            Optional<Long> idPessoa = resolverPessoa(row);
            if (idPessoa.isEmpty()) {
                log.warn("Pessoa não encontrada: ipi_name_number={}", row.getIpiNameNumber());
                continue;
            }

            Optional<TitularRow> titular = sbacemRepo.buscarTitular(row.getIpiBaseNumber());
            Optional<TitularRow> titular2 = sbacemRepo.buscarTitular2(row.getIpiBaseNumber());
            boolean controlado = titular.isPresent() || titular2.isPresent();

            double pctCessaoMr = resolverPercentualCessaoMr(titular, titular2);

            double perOwn = parseDouble(row.getPerOwn());
            double mecOwn = parseDouble(row.getMecOwn());

            double mrTitular = controlado
                    ? Math.max(0, mecOwn - Math.min(mecOwn, pctCessaoMr))
                    : mecOwn;
            double mrCedido = controlado ? Math.min(mecOwn, pctCessaoMr) : 0.0;

            List<Integer> linksDoRow = linkCalc.resolverTodosLinks(row, linhas, links);

            for (int link : linksDoRow) {
                if (controlado) {
                    coletaPrPorLink.merge(link, perOwn, Double::sum);
                    mrM360PorLink.merge(link, mrCedido, Double::sum);
                }

                if (controlado && row.getIpRole() != null && ROLES_EDITORA.contains(row.getIpRole())) {
                    linksComEditoraControlada.add(link);
                }

                resultado.add(IntegranteImportado.builder()
                        .idPessoa(idPessoa.get())
                        .codCategoria(row.getIpRole())
                        .controlado(controlado)
                        .percentualPr(perOwn)
                        .percentualMr(mrTitular)
                        .percentualSr(mrTitular)
                        .percentualBase(perOwn)
                        .coletaPr(perOwn)
                        .coletaMr(0.0)
                        .coletaSr(0.0)
                        .fonomecanico(0.0)
                        .sincronizacao(0.0)
                        .digital(0.0)
                        .execucaoPublica(0.0)
                        .link(link)
                        .sequencia(seq++)
                        .ipiBaseNumber(row.getIpiBaseNumber())
                        .omitirInsercao(false)
                        .build());
            }
        }

        if (!obraTemMusica360NaFonte) {
            Set<Integer> linksComM360 = new HashSet<>();
            for (Map.Entry<Integer, Double> entry : mrM360PorLink.entrySet()) {
                int link = entry.getKey();
                double mrM360 = entry.getValue();
                if (linksComM360.contains(link)) continue;
                linksComM360.add(link);

                String catM360 = linksComEditoraControlada.contains(link) ? "AM" : "E";
                double coletaMrM360 = coletaPrPorLink.getOrDefault(link, 0.0);
                boolean jaTemM360NoLink = obraTemMusica360Existente
                        || (linksOndeJaExisteM360 != null && linksOndeJaExisteM360.contains(link));

                resultado.add(IntegranteImportado.builder()
                        .idPessoa(ID_MUSICA_360)
                        .codCategoria(catM360)
                        .controlado(true)
                        .percentualPr(0.0)
                        .percentualMr(mrM360)
                        .percentualSr(mrM360)
                        .percentualBase(0.0)
                        .coletaPr(0.0)
                        .coletaMr(coletaMrM360)
                        .coletaSr(coletaMrM360)
                        .fonomecanico(0.0)
                        .sincronizacao(0.0)
                        .digital(0.0)
                        .execucaoPublica(0.0)
                        .link(link)
                        .sequencia(seq + 500)
                        .ipiBaseNumber(null)
                        .omitirInsercao(jaTemM360NoLink)
                        .build());
            }
        }

        aplicarDistribuicaoPorLink(resultado);

        resultado.sort(Comparator.comparingInt(IntegranteImportado::getLink)
                .thenComparingInt(IntegranteImportado::getSequencia));

        return resultado;
    }

    /**
     * Cessão MR: prioriza {@code titular2} quando informado (alinhado a {@code fase3_query4_ajuste_mr_sr.sql}),
     * senão {@code titular}.
     */
    static double resolverPercentualCessaoMr(Optional<TitularRow> titular, Optional<TitularRow> titular2) {
        if (titular2.isPresent()) {
            String p2 = titular2.get().getPercentual();
            if (p2 != null && !p2.isBlank()) {
                return parseDouble(p2.replace("%", ""));
            }
        }
        return titular.map(t -> parseDouble(t.getPercentual() != null ? t.getPercentual().replace("%", "") : "0"))
                .orElse(0.0);
    }

    /** Visível no mesmo pacote em testes (`src/test/java/.../service`). */
    void aplicarDistribuicaoPorLink(List<IntegranteImportado> resultado) {
        Map<Integer, List<IntegranteImportado>> porLink = new HashMap<>();
        for (IntegranteImportado i : resultado) {
            porLink.computeIfAbsent(i.getLink(), k -> new ArrayList<>()).add(i);
        }

        for (List<IntegranteImportado> bucket : porLink.values()) {
            IntegranteImportado linhaM360 = null;
            List<IntegranteImportado> demais = new ArrayList<>();
            for (IntegranteImportado i : bucket) {
                if (isLinhaM360Automatica(i)) {
                    linhaM360 = i;
                } else {
                    demais.add(i);
                }
            }

            double somaParcelaM360 = 0.0;
            double somaAutoresControlados = 0.0;
            double somaEditorasControladas = 0.0;

            for (IntegranteImportado i : demais) {
                if (!i.isControlado() || i.getCodCategoria() == null) {
                    continue;
                }
                double base = i.getPercentualBase() != null ? i.getPercentualBase() : 0.0;
                if (ROLES_AUTOR.contains(i.getCodCategoria())) {
                    somaAutoresControlados += base;
                } else if (ROLES_EDITORA.contains(i.getCodCategoria())) {
                    somaEditorasControladas += base;
                }
            }

            boolean linkMistoAutorEditora = somaAutoresControlados > 0.0 && somaEditorasControladas > 0.0;
            double somaBasesControladas = somaAutoresControlados + somaEditorasControladas;

            for (IntegranteImportado i : demais) {
                if (!i.isControlado()) {
                    i.setFonomecanico(0.0);
                    i.setSincronizacao(0.0);
                    continue;
                }

                String role = i.getCodCategoria();
                double base = i.getPercentualBase() != null ? i.getPercentualBase() : 0.0;
                double baseDistribuicao = somaBasesControladas > 0.0 ? (base / somaBasesControladas) * 100.0 : 0.0;

                double parcelaM360;
                double fono;

                if (role != null && ROLES_AUTOR.contains(role)) {
                    if (linkMistoAutorEditora) {
                        parcelaM360 = 0.0;
                        fono = round2(baseDistribuicao);
                    } else {
                        boolean pj = pessoaRepo.buscarTipoPorId(i.getIdPessoa()).map("J"::equals).orElse(false);
                        if (!pj) {
                            parcelaM360 = round2(baseDistribuicao * PCT_DISTRIBUICAO_AUTOR_PF);
                            fono = round2(baseDistribuicao - parcelaM360);
                        } else {
                            double pct = pctContratoTitular2(i.getIpiBaseNumber());
                            parcelaM360 = round2(baseDistribuicao * pct / 100.0);
                            fono = round2(baseDistribuicao - parcelaM360);
                        }
                    }
                } else if (role != null && ROLES_EDITORA.contains(role)) {
                    boolean pj = pessoaRepo.buscarTipoPorId(i.getIdPessoa()).map("J"::equals).orElse(false);
                    double pct = pctContratoEditora(i.getIpiBaseNumber(), pj);
                    parcelaM360 = round2(baseDistribuicao * pct / 100.0);
                    fono = round2(baseDistribuicao - parcelaM360);
                } else {
                    parcelaM360 = 0.0;
                    fono = 0.0;
                }

                somaParcelaM360 += parcelaM360;
                fono = Math.max(0.0, fono);
                i.setFonomecanico(fono);
                i.setSincronizacao(fono);
            }

            if (linhaM360 != null) {
                double v = round2(somaParcelaM360);
                linhaM360.setFonomecanico(v);
                linhaM360.setSincronizacao(v);
            }
        }
    }

    private double pctContratoTitular2(String ipiBase) {
        if (ipiBase == null || ipiBase.isBlank()) {
            return 0.0;
        }
        return sbacemRepo.buscarTitular2(ipiBase)
                .map(t -> parseDouble(t.getPercentual() != null ? t.getPercentual().replace("%", "") : "0"))
                .orElse(0.0);
    }

    /** Percentual de contrato (distribuição) para titular PF em `mdb.titular`. */
    private double pctContratoTitular1(String ipiBase) {
        if (ipiBase == null || ipiBase.isBlank()) {
            return 0.0;
        }
        return sbacemRepo.buscarTitular(ipiBase)
                .map(t -> parseDouble(t.getPercentual() != null ? t.getPercentual().replace("%", "") : "0"))
                .orElse(0.0);
    }

    private double pctContratoEditora(String ipiBase, boolean pj) {
        if (pj) {
            double pct = pctContratoTitular2(ipiBase);
            if (pct > 0) {
                return pct;
            }
            // Há editoras PJ cujo contrato veio apenas em titular1; usar como fallback.
            pct = pctContratoTitular1(ipiBase);
            if (pct > 0) {
                return pct;
            }
            return PCT_DISTRIBUICAO_AUTOR_PF * 100.0;
        }
        double pct = pctContratoTitular1(ipiBase);
        if (pct <= 0) {
            return PCT_DISTRIBUICAO_AUTOR_PF * 100.0;
        }
        return pct;
    }

    private double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
    }

    private Optional<Long> resolverPessoa(SbacemRow row) {
        if (isMusica360Nome(row.getIpName())) {
            return Optional.of(ID_MUSICA_360);
        }
        return pessoaRepo.buscarIdPorIpName(row.getIpiNameNumber());
    }

    private boolean isMusica360Nome(String nome) {
        if (nome == null) {
            return false;
        }
        String normalizado = nome.trim().toUpperCase();
        return NOME_M360_LTDA.equals(normalizado) || NOME_M360_EDITORA_LTDA.equals(normalizado);
    }

    private boolean isLinhaM360Automatica(IntegranteImportado i) {
        if (i.getIdPessoa() == null || i.getIdPessoa() != ID_MUSICA_360) {
            return false;
        }
        double base = i.getPercentualBase() != null ? i.getPercentualBase() : 0.0;
        double pr = i.getPercentualPr() != null ? i.getPercentualPr() : 0.0;
        return base == 0.0 && pr == 0.0 && i.getIpiBaseNumber() == null;
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
