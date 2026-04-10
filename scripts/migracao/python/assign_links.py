#!/usr/bin/env python3
"""
T012/T015: Executar atribuição de links (SQL) via cliente psql.

Uso:
  python assign_links.py --host ... --dbname woodstock --user ...

Ou rodar manualmente:
  psql -f ../sql/05_assign_links.sql
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

SQL_FILE = Path(__file__).resolve().parent.parent / "sql" / "05_assign_links.sql"


def main() -> int:
    p = argparse.ArgumentParser(description="Roda 05_assign_links.sql no PostgreSQL.")
    p.add_argument("--host", default="localhost")
    p.add_argument("--port", default="5432")
    p.add_argument("--dbname", required=True)
    p.add_argument("--user", required=True)
    args = p.parse_args()

    if not SQL_FILE.is_file():
        print(f"Arquivo não encontrado: {SQL_FILE}", file=sys.stderr)
        return 1

    cmd = [
        "psql",
        f"-h{args.host}",
        f"-p{args.port}",
        f"-U{args.user}",
        f"-d{args.dbname}",
        "-v",
        "ON_ERROR_STOP=1",
        "-f",
        str(SQL_FILE),
    ]
    return subprocess.call(cmd)


if __name__ == "__main__":
    raise SystemExit(main())
