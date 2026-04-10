#!/usr/bin/env python3
"""
Executa a cadeia de scripts SQL da migração MDB → staging (e opcionalmente validações).

Uso:
  cd scripts/migracao
  python -m venv .venv
  .venv\\Scripts\\activate   # Windows
  pip install -r requirements.txt
  copy .env.example .env     # preencher senha e host

  python run_pipeline.py
  python run_pipeline.py --load-destino     # inclui 02/03/04 (esqueletos / SELECT TODO)
  python run_pipeline.py --validate         # queries de conferência ao final
  python run_pipeline.py --dry-run          # só lista os arquivos que rodariam

Variáveis de ambiente (.env ou shell):
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

try:
    import psycopg2
except ImportError:
    psycopg2 = None  # type: ignore

try:
    import sqlparse
except ImportError:
    sqlparse = None  # type: ignore

try:
    from dotenv import load_dotenv
except ImportError:
    def load_dotenv(*_a, **_k):
        return False


MIGR_DIR = Path(__file__).resolve().parent

# Ordem alinhada a README.md
STEPS_CORE = [
    ("01_staging_tables", MIGR_DIR / "staging" / "01_staging_tables.sql"),
    ("02_populate_staging", MIGR_DIR / "sql" / "populate_staging_from_sbacem.sql"),
    ("03_verify_link_ddl", MIGR_DIR / "ddl" / "verify_obra_integrante_link.sql"),
    ("04_titular_cessao_view", MIGR_DIR / "sql" / "titular_cessao_unificada.sql"),
    ("05_assign_links", MIGR_DIR / "sql" / "05_assign_links.sql"),
    ("06_titular_nome", MIGR_DIR / "sql" / "06_staging_titular_nome.sql"),
    ("07_parcela_view", MIGR_DIR / "sql" / "07_cessao_mr_rateio.sql"),
    ("08_apply_cessao", MIGR_DIR / "sql" / "08_apply_cessao_cedente.sql"),
]

STEPS_LOAD_DESTINO = [
    ("load_02_pessoas_esqueleto", MIGR_DIR / "sql" / "02_load_pessoas_dedup.sql"),
    ("load_03_obras_esqueleto", MIGR_DIR / "sql" / "03_load_obras.sql"),
    ("load_04_integrantes_esqueleto", MIGR_DIR / "sql" / "04_load_integrantes_sbacem_base.sql"),
]

STEPS_M360 = [
    ("09_m360_insert", MIGR_DIR / "sql" / "09_insert_m360_integrantes.sql"),
    ("10_obra_controlada", MIGR_DIR / "sql" / "10_update_obra_controlada_controle_mr.sql"),
]

STEPS_VALIDATE = [
    ("validate_links_aw0", MIGR_DIR / "sql" / "validate_links_three_pairs.sql"),
    ("validate_aw0mtyo2", MIGR_DIR / "sql" / "validate_aw0mtyo2.sql"),
    ("report_chain_dangling", MIGR_DIR / "reports" / "chain_dangling_export.sql"),
    ("report_fallback_empty_chain", MIGR_DIR / "reports" / "fallback_empty_chain.sql"),
    ("validate_soma_100_stub", MIGR_DIR / "sql" / "validate_soma_100_por_obra.sql"),
    ("validate_cardinalidade", MIGR_DIR / "sql" / "validate_cardinalidade_fonte_destino.sql"),
]


def _strip_sql_comments(raw: str) -> str:
    if sqlparse is None:
        return raw
    return sqlparse.format(raw, strip_comments=True).strip()


def run_sql_psycopg2(conn, sql_path: Path) -> None:
    if sqlparse is None:
        raise RuntimeError("Instale sqlparse: pip install -r requirements.txt")
    raw = sql_path.read_text(encoding="utf-8-sig")
    cleaned = _strip_sql_comments(raw)
    if not cleaned:
        return
    with conn.cursor() as cur:
        for stmt in sqlparse.split(cleaned):
            s = str(stmt).strip()
            if not s:
                continue
            cur.execute(s)


def run_sql_psql(sql_path: Path, env: dict) -> None:
    host = env.get("PGHOST", "localhost")
    port = env.get("PGPORT", "5432")
    user = env["PGUSER"]
    db = env["PGDATABASE"]
    cmd = [
        "psql",
        f"-h{host}",
        f"-p{port}",
        f"-U{user}",
        f"-d{db}",
        "-v",
        "ON_ERROR_STOP=1",
        "-f",
        str(sql_path),
    ]
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stderr or r.stdout or "")
        raise RuntimeError(f"psql falhou ({r.returncode}): {sql_path}")


def build_pg_env() -> dict:
    env = os.environ.copy()
    env["PGHOST"] = os.getenv("DB_HOST", "localhost")
    env["PGPORT"] = str(os.getenv("DB_PORT", "5432"))
    env["PGUSER"] = os.getenv("DB_USER", "")
    env["PGDATABASE"] = os.getenv("DB_NAME", "woodstock")
    pwd = os.getenv("DB_PASSWORD", "")
    if pwd:
        env["PGPASSWORD"] = pwd
    return env


def main() -> int:
    parser = argparse.ArgumentParser(description="Pipeline SQL migracao_stg (Woodstock).")
    parser.add_argument(
        "--use-psql",
        action="store_true",
        help="Usar cliente psql no PATH em vez de psycopg2 (útil se sqlparse falhar em algum script).",
    )
    parser.add_argument(
        "--load-destino",
        action="store_true",
        help="Inclui scripts 02/03/04 (hoje em grande parte esqueleto / SELECT TODO).",
    )
    parser.add_argument(
        "--m360",
        action="store_true",
        help="Inclui 09/10 (INSERT/update comentados até DDL pronto).",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        help="Roda SQLs de validação ao final (leitura / checagens).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Lista arquivos sem executar.",
    )
    args = parser.parse_args()

    load_dotenv(MIGR_DIR / ".env")
    load_dotenv()

    steps: list[tuple[str, Path]] = list(STEPS_CORE)
    if args.load_destino:
        steps.extend(STEPS_LOAD_DESTINO)
    if args.m360:
        steps.extend(STEPS_M360)
    if args.validate:
        steps.extend(STEPS_VALIDATE)

    for name, path in steps:
        if not path.is_file():
            print(f"[ERRO] Arquivo ausente: {path}", file=sys.stderr)
            return 1

    if args.dry_run:
        print("Dry-run — arquivos na ordem:")
        for name, path in steps:
            print(f"  {name}: {path}")
        return 0

    if args.use_psql:
        env = build_pg_env()
        if not env.get("PGUSER"):
            print("Defina DB_USER no .env ou ambiente.", file=sys.stderr)
            return 1
        for name, path in steps:
            print(f"==> {name} …")
            run_sql_psql(path, env)
        print("Concluído (psql).")
        return 0

    if psycopg2 is None:
        print("Instale dependências: pip install -r requirements.txt", file=sys.stderr)
        return 1

    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    dbname = os.getenv("DB_NAME", "woodstock")
    user = os.getenv("DB_USER", "")
    password = os.getenv("DB_PASSWORD", "")
    if not user:
        print("Defina DB_USER (e DB_PASSWORD) no .env em scripts/migracao/.env", file=sys.stderr)
        return 1

    conn = psycopg2.connect(
        host=host,
        port=port,
        dbname=dbname,
        user=user,
        password=password,
    )
    # CREATE VIEW / múltiplos UPDATEs no mesmo arquivo: commit por arquivo
    conn.autocommit = False

    try:
        for name, path in steps:
            print(f"==> {name} …")
            run_sql_psycopg2(conn, path)
            conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"[ERRO] {e}", file=sys.stderr)
        return 1
    finally:
        conn.close()

    print("Concluído (psycopg2).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
