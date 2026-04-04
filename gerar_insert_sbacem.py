"""
Lê o sbacem.csv e gera um arquivo SQL com INSERTs para mdb.sbacem.
Testa automaticamente o encoding correto.

Uso:
    python gerar_insert_sbacem.py

Saída:
    insert_sbacem.sql  (na mesma pasta do script)
"""

import csv
import os

CSV_PATH = r"C:\Users\Gumercindo\Downloads\sbacem\sbacem.csv"
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "insert_sbacem.sql")
BATCH_SIZE = 500  # INSERTs por bloco


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


def escapar(valor):
    if valor is None or valor == "":
        return "NULL"
    valor = valor.replace("'", "''")
    return f"'{valor}'"


def gerar_sql():
    encoding = detectar_encoding(CSV_PATH)

    colunas = [
        "atlas_id", "original_title", "alternate_titles", "iswc",
        "work_codes", "chain_id", "chain", "ip_name", "ipi_name_number",
        "ipi_base_number", "ip_internal_id", "ip_role", "per_own", "per_soc",
        "mec_own", "mec_soc", "performers", "per_status", "mec_status", "source"
    ]

    total = 0
    erros = 0

    with open(CSV_PATH, encoding=encoding, newline="") as csvfile, \
         open(OUTPUT_PATH, "w", encoding="utf-8") as sqlfile:

        sqlfile.write("-- Gerado automaticamente por gerar_insert_sbacem.py\n")
        sqlfile.write("BEGIN;\n\n")
        sqlfile.write("TRUNCATE mdb.sbacem;\n\n")

        reader = csv.DictReader(csvfile)
        batch = []

        for row in reader:
            try:
                valores = ", ".join(escapar(row.get(col, "")) for col in [
                    "Atlas ID", "Original Title", "Alternate Titles", "ISWC",
                    "Work Codes", "Chain ID", "Chain", "IP Name", "IPI Name Number",
                    "IPI Base Number", "IP Internal ID", "IP role", "PER Own", "PER Soc",
                    "MEC Own", "MEC Soc", "Performers", "PER status", "MEC status", "Source"
                ])
                batch.append(f"({valores})")
                total += 1

                if len(batch) >= BATCH_SIZE:
                    sqlfile.write(
                        f"INSERT INTO mdb.sbacem ({', '.join(colunas)}) VALUES\n"
                        + ",\n".join(batch) + ";\n\n"
                    )
                    batch = []
                    if total % 50000 == 0:
                        print(f"  {total} linhas processadas...")

            except Exception as e:
                erros += 1
                print(f"Erro na linha {total + 1}: {e}")

        # Último batch
        if batch:
            sqlfile.write(
                f"INSERT INTO mdb.sbacem ({', '.join(colunas)}) VALUES\n"
                + ",\n".join(batch) + ";\n\n"
            )

        sqlfile.write("COMMIT;\n")

    print(f"\nConcluído: {total} linhas, {erros} erros.")
    print(f"Arquivo gerado: {OUTPUT_PATH}")


if __name__ == "__main__":
    gerar_sql()
