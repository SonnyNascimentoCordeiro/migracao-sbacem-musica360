package br.com.m360.importacao.repository;

import br.com.m360.importacao.model.IntegranteImportado;
import br.com.m360.importacao.model.ObraImportada;
import org.jdbi.v3.core.Jdbi;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;

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

    public void inserirIntegrante(long idObra, IntegranteImportado i) {
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
