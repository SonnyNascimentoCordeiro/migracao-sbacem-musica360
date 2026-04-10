package br.com.m360.importacao.controller;

import br.com.m360.importacao.model.PreviewObra;
import br.com.m360.importacao.service.ImportacaoService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/importacao")
@Tag(name = "Importação SBACEM", description = "Importação do catálogo SBACEM para Woodstock (tenant 38)")
public class ImportacaoController {

    private final ImportacaoService importacaoService;

    public ImportacaoController(ImportacaoService importacaoService) {
        this.importacaoService = importacaoService;
    }

    @GetMapping("/preview/{atlasId}")
    @Operation(summary = "Preview de uma obra", description = "Mostra como a obra ficará após importação, sem inserir no banco")
    public ResponseEntity<PreviewObra> preview(@PathVariable String atlasId) {
        PreviewObra preview = importacaoService.previewObra(atlasId);
        if (preview == null) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(preview);
    }

    @PostMapping("/obra/{atlasId}")
    @Operation(summary = "Importar obra específica", description = "Importa uma obra pelo atlas_id para o banco de produção")
    public ResponseEntity<String> importarObra(@PathVariable String atlasId) {
        importacaoService.importarObra(atlasId);
        return ResponseEntity.ok("Obra " + atlasId + " importada com sucesso.");
    }

    @PostMapping("/todas")
    @Operation(summary = "Importar todas as obras", description = "Importa todo o catálogo SBACEM (125k+ obras). Operação longa.")
    public ResponseEntity<String> importarTodas() {
        new Thread(() -> importacaoService.importarTodas()).start();
        return ResponseEntity.accepted().body("Importação iniciada em background. Acompanhe os logs.");
    }
}
