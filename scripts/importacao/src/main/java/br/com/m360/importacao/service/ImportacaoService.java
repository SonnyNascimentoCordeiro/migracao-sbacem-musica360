package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.ObraRepository;
import br.com.m360.importacao.repository.PessoaRepository;
import br.com.m360.importacao.repository.SbacemRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
public class ImportacaoService {

    private static final long ID_MUSICA_360 = 2405890L;
    private static final String NOME_M360_LTDA = "MUSICA 360 LTDA";
    private static final String NOME_M360_EDITORA_LTDA = "MUSICA 360 EDITORA LTDA";

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
        boolean obraTemMusica360NaFonte = contemMusica360NaFonte(linhas);
        Optional<Long> idObraExistente = obraRepo.buscarIdObraPorCodigo(atlasId);
        Set<Integer> linksComM360Existente = idObraExistente
                .map(obraRepo::buscarLinksComMusica360)
                .orElseGet(Set::of);
        boolean obraTemMusica360Existente = obraTemMusica360NaFonte || idObraExistente
                .map(id -> !linksComM360Existente.isEmpty() || obraRepo.existeMusica360EditoraPorIpName(id))
                .orElse(false);
        if (obraTemMusica360NaFonte) {
            log.info("Obra {}: M360 já veio na fonte; será aplicado apenas de-para sem inserção automática da M360.", atlasId);
        }
        List<IntegranteImportado> integrantes = integranteBuilder.construir(
                linhas, linksComM360Existente, obraTemMusica360Existente);

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
        boolean obraTemMusica360NaFonte = contemMusica360NaFonte(linhas);
        Optional<Long> idObraExistente = obraRepo.buscarIdObraPorCodigo(atlasId);
        Set<Integer> linksComM360Existente = idObraExistente
                .map(obraRepo::buscarLinksComMusica360)
                .orElseGet(Set::of);
        boolean obraTemMusica360Existente = obraTemMusica360NaFonte || idObraExistente
                .map(id -> !linksComM360Existente.isEmpty() || obraRepo.existeMusica360EditoraPorIpName(id))
                .orElse(false);
        if (obraTemMusica360NaFonte) {
            log.info("Obra {}: M360 já veio na fonte; será aplicado apenas de-para sem inserção automática da M360.", atlasId);
        }
        List<IntegranteImportado> integrantes = integranteBuilder.construir(
                linhas, linksComM360Existente, obraTemMusica360Existente);

        ObraImportada obra = ObraImportada.builder()
            .atlasId(atlasId)
            .titulo(primeira.getOriginalTitle())
            .iswc(primeira.getIswc() != null && !primeira.getIswc().isBlank() ? primeira.getIswc() : null)
            .titulosAlternativos(parseTitulos(primeira.getAlternateTitles()))
            .integrantes(integrantes)
            .build();

        long idObra;
        if (idObraExistente.isPresent()) {
            idObra = idObraExistente.get();
            if (obraTemMusica360NaFonte) {
                log.info("Obra {} já existe (id={}); de-para da M360 aplicado e sem inserção automática adicional.",
                        atlasId, idObra);
            } else if (obraTemMusica360Existente) {
                log.info("Obra {} já existe (id={}); M360 não será reinserido (detectada por id/nome no banco).",
                        atlasId, idObra);
            } else {
                log.info("Obra {} já existe (id={}); reimportando integrantes.", atlasId, idObra);
            }
        } else {
            idObra = obraRepo.inserirObra(obra);
            for (String alt : obra.getTitulosAlternativos()) {
                obraRepo.inserirTituloAlternativo(idObra, alt);
            }
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

    private boolean contemMusica360NaFonte(List<SbacemRow> linhas) {
        return linhas.stream().anyMatch(r -> isMusica360Nome(r.getIpName()));
    }

    private boolean isMusica360Nome(String ipName) {
        if (ipName == null) {
            return false;
        }
        String normalizado = ipName.trim().toUpperCase();
        return NOME_M360_LTDA.equals(normalizado) || NOME_M360_EDITORA_LTDA.equals(normalizado);
    }
}
