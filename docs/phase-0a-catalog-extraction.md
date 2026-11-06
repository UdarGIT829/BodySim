# Phase 0A Catalog Extraction

Phase 0A establishes the approved baseline catalog from Z-Anatomy's skeletal,
muscular, and muscle-attachment collections. Extraction is lossless: source objects
excluded as labels, helpers, overlays, or aggregates remain accounted for in the
inventory.

## Approved scope

Phase 0 requires 100% presence and identity coverage of the 960 structures in
`data/anatomy/structures.json`. An independent TA98 terminology audit identified
42 official muscle terms that have no independently selectable baseline mesh. They
are explicit, non-blocking product-scope exclusions—not represented anatomy and not
missing deliverables.

The decision and exact term list are recorded in:

- `data/anatomy/phase0_scope_exclusions.json`
- `docs/phase-0-scope-exclusions.md`
- `reports/phase0a_external_muscle_coverage.json`
- `reports/phase0a_cross_referenced_muscle_coverage.json`

No fallback geometry is part of the canonical asset.

## Outputs

- `data/anatomy/source/z_anatomy_inventory.json` records all audited source
  objects and their classification.
- `data/anatomy/source/z_anatomy_object_index.json` records all 7,184 source
  objects so regional omissions cannot hide in an unexpected collection.
- `data/anatomy/structures.json` contains 960 independently selectable canonical
  structures with stable IDs, system, region, laterality, hierarchy, and provenance.
- `data/anatomy/catalog_curation.json` contains versioned manual curation decisions.
- `reports/phase0a_catalog_review.json` and `.md` summarize the canonical catalog.
- `reports/phase0a_external_skeleton_coverage.json` and `.md` verify the
  conventional complete adult skeleton.
- `reports/phase0a_external_muscle_coverage.json` and
  `reports/phase0a_cross_referenced_muscle_coverage.json` prove that every audited
  terminology term is represented, adjudicated, or explicitly excluded.
- `reports/phase0a_canonical_preview.json` and `.md` verify that all 960
  canonical structures have renderable Godot mesh nodes.

## Reproduce the catalog

Download the pinned archive recorded in `data/anatomy/sources/z_anatomy.json`,
extract `Startup.blend`, and run:

```bash
blender --background /path/to/Startup.blend \
  --python tools/anatomy/extract_z_anatomy_catalog.py -- \
  --output-root . \
  --source-archive-sha256 e029688545627bd0214b269e1063143abb580aad72b2c2445d6d8a9a0d9da736 \
  --source-blend-sha256 9f08a17ea0115fed80b2a73ecdf0a1bc2ab2f6956f37c593ce23d513ea35afcd
```

## Rebuild the catalog-wide geometry proof

```bash
blender --background /path/to/Startup.blend \
  --python tools/anatomy/blender_export_canonical_preview.py -- \
  --catalog data/anatomy/structures.json \
  --output build/anatomy/preview/canonical_preview.glb

python3 tools/anatomy/audit_canonical_preview.py \
  --catalog data/anatomy/structures.json \
  --canonical-glb build/anatomy/preview/canonical_preview.glb \
  --exclusions data/anatomy/phase0_scope_exclusions.json \
  --output-json reports/phase0a_canonical_preview.json \
  --output-md reports/phase0a_canonical_preview.md
```

This monolithic GLB is a catalog-wide extraction check. The production runtime uses
the seven-asset Phase 0B pipeline documented in
[`phase-0b-regional-asset-pipeline.md`](phase-0b-regional-asset-pipeline.md).

Run the project to inspect the canonical preview. Drag to orbit, scroll to zoom,
use `C` for the complete body, `M` for muscles, `B` for bones/teeth/skeletal
features, `K` for cartilage, `T` for connective tissue, and `1`–`6` for
regional camera presets.

Generated GLBs remain under the git-ignored `build/anatomy/` directory.

## Approval boundary

The terminology audit is broader than the product catalog. A term marked
`excluded_phase0_reference_only` is neither silently omitted nor represented; it
is outside the approved baseline. Phase 0 coverage is measured only against the
960 canonical structures, all of which must continue to render and remain
individually identifiable.
