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
