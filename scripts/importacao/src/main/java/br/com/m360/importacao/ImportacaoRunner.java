package br.com.m360.importacao;

import br.com.m360.importacao.repository.SbacemRepository;
import br.com.m360.importacao.service.ImportacaoService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import java.util.Arrays;
import java.util.List;

@Slf4j
@Component
public class ImportacaoRunner implements CommandLineRunner {

    private final SbacemRepository sbacemRepo;
    private final ImportacaoService importacaoService;

    public ImportacaoRunner(SbacemRepository sbacemRepo, ImportacaoService importacaoService) {
        this.sbacemRepo = sbacemRepo;
        this.importacaoService = importacaoService;
    }

    @Override
    public void run(String... args) {
        List<String> argList = Arrays.asList(args);

        // Modo: preview de obra (sem inserir no banco)
        int previewIdx = argList.indexOf("--preview");
        if (previewIdx >= 0 && previewIdx + 1 < argList.size()) {
            String atlasId = argList.get(previewIdx + 1);
            log.info("Preview da obra: {}", atlasId);
            importacaoService.previewObra(atlasId);
            return;
        }

        // Modo: obra específica
        int obraIdx = argList.indexOf("--obra");
        if (obraIdx >= 0 && obraIdx + 1 < argList.size()) {
            String atlasId = argList.get(obraIdx + 1);
            log.info("Importando obra específica: {}", atlasId);
            importacaoService.importarObra(atlasId);
            return;
        }

        // Modo: importação completa
        if (argList.contains("--confirm")) {
            log.info("Iniciando importação completa SBACEM → Woodstock (tenant 38)");
            List<String> atlasIds = sbacemRepo.listarAtlasIds();
            log.info("Total de obras: {}", atlasIds.size());

            int ok = 0, erro = 0;
            for (String atlasId : atlasIds) {
                try {
                    importacaoService.importarObra(atlasId);
                    ok++;
                    if (ok % 1000 == 0) log.info("Progresso: {}/{}", ok, atlasIds.size());
                } catch (Exception e) {
                    erro++;
                    log.error("Erro na obra {}: {}", atlasId, e.getMessage());
                }
            }
            log.info("Concluído. Sucesso: {}, Erros: {}", ok, erro);
            return;
        }

        // Sem argumento
        log.info("Uso:");
        log.info("  --preview <atlas_id>  Mostra como a obra ficará (sem inserir no banco)");
        log.info("  --obra <atlas_id>     Importa uma obra específica para validação");
        log.info("  --confirm             Importa todas as obras (125k+)");
    }
}
