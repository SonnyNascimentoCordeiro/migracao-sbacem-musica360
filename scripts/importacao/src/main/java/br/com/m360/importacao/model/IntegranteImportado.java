package br.com.m360.importacao.model;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class IntegranteImportado {
    private Long idPessoa;
    private String codCategoria;
    private boolean controlado;
    private Double percentualPr;
    private Double percentualMr;
    private Double percentualSr;
    private Double percentualBase;
    private Double coletaPr;
    private Double coletaMr;
    private Double coletaSr;
    // Distribuição
    private Double fonomecanico;
    private Double sincronizacao;
    private Double digital;
    private Double execucaoPublica;
    private int link;
    private int sequencia;
}
