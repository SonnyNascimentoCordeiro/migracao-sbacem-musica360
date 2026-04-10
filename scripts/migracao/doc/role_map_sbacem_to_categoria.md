# Mapa `ip_role` (sbacem) → `cod_categoria` (Woodstock)

Referência: `CLAUDE.md` (distribuição SBACEM) + specs **001**/**002**.

| `ip_role` | `cod_categoria` | Notas |
|-----------|-------------------|--------|
| CA | CA | Composer/Author |
| C | C | Composer |
| A | A | Author |
| AR | AR | Arranger |
| SA | SA | Sub-Author |
| AD | AD | Adaptor |
| TR | TR | Translator |
| E | E | Editor |
| ES | ES | Estranged sub-publisher |
| AM | AM | Administrator |
| PA | PA | Publisher for agreement |
| SE | SE | Sub-editor |
| AQ | AQ | Acquirer |

**Música 360** após cessão: **`SE`** se existir **`E`** no mesmo `numero_link`; senão **`E`** (**FR-010**).

Implementação: manter um `CASE` ou tabela `migracao_stg.role_map` se preferir configurar sem redeploy.
