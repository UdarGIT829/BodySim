# Phase 0A External Coverage Audit

The Z-Anatomy catalog cannot prove its own completeness. BodySim therefore
compares it against independent anatomical requirements before approving Phase
0A. A missing official term is adjudicated as represented, represented by
components, represented at lower granularity, optional/variable, outside the
skeletal-muscle scope, or an explicit product-scope exclusion.

## References

- FIPAT's *Terminologia Anatomica*, second edition, supplies official
  musculoskeletal terminology.
- The IFAA TA98 online partonomic muscle chapter supplies machine-readable coded
  English and Latin terms. Individual terminology terms are public domain.
- OpenStax *Anatomy and Physiology*, section 7.1, supplies an independent,
  conventional adult-skeleton count and regional organization check.

The pinned links and citations are recorded in the reference and requirements
JSON files rather than being implicit in this document.

## Skeleton result

All 17 executable requirements pass. They explicitly cover:

- the 22 skull bones, six auditory ossicles, and hyoid;
- 24 presacral vertebrae, sacrum, and coccyx;
- 24 ribs and all separately modeled sternum components;
- both pectoral girdles and all upper-limb long bones;
- all 16 carpals, 10 metacarpals, and 28 hand phalanges;
- both hip bones and all lower-limb long bones;
- all 14 tarsals, 10 metatarsals, and 28 foot phalanges.

Ethmoidal air cells are retained as selectable skeletal features but are not
miscounted as separate bones. Foot sesamoids are present but are additional to
the conventional 206-bone checklist.

## Muscle result

The automated comparison audits 228 individual muscle terms directly enumerated
in the official A04.1-A04.7 muscle chapter:

- 188 match catalog structures directly;
- seven composite terms are represented by finer selectable components;
- two terms are represented at lower source granularity;
- seven optional or variable terms are absent and explicitly tracked;
- one pelvic visceral smooth/fibromuscular term is outside BodySim's
  skeletal-muscle scope;
- 22 terms are absent from all 7,184 Z-Anatomy objects and explicitly excluded
  from the Phase 0 product scope.

The redirected chapter audit adds another 52 official muscle terms covering
the tongue, soft palate, pharynx, larynx, perineum, extra-ocular muscles, and
auditory-ossicle muscles. Twenty of those are additional explicit Phase 0 exclusions.

There are zero unadjudicated terms and zero release-blocking terminology gaps.
The 42 absent official terms remain listed in
`data/anatomy/phase0_scope_exclusions.json`; they are not claimed as represented,
but they do not require fallback or bespoke geometry for the workout-summary MVP.

## Important boundary

The automated scope now covers both the A04 muscle chapter and all seven muscle
groups it redirects into other organ chapters. It remains a terminology-to-mesh
audit, not a substitute for review by a qualified anatomist.

## Reproduce

After downloading the official TA98 chapter HTML:

```bash
python3 tools/anatomy/extract_ta98_muscle_reference.py \
  --input /path/to/ta98-muscles.html \
  --output data/anatomy/references/ta98_individual_muscles.json

python3 tools/anatomy/audit_external_coverage.py \
  --catalog data/anatomy/structures.json \
  --reference data/anatomy/references/ta98_individual_muscles.json \
  --dispositions data/anatomy/coverage_dispositions.json \
  --output-json reports/phase0a_external_muscle_coverage.json \
  --output-md reports/phase0a_external_muscle_coverage.md

python3 tools/anatomy/audit_skeleton_coverage.py \
  --catalog data/anatomy/structures.json \
  --requirements data/anatomy/skeleton_coverage_requirements.json \
  --output-json reports/phase0a_external_skeleton_coverage.json \
  --output-md reports/phase0a_external_skeleton_coverage.md
```
