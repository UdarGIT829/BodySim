# Phase 0A External Muscle Coverage Audit

- Official terms audited: **228**
- Release-blocking gaps: **0**

## Status summary

| Status | Count |
|---|---:|
| `excluded_phase0_reference_only` | 22 |
| `not_separate_structure` | 1 |
| `optional_not_represented` | 7 |
| `out_of_scope_non_skeletal` | 1 |
| `represented` | 188 |
| `represented_by_components` | 7 |
| `represented_lower_granularity` | 2 |

## Unresolved required terms

None.

## Confirmed source gaps

None.

## Explicit Phase 0 scope exclusions

| Code | Official English term | Finding |
|---|---|---|
| `A04.1.03.019` | Depressor supercilii | No candidate or alternate source object exists in the complete Z-Anatomy object index. |
| `A04.1.03.020` | Auricularis anterior | No candidate or alternate source object exists in the complete Z-Anatomy object index. |
| `A04.1.03.021` | Auricularis superior | No candidate or alternate source object exists in the complete Z-Anatomy object index. |
| `A04.1.03.022` | Auricularis posterior | No candidate or alternate source object exists in the complete Z-Anatomy object index. |
| `A04.1.03.027` | Transversus menti | No candidate or alternate source object exists in the complete Z-Anatomy object index. |
| `A04.1.03.036` | Buccinator | No candidate or alternate source object exists in the complete Z-Anatomy object index. |
| `A04.3.01.012` | Anterior cervical intertransversarii | The source has no independently selectable anterior cervical intertransversarii. |
| `A04.3.01.013` | Lateral posterior cervical intertransversarii | The source has no independently selectable lateral posterior cervical intertransversarii. |
| `A04.3.02.209` | Semispinalis capitis | Spinalis capitis exists, but the distinct semispinalis capitis does not. |
| `A04.3.02.402` | Medial lumbar intertransversarii | Only lateral lumbar intertransversarii are present in the source. |
| `A04.3.02.403` | Thoracic intertransversarii | No thoracic intertransversarii candidate exists in the source. |
| `A04.3.02.404` | Medial posterior cervical intertransversarii | No medial posterior cervical intertransversarii candidate exists in the source. |
| `A04.4.01.015` | Subcostales | No subcostales muscle object exists; similarly named source objects are blood vessels. |
| `A04.5.01.018` | Cremaster ♂ | Sex-specific skeletal muscle is absent from the selected baseline and excluded from Phase 0. |
| `A04.5.03.014` | Pubovesicalis | No pubovesicalis mesh exists in the complete source index; retain as a gap pending definitive tissue-scope review. |
| `A04.5.04.004` | Puboperinealis | Named levator ani subdivision is absent from the source. |
| `A04.5.04.005` | Pubovaginalis ♀ | Sex-specific levator ani subdivision is absent from the source. |
| `A04.5.04.005` | Puboprostaticus | Sex-specific levator ani subdivision is absent from the source. |
| `A04.5.04.007` | Puborectalis | Named levator ani subdivision is absent from the source. |
| `A04.6.02.024` | Articularis cubiti | No articularis cubiti object exists in the complete source index. |
| `A04.6.02.053` | Palmaris brevis | No palmaris brevis object exists in the complete source index. |
| `A04.7.02.024` | Articularis genus | Only attachment overlays exist; there is no selectable muscle mesh. |

An unresolved term is not automatically a missing mesh. It must be classified
as a naming mismatch, represented by finer-grained components, outside the
canonical scope, an accepted anatomical variant, a confirmed coverage gap, or an
explicit non-blocking product-scope exclusion. Exclusions are not represented anatomy.
