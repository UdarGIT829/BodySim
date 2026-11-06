# Phase 0 Completion

Phase 0 is complete for BodySim's approved 960-structure canonical adult
musculoskeletal catalog.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Complete approved catalog | Pass | `data/anatomy/structures.json`; Phase 0A audits |
| Attributable mesh for every structure | Pass | `data/anatomy/mesh_manifest.json` |
| Godot import and visibility | 960 / 960 | `reports/anatomy_coverage.json`; Godot runtime test |
| Search and direct selection | 960 / 960 | Registry, anatomy tree, physicsless mesh picker |
| Whole-body assembly | Pass | Seven regional GLBs assembled under `CanonicalBody` |
| Unexplained canonical source objects | 0 | Coverage report |
| Missing structures/import failures | 0 / 0 | Coverage report |
| Licensing resolved | 960 / 960 | `docs/anatomy-licensing.md`; source record |
| Repeatable preprocessing | Pass | Phase 0A/0B generators, audits, deterministic hashes |
| Surface/deep display | 160 / 306 muscles | [`phase-0-depth-classification.md`](phase-0-depth-classification.md) |
| Performance budgets | Pass | `reports/phase0_performance.json` |
| Coverage-preserving optimization | Pass | Performance benchmark loads all 960 meshes |

## Reference performance

The windowed Godot 4.7.1 Forward+ Vulkan measurement at 1152×648 recorded:

- 347.83 ms load-to-ready against a 3,000 ms budget.
- 61,871,186 bytes incremental static memory against a 1 GiB budget.
- 60.00 average FPS against a 30 FPS minimum.
- 16.726 ms 95th-percentile frame time against a 33.34 ms maximum.
- 960 canonical meshes, 999 draw calls, and 1,103,976 rendered primitives.

## Reproduction

```bash
python3 tools/anatomy/generate_display_depth.py \
  --catalog data/anatomy/structures.json \
  --output data/anatomy/display_depth.json

python3 tools/anatomy/generate_structure_manifest.py \
  --catalog data/anatomy/structures.json \
  --source-dir data/anatomy/sources \
  --asset-dir build/anatomy/regions \
  --regional-report reports/phase0b_regional_export.json \
  --display-depth data/anatomy/display_depth.json \
  --manifest data/anatomy/mesh_manifest.json \
  --coverage-json reports/anatomy_coverage.json \
  --coverage-md reports/anatomy_coverage.md

/home/vudar/Applications/Godot_v4.7.1-stable_linux.x86_64 \
  --path /home/vudar/Documents/code/BodySim \
  --script res://tools/anatomy/benchmark_phase0.gd
```

Display-depth classifications are visualization aids rather than diagnostic or
surgical planes. The approved 42 reference-only TA98 exclusions remain explicit and
do not count as represented canonical anatomy. Animation, exercise scoring, and
workout aggregation remain intentionally deferred to later phases.
