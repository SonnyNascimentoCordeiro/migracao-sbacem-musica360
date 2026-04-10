package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.ObraRepository;
import br.com.m360.importacao.repository.PessoaRepository;
import br.com.m360.importacao.repository.SbacemRepository;
import lombok.extern.slf4j.Slf4j;
import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Service;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
public class ImportacaoService {

    private static final long ID_MUSICA_360 = 2405890L;

    private final SbacemRepository sbacemRepo;
    private final ObraRepository obraRepo;
    private final PessoaRepository pessoaRepo;
    private final IntegranteBuilderService integranteBuilder;

    public ImportacaoService(SbacemRepository sbacemRepo,
                             ObraRepository obraRepo,
                             PessoaRepository pessoaRepo,
                             IntegranteBuilderService integranteBuilder) {
        this.sbacemRepo = sbacemRepo;
        this.obraRepo = obraRepo;
        this.pessoaRepo = pessoaRepo;
        this.integranteBuilder = integranteBuilder;
    }

    public PreviewObra previewObra(String atlasId) {
        List<SbacemRow> linhas = sbacemRepo.listarPorAtlasId(atlasId);
        if (linhas.isEmpty()) {
            log.warn("Nenhuma linha encontrada para atlas_id={}", atlasId);
            return null;
        }

        SbacemRow primeira = linhas.get(0);
        List<IntegranteImportado> integrantes = integranteBuilder.construir(linhas);

        double controleMr = integrantes.stream()
            .filter(i -> i.getIdPessoa() == ID_MUSICA_360)
            .mapToDouble(IntegranteImportado::getColetaMr)
            .sum();

        List<PreviewObra.PreviewIntegrante> previewIntegrantes = integrantes.stream()
            .map(i -> PreviewObra.PreviewIntegrante.builder()
                .link(i.getLink())
                .idPessoa(i.getIdPessoa())
                .nome(pessoaRepo.buscarNomePorId(i.getIdPessoa()).orElse("ID: " + i.getIdPessoa()))
                .codCategoria(i.getCodCategoria())
                .controlado(i.isControlado())
                .percentualPr(i.getPercentualPr())
                .percentualMr(i.getPercentualMr())
                .percentualSr(i.getPercentualSr())
                .percentualBase(i.getPercentualBase())
                .coletaPr(i.getColetaPr())
                .coletaMr(i.getColetaMr())
                .coletaSr(i.getColetaSr())
                .fonomecanico(i.getFonomecanico() != null ? i.getFonomecanico() : 0.0)
                .sincronizacao(i.getSincronizacao() != null ? i.getSincronizacao() : 0.0)
                .digital(i.getDigital() != null ? i.getDigital() : 0.0)
                .execucaoPublica(i.getExecucaoPublica() != null ? i.getExecucaoPublica() : 0.0)
                .build())
            .collect(Collectors.toList());

        PreviewObra preview = PreviewObra.builder()
            .atlasId(atlasId)
            .titulo(primeira.getOriginalTitle())
            .iswc(primeira.getIswc())
            .controleMr(controleMr)
            .controleSr(controleMr)
            .titulosAlternativos(parseTitulos(primeira.getAlternateTitles()))
            .integrantes(previewIntegrantes)
            .build();

        log.info("Preview gerado para obra {} - {}", atlasId, preview.getTitulo());
        return preview;
    }

    public void importarObra(String atlasId) {
        List<SbacemRow> linhas = sbacemRepo.listarPorAtlasId(atlasId);
        if (linhas.isEmpty()) {
            log.warn("Nenhuma linha encontrada para atlas_id={}", atlasId);
            return;
        }

        SbacemRow primeira = linhas.get(0);
        List<IntegranteImportado> integrantes = integranteBuilder.construir(linhas);

        ObraImportada obra = ObraImportada.builder()
            .atlasId(atlasId)
            .titulo(primeira.getOriginalTitle())
            .iswc(primeira.getIswc() != null && !primeira.getIswc().isBlank() ? primeira.getIswc() : null)
            .titulosAlternativos(parseTitulos(primeira.getAlternateTitles()))
            .integrantes(integrantes)
            .build();

        long idObra = obraRepo.inserirObra(obra);

        for (String alt : obra.getTitulosAlternativos()) {
            obraRepo.inserirTituloAlternativo(idObra, alt);
        }

        for (IntegranteImportado i : integrantes) {
            obraRepo.inserirIntegrante(idObra, i);
        }

        double controleMr = integrantes.stream()
            .filter(i -> i.getIdPessoa() == ID_MUSICA_360)
            .mapToDouble(IntegranteImportado::getColetaMr)
            .sum();

        if (controleMr > 0) {
            obraRepo.atualizarControle(idObra, controleMr, controleMr);
        }

        log.info("Obra {} '{}' importada com {} integrantes", atlasId, obra.getTitulo(), integrantes.size());
    }

    public void importarTodas() {
        List<String> atlasIds = sbacemRepo.listarAtlasIds();
        log.info("Iniciando importação de {} obras", atlasIds.size());
        int ok = 0, erro = 0;
        for (String atlasId : atlasIds) {
            try {
                importarObra(atlasId);
                ok++;
                if (ok % 1000 == 0) log.info("Progresso: {}/{}", ok, atlasIds.size());
            } catch (Exception e) {
                erro++;
                log.error("Erro na obra {}: {}", atlasId, e.getMessage());
            }
        }
        log.info("Concluído. Sucesso: {}, Erros: {}", ok, erro);
    }

    private List<String> parseTitulos(String alternateTitles) {
        if (alternateTitles == null || alternateTitles.isBlank()) return List.of();
        return Arrays.stream(alternateTitles.split("\\|"))
            .map(String::trim).filter(t -> !t.isBlank())
            .collect(Collectors.toList());
    }
}
