package br.com.m360.importacao.model;

import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class SbacemRow {
    private String atlasId;
    private String originalTitle;
    private String alternateTitles;
    private String iswc;
    private String chainId;
    private String chain;
    private String ipName;
    private String ipiNameNumber;
    private String ipiBaseNumber;
    private String ipRole;
    private String perOwn;
    private String mecOwn;
    private String performers;
    private String perStatus;
    private String mecStatus;
    private String source;
}
