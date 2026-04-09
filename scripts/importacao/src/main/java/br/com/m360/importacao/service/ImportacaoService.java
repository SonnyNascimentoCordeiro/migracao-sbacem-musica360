package br.com.m360.importacao.service;

import br.com.m360.importacao.model.*;
import br.com.m360.importacao.repository.ObraRepository;
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
    private final IntegranteBuilderService integranteBuilder;
    private final Jdbi jdbi;

    public ImportacaoService(SbacemRepository sbacemRepo,
                             ObraRepository obraRepo,
                             IntegranteBuilderService integranteBuilder,
                             Jdbi jdbi) {
        this.sbacemRepo = sbacemRepo;
        this.obraRepo = obraRepo;
        this.integranteBuilder = integranteBuilder;
        this.jdbi = jdbi;
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

        long idObra = obraRepo.inserirObra(atlasId, obra.getTitulo(), obra.getIswc());

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

    private List<String> parseTitulos(String alternateTitles) {
        if (alternateTitles == null || alternateTitles.isBlank()) return List.of();
        return Arrays.stream(alternateTitles.split("\\|"))
            .map(String::trim).filter(t -> !t.isBlank())
            .collect(Collectors.toList());
    }
}
