package br.com.m360.importacao.model;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class PreviewObra {
    private String atlasId;
    private String titulo;
    private String iswc;
    private double controleMr;
    private double controleSr;
    private List<String> titulosAlternativos;
    private List<PreviewIntegrante> integrantes;

    @Data
    @Builder
    public static class PreviewIntegrante {
        private int link;
        private Long idPessoa;
        private String nome;
        private String codCategoria;
        private boolean controlado;
        // Percentuais de propriedade
        private double percentualPr;
        private double percentualMr;
        private double percentualSr;
        private double percentualBase;
        // Percentuais de coleta
        private double coletaPr;
        private double coletaMr;
        private double coletaSr;
        // Percentuais de distribuição
        private double fonomecanico;
        private double sincronizacao;
        private double digital;
        private double execucaoPublica;
    }
}
