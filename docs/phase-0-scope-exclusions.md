# Phase 0 Scope Exclusions

Phase 0 guarantees complete rendering and identity coverage of the approved,
pinned Z-Anatomy-derived catalog. It does not promise a bespoke mesh for every
term in an external anatomical terminology.

The independent TA98 audit found 42 skeletal-muscle terms that do not have an
independently selectable mesh in the baseline. On 2026-08-10 these were approved
as non-blocking scope exclusions for Phase 0 and the workout-summary MVP. The exact
codes and names are retained in `data/anatomy/phase0_scope_exclusions.json`.

This decision is explicit rather than a claim that the terms are represented:

- They are absent from the canonical catalog and will not appear in search,
  selection, exercise mappings, or coverage totals.
- BodySim does not substitute a nearby muscle and claim it is the omitted term.
- They do not block 100% coverage of the selected 960-structure baseline catalog.
- They may be reconsidered later if a product use case requires them and a coherent,
  attributable mesh becomes available.

The excluded set consists primarily of auditory-ossicle muscles, facial and tongue
muscles, highly subdivided deep spinal muscles, sex-specific pelvic/perineal muscles,
soft-palate and pharyngeal muscles, and tiny articular muscles. These structures do
not materially improve conventional exercise-exposure summaries.

Fallback geometry previously investigated for 14 terms was intentionally removed.
It mixed sources and morphology, required unresolved licensing or anatomical review,
and did not justify becoming part of the canonical visual asset.
