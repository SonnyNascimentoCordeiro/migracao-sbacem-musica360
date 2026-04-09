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
        // controle de M360 já inserido por link
        Set<Integer> linksComM360 = new HashSet<>();
        Map<Integer, Double> coletaPrPorLink = new HashMap<>();
        int seq = 1;

        for (SbacemRow row : linhas) {
            Optional<Long> idPessoa = pessoaRepo.buscarIdPorIpName(row.getIpiNameNumber());
            if (idPessoa.isEmpty()) {
                log.warn("Pessoa não encontrada: ipi_name_number={}", row.getIpiNameNumber());
                continue;
            }

            Optional<TitularRow> titular = sbacemRepo.buscarTitular(row.getIpiBaseNumber());
            double perOwn = parseDouble(row.getPerOwn());
            double mecOwn = parseDouble(row.getMecOwn());
            double pctTitular = titular.map(t -> {
                String pct = t.getPercentual() != null ? t.getPercentual().replace("%", "") : "0";
                return parseDouble(pct);
            }).orElse(0.0);
            boolean controlado = titular.isPresent();

            double mr = controlado
                ? Math.max(0, mecOwn - Math.min(mecOwn, pctTitular))
                : mecOwn;

            int link = linkCalc.resolverLink(row, linhas, links);

            double coletaPr = controlado ? perOwn : perOwn;
            if (controlado) {
                coletaPrPorLink.merge(link, coletaPr, Double::sum);
            }

            IntegranteImportado integrante = IntegranteImportado.builder()
                .idPessoa(idPessoa.get())
                .codCategoria(row.getIpRole())
                .controlado(controlado)
                .percentualPr(perOwn)
                .percentualMr(mr)
                .percentualSr(mr)
                .percentualBase(perOwn)
                .coletaPr(coletaPr)
                .coletaMr(0.0)
                .coletaSr(0.0)
                .link(link)
                .sequencia(seq++)
                .build();

            resultado.add(integrante);

            // Inserir M360 uma vez por link (quando há titular cedente)
            if (controlado && !linksComM360.contains(link)) {
                linksComM360.add(link);
                double mrM360 = Math.min(mecOwn, pctTitular);
                boolean temENoLink = resultado.stream()
                    .anyMatch(i -> i.getLink() == link && "E".equals(i.getCodCategoria()) && i.getIdPessoa() != ID_MUSICA_360);
                String catM360 = temENoLink ? "AM" : "E";

                resultado.add(IntegranteImportado.builder()
                    .idPessoa(ID_MUSICA_360)
                    .codCategoria(catM360)
                    .controlado(true)
                    .percentualPr(0.0)
                    .percentualMr(mrM360)
                    .percentualSr(mrM360)
                    .percentualBase(0.0)
                    .coletaPr(0.0)
                    .coletaMr(coletaPrPorLink.getOrDefault(link, 0.0))
                    .coletaSr(coletaPrPorLink.getOrDefault(link, 0.0))
                    .link(link)
                    .sequencia(seq + 500)
                    .build());
            }
        }
        return resultado;
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
