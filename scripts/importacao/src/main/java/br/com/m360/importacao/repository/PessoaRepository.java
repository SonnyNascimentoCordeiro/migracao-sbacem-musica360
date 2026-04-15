package br.com.m360.importacao.repository;

import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public class PessoaRepository {

    private final Jdbi jdbi;

    public PessoaRepository(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public Optional<Long> buscarIdPorIpName(String ipiNameNumber) {
        return jdbi.withHandle(h -> h.createQuery(
                "SELECT id FROM pessoas.pessoa WHERE ip_name = :ipName AND id_tenant = 38 LIMIT 1")
                .bind("ipName", ipiNameNumber)
                .mapTo(Long.class)
                .findFirst());
    }

    public Optional<String> buscarNomePorId(Long id) {
        return jdbi.withHandle(h -> h.createQuery(
                "SELECT nome FROM pessoas.pessoa WHERE id = :id AND id_tenant = 38 LIMIT 1")
                .bind("id", id)
                .mapTo(String.class)
                .findFirst());
    }

    /** Primeira letra de `tipo`: {@code F} = PF, {@code J} = PJ — distribuição titular vs titular2. */
    public Optional<String> buscarTipoPorId(Long id) {
        return jdbi.withHandle(h -> h.createQuery(
                "SELECT tipo FROM pessoas.pessoa WHERE id = :id AND id_tenant = 38 LIMIT 1")
                .bind("id", id)
                .mapTo(String.class)
                .findFirst())
                .filter(t -> t != null && !t.isBlank())
                .map(t -> t.substring(0, 1).toUpperCase());
    }
}
