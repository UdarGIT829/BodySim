# Phase 0C: Structure Manifest and Coverage Report

Phase 0C joins the canonical anatomical catalog to the seven production regional
GLBs. Its output is the runtime identity contract that later Godot selection,
exercise scoring, and visualization code will use.

## Outputs

- `data/anatomy/mesh_manifest.json`: one record for each of the 960 canonical
  structures.
- `reports/anatomy_coverage.json`: machine-readable completion checks and exact
  blocking structure IDs.
- `reports/anatomy_coverage.md`: concise human-readable coverage summary.

Each manifest record connects the stable BodySim ID to its original source object,
provenance, current license status, regional GLB, exact glTF node, renderability,
selection status, and future exercise-mapping status.

## Regeneration

Run this after regenerating or auditing the regional GLBs:

```bash
python3 tools/anatomy/generate_structure_manifest.py \
  --catalog data/anatomy/structures.json \
  --source-dir data/anatomy/sources \
  --asset-dir build/anatomy/regions \
  --regional-report reports/phase0b_regional_export.json \
  --display-depth data/anatomy/display_depth.json \
  --manifest data/anatomy/mesh_manifest.json \
  --coverage-json reports/anatomy_coverage.json \
  --coverage-md reports/anatomy_coverage.md
```

The generator fails if the regional assets use a stale catalog hash, omit or
duplicate an ID, place a structure in the wrong asset, lack a mesh, disagree with
catalog metadata, or cite an unknown source record.

## Current result

- Canonical identities resolved: 960 / 960.
- Meshes assigned: 960 / 960.
- Renderable regional nodes: 960 / 960.
- Missing structures: 0.
- Import failures: 0.
- Search-selectable structures: 960 / 960.
- Distribution licenses resolved: 960 / 960 for the pinned musculoskeletal extraction.

`visible` currently means that the audited GLB node contains renderable geometry.
The Godot whole-body runtime test independently verifies that all 960 mesh nodes
instantiate. It does not claim that each individual structure has received manual
visual inspection.

`selectable` means the Phase 0D registry can resolve the manifest record and exact
Godot mesh from a canonical ID. Every structure can be selected through search, and
visible surfaces can also be selected through the physicsless triangle-mesh picker.

The source record preserves Z-Anatomy's CC BY-SA 4.0 grant, required Z-Anatomy and
BodyParts3D attribution, the scope decision excluding separately identified
noncommercial organ/neural assets, and the share-alike distribution obligations.
See [`anatomy-licensing.md`](anatomy-licensing.md).
