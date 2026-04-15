package br.com.m360.importacao.repository;

import br.com.m360.importacao.model.IntegranteImportado;
import br.com.m360.importacao.model.ObraImportada;
import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@Repository
public class ObraRepository {

    private final Jdbi jdbi;

    public ObraRepository(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public long inserirObra(ObraImportada obra) {
        return jdbi.withHandle(h -> h.createUpdate("""
                INSERT INTO obras.obra (
                    id_tenant, id_configuracao, codigo, titulo, iswc,
                    situacao, cod_tipo_versao, cancelada, retida, gravada,
                    instrumental, importado, nacional, registro,
                    controlada, controle_pr, controle_mr, controle_sr, criacao
                ) VALUES (
                    38, 61, :codigo, :titulo, :iswc,
                    'L', 'ORI', false, false, false, false, true, true, :registro,
                    false, 0, 0, 0, now()
                )
                """)
                .bind("codigo", obra.getAtlasId())
                .bind("titulo", obra.getTitulo())
                .bind("iswc", obra.getIswc())
                .bind("registro", LocalDate.now())
                .executeAndReturnGeneratedKeys("id")
                .mapTo(Long.class)
                .one());
    }

    public void inserirTituloAlternativo(long idObra, String titulo) {
        jdbi.withHandle(h -> h.createUpdate("""
                INSERT INTO obras.obra_titulo (id_obra, titulo, cod_tipo_titulo, ativo, criacao)
                VALUES (:idObra, :titulo, 'AL', true, now())
                """)
                .bind("idObra", idObra)
                .bind("titulo", titulo)
                .execute());
    }

    private static final long ID_MUSICA_360 = 2405890L;

    /** Obra já importada com este {@code codigo} (ex.: {@code atlas_id}). */
    public Optional<Long> buscarIdObraPorCodigo(String codigo) {
        return jdbi.withHandle(h -> h.createQuery("""
                SELECT id FROM obras.obra
                WHERE codigo = :codigo AND id_tenant = 38
                LIMIT 1
                """)
                .bind("codigo", codigo)
                .mapTo(Long.class)
                .findFirst());
    }

    /** Links em que a obra já tem integrante Música 360 (não inserir duplicata). */
    public Set<Integer> buscarLinksComMusica360(long idObra) {
        List<Integer> links = jdbi.withHandle(h -> h.createQuery("""
                SELECT DISTINCT link FROM obras.obra_integrante
                WHERE id_obra = :idObra AND id_pessoa = :idM360
                """)
                .bind("idObra", idObra)
                .bind("idM360", ID_MUSICA_360)
                .mapTo(Integer.class)
                .list());
        return new HashSet<>(links);
    }

    /** Detecta se a obra já possui integrante com {@code ip_name = MUSICA 360 EDITORA LTDA}. */
    public boolean existeMusica360EditoraPorIpName(long idObra) {
        return jdbi.withHandle(h -> h.createQuery("""
                SELECT EXISTS (
                    SELECT 1
                    FROM obras.obra_integrante oi
                    JOIN pessoas.pessoa p ON p.id = oi.id_pessoa
                    WHERE oi.id_obra = :idObra
                      AND upper(trim(coalesce(p.ip_name, ''))) = 'MUSICA 360 EDITORA LTDA'
                )
                """)
                .bind("idObra", idObra)
                .mapTo(Boolean.class)
                .one());
    }

    public void inserirIntegrante(long idObra, IntegranteImportado i) {
        if (i.isOmitirInsercao()) {
            return;
        }
        jdbi.withHandle(h -> h.createUpdate("""
                INSERT INTO obras.obra_integrante (
                    id_obra, id_pessoa, cod_territorio, cod_categoria,
                    controlado, percentual_pr, percentual_mr, percentual_sr, percentual_base,
                    coleta_pr, coleta_mr, coleta_sr,
                    fonomecanico, sincronizacao, digital, execucao_publica,
                    link, sequencia, criacao
                ) VALUES (
                    :idObra, :idPessoa, '76', :codCategoria,
                    :controlado, :percentualPr, :percentualMr, :percentualSr, :percentualBase,
                    :coletaPr, :coletaMr, :coletaSr,
                    :fonomecanico, :sincronizacao, :digital, :execucaoPublica,
                    :link, :sequencia, now()
                )
                """)
                .bind("idObra", idObra)
                .bind("idPessoa", i.getIdPessoa())
                .bind("codCategoria", i.getCodCategoria())
                .bind("controlado", i.isControlado())
                .bind("percentualPr", i.getPercentualPr())
                .bind("percentualMr", i.getPercentualMr())
                .bind("percentualSr", i.getPercentualSr())
                .bind("percentualBase", i.getPercentualBase())
                .bind("coletaPr", i.getColetaPr())
                .bind("coletaMr", i.getColetaMr())
                .bind("coletaSr", i.getColetaSr())
                .bind("fonomecanico", i.getFonomecanico() != null ? i.getFonomecanico() : 0.0)
                .bind("sincronizacao", i.getSincronizacao() != null ? i.getSincronizacao() : 0.0)
                .bind("digital", i.getDigital() != null ? i.getDigital() : 0.0)
                .bind("execucaoPublica", i.getExecucaoPublica() != null ? i.getExecucaoPublica() : 0.0)
                .bind("link", i.getLink())
                .bind("sequencia", i.getSequencia())
                .execute());
    }

    public void atualizarControle(long idObra, double controleMr, double controleSr) {
        jdbi.withHandle(h -> h.createUpdate("""
                UPDATE obras.obra SET controlada=true, controle_mr=:mr, controle_sr=:sr
                WHERE id=:id AND id_tenant=38
                """)
                .bind("id", idObra)
                .bind("mr", controleMr)
                .bind("sr", controleSr)
                .execute());
    }
}
