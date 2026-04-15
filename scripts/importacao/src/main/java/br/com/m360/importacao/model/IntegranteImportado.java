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
    /** IPI base da fonte SBACEM — para lookup `mdb.titular` / `mdb.titular2` na distribuição. */
    private String ipiBaseNumber;
    /**
     * Se true, não persiste esta linha no INSERT (ex.: M360 já existe no mesmo {@code link} na obra).
     * Continua na lista para cálculo de distribuição em memória.
     */
    @Builder.Default
    private boolean omitirInsercao = false;
}
