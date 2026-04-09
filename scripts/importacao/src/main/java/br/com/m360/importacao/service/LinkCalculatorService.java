package br.com.m360.importacao.service;

import br.com.m360.importacao.model.SbacemRow;
import org.springframework.stereotype.Service;
import java.util.*;

@Service
public class LinkCalculatorService {

    /**
     * Retorna mapa de chave -> link.
     * Chaves para pares: "chainIdAutor::chainIdEditor"
     * Chaves para sem par: "chainId"
     */
    public Map<String, Integer> calcularLinks(List<SbacemRow> linhas) {
        Map<String, Integer> result = new LinkedHashMap<>();
        Set<String> chainIdsComLink = new HashSet<>();
        int linkCounter = 1;

        // Processar pares (editor com chain apontando para autor)
        for (SbacemRow row : linhas) {
            if (row.getChain() == null || row.getChain().isBlank()) continue;
            String[] targets = row.getChain().split("\\s*\\|\\s*");
            for (String target : targets) {
                String trimmedTarget = target.trim();
                boolean autorExiste = linhas.stream().anyMatch(r -> trimmedTarget.equals(r.getChainId()));
                if (!autorExiste) continue;
                String pairKey = trimmedTarget + "::" + row.getChainId();
                result.put(pairKey, linkCounter++);
                chainIdsComLink.add(trimmedTarget);
                chainIdsComLink.add(row.getChainId());
            }
        }

        // Sem par: link sequencial próprio
        for (SbacemRow row : linhas) {
            if (!chainIdsComLink.contains(row.getChainId())) {
                result.put(row.getChainId(), linkCounter++);
            }
        }
        return result;
    }

    public int resolverLink(SbacemRow linha, List<SbacemRow> todas, Map<String, Integer> links) {
        // Linha é editor com chain?
        if (linha.getChain() != null && !linha.getChain().isBlank()) {
            String primeiroAlvo = linha.getChain().split("\\s*\\|\\s*")[0].trim();
            String pairKey = primeiroAlvo + "::" + linha.getChainId();
            if (links.containsKey(pairKey)) return links.get(pairKey);
        }
        // Linha é autor (alvo de um editor)?
        for (SbacemRow editor : todas) {
            if (editor.getChain() == null) continue;
            String[] targets = editor.getChain().split("\\s*\\|\\s*");
            for (String t : targets) {
                if (t.trim().equals(linha.getChainId())) {
                    String pairKey = linha.getChainId() + "::" + editor.getChainId();
                    if (links.containsKey(pairKey)) return links.get(pairKey);
                }
            }
        }
        // Sem par
        return links.getOrDefault(linha.getChainId(), 1);
    }
}
