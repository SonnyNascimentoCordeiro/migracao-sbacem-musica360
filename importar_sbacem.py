"""
Lê o sbacem.csv e insere diretamente no banco PostgreSQL (mdb.sbacem).
Detecta o encoding correto automaticamente.

Dependência:
    pip install psycopg2-binary

Uso:
    1. Preencha as configurações de conexão abaixo
    2. python importar_sbacem.py
"""

import csv
import os
import psycopg2
from psycopg2.extras import execute_values

# ----------------------------------------------------------------
# CONFIGURAÇÕES DE CONEXÃO — preencher antes de executar
# ----------------------------------------------------------------
DB_HOST     = "207.244.247.148"   # ex: 192.168.1.10 ou db.woodstock.com
DB_PORT     = 46543
DB_NAME     = "woodstock"
DB_USER     = "backstage"
DB_PASSWORD = "Backstage2020#"
# ----------------------------------------------------------------

# Relativo à pasta do script (projeto/arquivos/sbacem2.csv)
CSV_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "arquivos", "sbacem2.csv")
BATCH_SIZE = 1000  # linhas por INSERT


def detectar_encoding(path):
    for enc in ["utf-8-sig", "utf-8", "windows-1252", "latin-1"]:
        try:
            with open(path, encoding=enc, errors="strict") as f:
                for _ in f:
                    pass
            print(f"Encoding detectado: {enc}")
            return enc
        except Exception:
            continue
    raise RuntimeError("Não foi possível detectar o encoding do arquivo.")


def importar():
    encoding = detectar_encoding(CSV_PATH)

    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASSWORD
    )
    conn.autocommit = False
    cur = conn.cursor()

    print("Truncando mdb.sbacem...")
    cur.execute("TRUNCATE mdb.sbacem")

    colunas_csv = [
        "Atlas ID", "Original Title", "Alternate Titles", "ISWC",
        "Work Codes", "Chain ID", "Chain", "IP Name", "IPI Name Number",
        "IPI Base Number", "IP Internal ID", "IP role", "PER Own", "PER Soc",
        "MEC Own", "MEC Soc", "Performers", "PER status", "MEC status", "Source"
    ]
    colunas_db = [
        "atlas_id", "original_title", "alternate_titles", "iswc",
        "work_codes", "chain_id", "chain", "ip_name", "ipi_name_number",
        "ipi_base_number", "ip_internal_id", "ip_role", "per_own", "per_soc",
        "mec_own", "mec_soc", "performers", "per_status", "mec_status", "source"
    ]

    sql = f"INSERT INTO mdb.sbacem ({', '.join(colunas_db)}) VALUES %s"

    total = 0
    batch = []

    with open(CSV_PATH, encoding=encoding, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            valores = tuple(row.get(col) or None for col in colunas_csv)
            batch.append(valores)
            total += 1

            if len(batch) >= BATCH_SIZE:
                execute_values(cur, sql, batch)
                batch = []
                if total % 50000 == 0:
                    print(f"  {total} linhas inseridas...")

        if batch:
            execute_values(cur, sql, batch)

    conn.commit()
    cur.close()
    conn.close()
    print(f"\nConcluído: {total} linhas inseridas em mdb.sbacem.")


if __name__ == "__main__":
    importar()
