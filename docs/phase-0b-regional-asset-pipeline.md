# Phase 0B Regional Asset Pipeline

Phase 0B converts the pinned canonical Blender atlas into seven runtime assets while
preserving every stable BodySim identity:

| Asset | Canonical structures |
|---|---:|
| `head_neck.glb` | 288 |
| `torso.glb` | 186 |
| `pelvis.glb` | 16 |
| `upper_limb_left.glb` | 97 |
| `upper_limb_right.glb` | 97 |
| `lower_limb_left.glb` | 138 |
| `lower_limb_right.glb` | 138 |

The partition is an implementation boundary, not a coverage boundary. Godot assembles
all seven under `CanonicalBody`, and each catalog ID must occur exactly once.

## Build

```bash
blender --background /path/to/Startup.blend \
  --python tools/anatomy/blender_export_canonical_regions.py -- \
  --catalog data/anatomy/structures.json \
  --output-dir build/anatomy/regions

python3 tools/anatomy/audit_regional_glbs.py \
  --catalog data/anatomy/structures.json \
  --asset-dir build/anatomy/regions \
  --output-json reports/phase0b_regional_export.json \
  --output-md reports/phase0b_regional_export.md

godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/godot/test_whole_body_preview.gd
```

## Guarantees

- Labels, cameras, lights, animations, source materials, and Blender helpers are not exported.
- All 960 catalog structures retain independent mesh nodes.
- Stable ID, name, system, source region, side, and asset region are embedded as glTF extras.
- The 14 edge-only tendon-sheath sources have their Skin/Subdivision results baked into meshes.
- Limb assets are split by catalog laterality; no limb structure is unpaired.
- The audit fails on a missing mesh, missing ID, duplicate ID, or misplaced regional ID.

Generated GLBs remain git-ignored. Their hashes and sizes are retained in
`reports/phase0b_regional_export.json`.
