-- T013: Validação AW0MTYO2 — três links distintos para pares A/F, B/G, C/H (spec 002).

WITH w AS (
    SELECT *
    FROM migracao_stg.sbacem_import_staging
    WHERE atlas_id = 'AW0MTYO2'
),
pairs AS (
    SELECT
        BOOL_OR(chain_id = 'A' AND numero_link = 1) AS a_link1,
        BOOL_OR(chain_id = 'F' AND chain = 'A' AND numero_link = 1) AS f_link1,
        BOOL_OR(chain_id = 'B' AND numero_link = 2) AS b_link2,
        BOOL_OR(chain_id = 'G' AND chain = 'B' AND numero_link = 2) AS g_link2,
        BOOL_OR(chain_id = 'C' AND numero_link = 3) AS c_link3,
        BOOL_OR(chain_id = 'H' AND chain = 'C' AND numero_link = 3) AS h_link3,
        COUNT(DISTINCT numero_link) FILTER (WHERE chain_id IN ('A','B','C','F','G','H')) AS distinct_in_group
    FROM w
)
SELECT
    a_link1 AND f_link1 AND b_link2 AND g_link2 AND c_link3 AND h_link3 AS ok_pairs,
    distinct_in_group
FROM pairs;
