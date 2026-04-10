package br.com.m360.importacao.model;

import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class TitularRow {
    private String nome;
    private String cae;
    private String ipi;
    private String percentual;
}
