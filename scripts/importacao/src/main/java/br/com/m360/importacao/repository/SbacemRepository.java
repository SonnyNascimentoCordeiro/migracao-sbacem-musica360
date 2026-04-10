package br.com.m360.importacao.repository;

import br.com.m360.importacao.model.SbacemRow;
import br.com.m360.importacao.model.TitularRow;
import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public class SbacemRepository {

    private final Jdbi jdbi;

    public SbacemRepository(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public List<String> listarAtlasIds() {
        return jdbi.withHandle(h -> h.createQuery("""
                SELECT DISTINCT atlas_id
                FROM mdb.sbacem
                WHERE ignorar IS DISTINCT FROM true
                ORDER BY atlas_id
                """)
                .mapTo(String.class)
                .list());
    }

    public List<SbacemRow> listarPorAtlasId(String atlasId) {
        return jdbi.withHandle(h -> h.createQuery("""
                SELECT atlas_id, original_title, alternate_titles, iswc,
                       chain_id, chain, ip_name, ipi_name_number, ipi_base_number,
                       ip_role, per_own, mec_own
                FROM mdb.sbacem
                WHERE atlas_id = :atlasId AND ignorar IS DISTINCT FROM true
                ORDER BY chain_id
                """)
                .bind("atlasId", atlasId)
                .map((rs, ctx) -> {
                    SbacemRow row = new SbacemRow();
                    row.setAtlasId(rs.getString("atlas_id"));
                    row.setOriginalTitle(rs.getString("original_title"));
                    row.setAlternateTitles(rs.getString("alternate_titles"));
                    row.setIswc(rs.getString("iswc"));
                    row.setChainId(rs.getString("chain_id"));
                    row.setChain(rs.getString("chain"));
                    row.setIpName(rs.getString("ip_name"));
                    row.setIpiNameNumber(rs.getString("ipi_name_number"));
                    row.setIpiBaseNumber(rs.getString("ipi_base_number"));
                    row.setIpRole(rs.getString("ip_role"));
                    row.setPerOwn(rs.getString("per_own"));
                    row.setMecOwn(rs.getString("mec_own"));
                    return row;
                })
                .list());
    }

    public Optional<TitularRow> buscarTitular(String ipiBase) {
        return jdbi.withHandle(h -> h.createQuery("""
                SELECT nome, cae, ipi, percentual
                FROM mdb.titular
                WHERE ipi = :ipi LIMIT 1
                """)
                .bind("ipi", ipiBase)
                .map((rs, ctx) -> {
                    TitularRow row = new TitularRow();
                    row.setNome(rs.getString("nome"));
                    row.setCae(rs.getString("cae"));
                    row.setIpi(rs.getString("ipi"));
                    row.setPercentual(rs.getString("percentual"));
                    return row;
                })
                .findFirst());
    }
}
