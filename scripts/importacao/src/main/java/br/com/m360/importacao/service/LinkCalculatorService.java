package br.com.m360.importacao.service;

import br.com.m360.importacao.model.SbacemRow;
import org.springframework.stereotype.Service;
import java.util.*;

@Service
public class LinkCalculatorService {

    /**
     * Retorna mapa de chainId -> link.
     * O link passa a ser canônico por componente de chain conectada.
     */
    public Map<String, Integer> calcularLinks(List<SbacemRow> linhas) {
        Map<String, Set<String>> grafo = construirGrafo(linhas);
        List<String> ordem = chainIdsEmOrdem(linhas);

        Map<String, Integer> result = new LinkedHashMap<>();
        Set<String> visitados = new HashSet<>();
        int linkCounter = 1;

        for (String chainId : ordem) {
            if (visitados.contains(chainId)) {
                continue;
            }
            Set<String> componente = coletarComponente(chainId, grafo, visitados);
            for (String no : componente) {
                result.put(no, linkCounter);
            }
            linkCounter++;
        }

        return result;
    }

    /**
     * Retorna todos os links de uma linha.
     * Editor com chain "E | F" retorna [link_E, link_F].
     * Autor ou sem par retorna [link_proprio].
     */
    public List<Integer> resolverTodosLinks(SbacemRow linha, List<SbacemRow> todas, Map<String, Integer> links) {
        // Editor com múltiplos chains → um link por alvo
        if (linha.getChain() != null && !linha.getChain().isBlank()) {
            List<Integer> result = new ArrayList<>();
            String[] targets = linha.getChain().split("\\s*\\|\\s*");
            for (String target : targets) {
                String trimmed = target.trim();
                Integer link = links.get(trimmed);
                if (link != null && !result.contains(link)) {
                    result.add(link);
                }
            }
            if (!result.isEmpty()) return result;
        }

        String chainId = normalizar(linha.getChainId());
        if (chainId != null) {
            return List.of(links.getOrDefault(chainId, 1));
        }

        return List.of(1);
    }

    public int resolverLink(SbacemRow linha, List<SbacemRow> todas, Map<String, Integer> links) {
        List<Integer> todosLinks = resolverTodosLinks(linha, todas, links);
        return todosLinks.isEmpty() ? 1 : todosLinks.get(0);
    }

    private Map<String, Set<String>> construirGrafo(List<SbacemRow> linhas) {
        Map<String, Set<String>> grafo = new LinkedHashMap<>();
        Set<String> existentes = new HashSet<>();

        for (SbacemRow row : linhas) {
            String chainId = normalizar(row.getChainId());
            if (chainId != null) {
                existentes.add(chainId);
                grafo.computeIfAbsent(chainId, key -> new LinkedHashSet<>());
            }
        }

        for (SbacemRow row : linhas) {
            String origem = normalizar(row.getChainId());
            if (origem == null || row.getChain() == null || row.getChain().isBlank()) {
                continue;
            }
            for (String target : row.getChain().split("\\s*\\|\\s*")) {
                String destino = normalizar(target);
                if (destino == null || !existentes.contains(destino)) {
                    continue;
                }
                grafo.computeIfAbsent(origem, key -> new LinkedHashSet<>()).add(destino);
                grafo.computeIfAbsent(destino, key -> new LinkedHashSet<>()).add(origem);
            }
        }

        return grafo;
    }

    private List<String> chainIdsEmOrdem(List<SbacemRow> linhas) {
        Set<String> ordem = new LinkedHashSet<>();
        for (SbacemRow row : linhas) {
            String chainId = normalizar(row.getChainId());
            if (chainId != null) {
                ordem.add(chainId);
            }
        }
        return new ArrayList<>(ordem);
    }

    private Set<String> coletarComponente(String raiz, Map<String, Set<String>> grafo, Set<String> visitados) {
        Set<String> componente = new LinkedHashSet<>();
        Deque<String> fila = new ArrayDeque<>();
        fila.add(raiz);
        visitados.add(raiz);

        while (!fila.isEmpty()) {
            String atual = fila.poll();
            componente.add(atual);
            for (String vizinho : grafo.getOrDefault(atual, Collections.emptySet())) {
                if (visitados.add(vizinho)) {
                    fila.add(vizinho);
                }
            }
        }

        return componente;
    }

    private String normalizar(String valor) {
        if (valor == null) {
            return null;
        }
        String trimmed = valor.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
