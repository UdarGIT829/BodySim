# Phase 0A External Muscle Coverage Audit

- Official terms audited: **52**
- Release-blocking gaps: **0**

## Status summary

| Status | Count |
|---|---:|
| `excluded_phase0_reference_only` | 20 |
| `not_separate_structure` | 1 |
| `optional_not_represented` | 1 |
| `out_of_scope_non_skeletal` | 2 |
| `represented` | 22 |
| `represented_by_components` | 1 |
| `represented_lower_granularity` | 5 |

## Unresolved required terms

None.

## Confirmed source gaps

None.

## Explicit Phase 0 scope exclusions

| Code | Official English term | Finding |
|---|---|---|
| `A05.1.04.105` | Styloglossus | No styloglossus object exists in the complete source index. |
| `A05.1.04.106` | Superior longitudinal muscle | No superior longitudinal tongue muscle object exists in the complete source index. |
| `A05.1.04.107` | Inferior longitudinal muscle | No inferior longitudinal tongue muscle object exists in the complete source index. |
| `A05.1.04.109` | Vertical muscle | No vertical tongue muscle object exists in the complete source index. |
| `A05.1.04.110` | Palatoglossus | No palatoglossus object exists in the complete source index. |
| `A05.2.01.102` | Levator veli palatini | No levator veli palatini object exists in the complete source index. |
| `A05.2.01.103` | Tensor veli palatini | No tensor veli palatini object exists in the complete source index. |
| `A05.2.01.104` | Musculus uvulae | The uvula surface exists, but no musculus uvulae mesh exists. |
| `A05.3.01.115` | Salpingopharyngeus | No salpingopharyngeus object exists in the complete source index. |
| `A06.2.08.007` | Vocalis | No separately selectable vocalis or internal thyro-arytenoid mesh exists. |
| `A09.2.03.006` | External urethral sphincter ♀ | Female external urethral sphincter is absent from the complete source index. |
| `A09.4.02.016` | External urethral sphincter ♂ | Male external urethral sphincter is absent from the complete source index. |
| `A09.5.02.003` | Superficial transverse perineal muscle | No superficial transverse perineal muscle object exists. |
| `A09.5.02.004` | Ischiocavernosus | No ischiocavernosus object exists in the complete source index. |
| `A09.5.02.005` | Bulbospongiosus | No bulbospongiosus object exists in the complete source index. |
| `A09.5.03.004` | Deep transverse perineal muscle ♂ | Male deep transverse perineal muscle is absent from the source. |
| `A09.5.03.005` | Compressor urethrae ♀ | Female compressor urethrae is absent from the source. |
| `A09.5.03.006` | Sphincter urethrovaginalis ♀ | Female sphincter urethrovaginalis is absent from the source. |
| `A15.3.02.061` | Tensor tympani | No tensor tympani muscle mesh exists in the complete source index. |
| `A15.3.02.062` | Stapedius | No stapedius muscle mesh exists in the complete source index. |

An unresolved term is not automatically a missing mesh. It must be classified
as a naming mismatch, represented by finer-grained components, outside the
canonical scope, an accepted anatomical variant, a confirmed coverage gap, or an
explicit non-blocking product-scope exclusion. Exclusions are not represented anatomy.
