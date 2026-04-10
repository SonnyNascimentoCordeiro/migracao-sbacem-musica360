package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.PessoaRepository;
import br.com.m360.importacao.repository.SbacemRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.*;

@Slf4j
@Service
public class IntegranteBuilderService {

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

        // Acumuladores por link
        Map<Integer, Double> coletaPrPorLink = new HashMap<>();   // soma coleta_pr controlados
        Map<Integer, Double> mrM360PorLink = new HashMap<>();     // soma mr cedido ao M360
        Map<Integer, Double> pctTitularPorLink = new HashMap<>(); // % contrato titular (para distribuição)
        Set<Integer> linksComEditorE = new HashSet<>();

        // Mapa ipiBase → pctTitular para uso no segundo passe
        Map<Long, Double> pctTitularPorPessoa = new HashMap<>();

        // ====================================================
        // FASE 1: integrantes base
        // Editor com chain "E | F" gera UMA linha por alvo (um link por par)
        // ====================================================
        for (SbacemRow row : linhas) {
            Optional<Long> idPessoa = pessoaRepo.buscarIdPorIpName(row.getIpiNameNumber());
            if (idPessoa.isEmpty()) {
                log.warn("Pessoa não encontrada: ipi_name_number={}", row.getIpiNameNumber());
                continue;
            }

            Optional<TitularRow> titular = sbacemRepo.buscarTitular(row.getIpiBaseNumber());
            double perOwn = parseDouble(row.getPerOwn());
            double mecOwn = parseDouble(row.getMecOwn());
            double pctTitular = titular.map(t ->
                parseDouble(t.getPercentual() != null ? t.getPercentual().replace("%", "") : "0")
            ).orElse(0.0);
            boolean controlado = titular.isPresent();

            double mrTitular = controlado
                    ? Math.max(0, mecOwn - Math.min(mecOwn, pctTitular))
                    : mecOwn;
            double mrCedido = controlado ? Math.min(mecOwn, pctTitular) : 0.0;

            // Editor com múltiplos chains → resolver todos os links
            List<Integer> linksDoRow = linkCalc.resolverTodosLinks(row, linhas, links);

            for (int link : linksDoRow) {
                if (controlado) {
                    coletaPrPorLink.merge(link, perOwn, Double::sum);
                    mrM360PorLink.merge(link, mrCedido, Double::sum);
                    pctTitularPorLink.merge(link, pctTitular, Double::sum);
                    pctTitularPorPessoa.put(idPessoa.get(), pctTitular);
                }

                if ("E".equals(row.getIpRole()) || "ES".equals(row.getIpRole())) {
                    linksComEditorE.add(link);
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
                        .build());
            }
        }

        // ====================================================
        // FASE 2: inserir M360 por link
        // ====================================================
        Set<Integer> linksComM360 = new HashSet<>();
        for (Map.Entry<Integer, Double> entry : mrM360PorLink.entrySet()) {
            int link = entry.getKey();
            double mrM360 = entry.getValue();
            if (linksComM360.contains(link)) continue;
            linksComM360.add(link);

            String catM360 = linksComEditorE.contains(link) ? "AM" : "E";
            double coletaMrM360 = coletaPrPorLink.getOrDefault(link, 0.0);

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
                    .fonomecanico(0.0)  // calculado na fase 3
                    .sincronizacao(0.0)
                    .digital(0.0)
                    .execucaoPublica(0.0)
                    .link(link)
                    .sequencia(seq + 500)
                    .build());
        }

        // ====================================================
        // FASE 3: calcular distribuição (fonomecanico + sincronizacao)
        // controle_mr da obra = soma coleta_mr do M360
        // ====================================================
        double controleMrObra = resultado.stream()
                .filter(i -> i.getIdPessoa() == ID_MUSICA_360)
                .mapToDouble(IntegranteImportado::getColetaMr)
                .sum();

        if (controleMrObra > 0) {
            for (IntegranteImportado i : resultado) {
                if (i.getIdPessoa() == ID_MUSICA_360) {
                    // M360: fonomecanico = pct_titular (contrato)
                    // = coleta_mr do M360 nesse link (já é a soma coleta_pr dos controlados)
                    double fono = round2(i.getColetaMr());
                    i.setFonomecanico(fono);
                    i.setSincronizacao(fono);

                } else if (i.isControlado()) {
                    // Controlado: fonomecanico = ROUND((percentual_base / controle_mr_obra) * 100 - pct_m360, 2)
                    double pctM360 = pctTitularPorPessoa.getOrDefault(i.getIdPessoa(), 0.0);
                    double fono = round2((i.getPercentualBase() / controleMrObra) * 100 - pctM360);
                    fono = Math.max(0, fono); // nunca negativo
                    i.setFonomecanico(fono);
                    i.setSincronizacao(fono);
                }
                // não controlados: fonomecanico = 0 (já está)
            }
        }

        // Ordenar por link e sequencia
        resultado.sort(Comparator.comparingInt(IntegranteImportado::getLink)
                .thenComparingInt(IntegranteImportado::getSequencia));

        return resultado;
    }

    private double round2(double value) {
        return Math.round(value * 100.0) / 100.0;
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
