# Phase 0: Full-Body Musculoskeletal Coverage

**Status: COMPLETE.** The acceptance evidence is summarized in
[`phase-0-completion.md`](phase-0-completion.md).

## Purpose

Phase 0 establishes the anatomical asset foundation for BodySim. It is not a regional prototype or a representative sampling of convenient muscle groups. It must prove that BodySim can render and identify the complete adult musculoskeletal system from skull to toes.

The hard requirement is:

> BodySim must render the entire canonical adult musculoskeletal system, with every available bone and skeletal muscle represented, identifiable, and accounted for.

Phase 0 is incomplete if structures are silently omitted because an enhanced mesh is unavailable, difficult to import, too small, deeply placed, or irrelevant to common workouts.

The approved product catalog is the pinned, curated Z-Anatomy-derived catalog. An
independent terminology audit is used to expose the limits of that atlas, not to expand
Phase 0 into a promise to model every official anatomical term. Terms absent from the
baseline are listed in `data/anatomy/phase0_scope_exclusions.json`; they are explicitly
outside Phase 0 and are never claimed as represented.

## Scope

### Included

- The complete canonical adult skeleton.
- All skeletal muscles represented by the selected canonical source atlas.
- Left, right, median, and unpaired structures.
- Muscle heads and named subdivisions where the source distinguishes them.
- Tendons, aponeuroses, and attachment structures needed to understand the musculoskeletal anatomy.
- Static whole-body rendering in Godot.
- Structure search, selection, hiding, isolation, fading, and highlighting.
- A machine-readable manifest and coverage report for every imported structure.
- Attribution and licensing provenance for every source asset.

### Excluded

- Skeletal animation.
- Muscle deformation.
- Exercise scoring.
- Workout entry and aggregation.
- OpenSim or MuscleMimic integration.
- Patient-specific anatomy.
- Every possible anatomical variation or accessory muscle.
- Medical, diagnostic, or injury-risk claims.

These exclusions limit Phase 0 functionality, not anatomical coverage. A structure may be present without exercise metadata, but it may not be absent without being reported as a release-blocking gap.

## Definition of Full Coverage

For Phase 0, “full coverage” means complete canonical adult musculoskeletal coverage relative to the approved anatomical catalog. The catalog must include, at minimum:

### Skeleton

- Skull and mandible.
- Auditory ossicles.
- Hyoid.
- Cervical, thoracic, and lumbar vertebrae.
- Sacrum and coccyx.
- Ribs and sternum.
- Pectoral girdles.
- Upper-limb bones.
- Individual wrist and hand bones.
- Pelvic girdle.
- Lower-limb bones.
- Individual ankle and foot bones.

### Skeletal musculature

- Muscles of the head and neck.
- Superficial and deep muscles of the back.
- Thoracic-wall and respiratory skeletal muscles.
- Abdominal-wall muscles.
- Pelvic-floor and perineal skeletal muscles.
- Axio-appendicular muscles.
- Shoulder and rotator-cuff muscles.
- Arm, forearm, and intrinsic hand muscles.
- Hip and gluteal muscles.
- Thigh and leg muscles.
- Intrinsic foot muscles.

The catalog may exceed this minimum. Once a structure is included in the approved catalog, its presence becomes a hard requirement.

## Source Strategy

**Z-Anatomy provides and defines the complete, internally aligned Phase 0 baseline.**
Supplemental atlases may later improve a cataloged structure's geometry, but external
terminology terms absent from the approved baseline do not require fallback or bespoke
meshes for Phase 0.

Asset substitutions must not change the stable BodySim identity of a structure. For example, `muscle.latissimus_dorsi.left` remains the same entity whether its current mesh comes from Z-Anatomy, Open3DModel, or BodyParts3D.

### Known baseline characteristics

The audited Z-Anatomy Blender archive contains approximately:

- 7,184 total objects.
- 4,569 mesh objects.
- 951 curves.
- 1,660 text objects.
- 1,196,126 stored mesh vertices.
- 2,060,488 polygons.
- 1,944 collections.
- 894 objects in the muscular-system collection.
- 2,218 objects in the skeletal-system collection.
- No armatures.
- No animation actions.

These are source-file counts, not canonical structure counts. Labels, overlays, insertion objects, helpers, duplicates, and named subdivisions must be classified during extraction.

## Licensing Requirements

Every source asset must have recorded provenance and license information before it can be included in a distributable build.

- Do not infer that every item in a mixed-source archive uses the archive’s headline license.
- Record the source project, source URL, source object name, license, attribution text, and modification history.
- Avoid noncommercial textures in any build that may later be distributed commercially.
- Prefer BodySim-created procedural materials over mixed-license source textures.
- Exclude or replace a questionable asset rather than silently treating its license as compatible.

Licensing gaps are release blockers even when the geometry imports successfully.

## Work Breakdown

### Phase 0A: Establish the canonical catalog

Create the authoritative checklist against which coverage is measured.

Tasks:

1. Extract skeletal and muscular structure names from the baseline source.
2. Separate anatomical structures from labels, helpers, overlays, and duplicates.
3. Normalize names, laterality, and hierarchy.
4. Assign each structure a stable BodySim ID.
5. Record named subdivisions and parent-child relationships.
6. Record externally referenced terms absent from the selected atlas as explicit
   represented, excluded, or unresolved dispositions.
7. Have the resulting catalog reviewed for obvious regional omissions.

Example hierarchy:

```text
muscle.biceps_brachii.right
├── muscle.biceps_brachii.right.long_head
└── muscle.biceps_brachii.right.short_head
```

Deliverable:

```text
data/anatomy/structures.json
```

### Phase 0B: Build the whole-body asset pipeline

Create a repeatable Blender preprocessing and GLB export pipeline.

The pipeline must:

1. Remove text labels, cameras, lights, and Blender-only helpers.
2. Preserve every cataloged bone, muscle, and required connective structure.
3. Preserve individual selection boundaries.
4. Normalize scale, orientation, transforms, and laterality.
5. Generate missing mirrored instances where the source provides only one side.
6. Consolidate duplicate materials without merging anatomical identities.
7. Apply BodySim-created materials suitable for runtime highlighting.
8. Attach or emit canonical BodySim IDs.
9. Export regional GLBs.
10. Produce deterministic output so the pipeline can be rerun when source assets change.

Proposed output layout:

```text
assets/anatomy/
├── head_neck.glb
├── torso.glb
├── pelvis.glb
├── upper_limb_left.glb
├── upper_limb_right.glb
├── lower_limb_left.glb
└── lower_limb_right.glb
```

Regional files are an implementation and optimization detail. Godot must assemble them into one complete body:

```text
whole_body.tscn
├── HeadNeck
├── Torso
├── Pelvis
├── UpperLimbLeft
├── UpperLimbRight
├── LowerLimbLeft
└── LowerLimbRight
```

Implementation and reproducibility instructions are recorded in
[`phase-0b-regional-asset-pipeline.md`](phase-0b-regional-asset-pipeline.md).
The generated regional audit is `reports/phase0b_regional_export.json`.

### Phase 0C: Generate the structure manifest and coverage report

Every canonical structure must receive a record connecting its anatomical identity, source geometry, and Godot representation.

Required fields:

| Field | Purpose |
|---|---|
| `id` | Stable canonical BodySim identifier. |
| `name` | User-facing anatomical name. |
| `latin_name` | Latin name when available. |
| `side` | Left, right, median, or unpaired. |
| `system` | Bone, skeletal muscle, tendon, or other included type. |
| `region` | Head, neck, torso, pelvis, upper limb, or lower limb. |
| `parent_id` | Optional canonical parent structure. |
| `source` | Z-Anatomy, Open3DModel, BodyParts3D, or another approved source. |
| `source_object` | Original source object name. |
| `source_url` | Provenance URL. |
| `license` | Applicable asset license. |
| `attribution` | Required attribution text. |
| `godot_scene` | Regional scene containing the structure. |
| `godot_node` | Imported node or lookup key. |
| `visible` | Whether the structure renders successfully. |
| `selectable` | Whether the structure can be identified in the application. |
| `exercise_mapping_status` | `mapped`, `not_yet_mapped`, or `not_applicable`. |
| `confidence` | Confidence in identification and mapping. |

The report must distinguish:

- **Missing mesh:** release blocker.
- **Import failure:** release blocker.
- **Licensing unresolved:** release blocker.
- **Present but not exercise-mapped:** permitted in Phase 0 and explicitly tracked.
- **Mapped with no significant engagement:** a valid zero in later phases.
- **Mapped with uncertain evidence:** allowed only with a visible confidence indicator in later phases.

Example report:

```text
Canonical structures:       812
Mesh assigned:               812 / 812
Imported into Godot:         812 / 812
Visible:                     812 / 812
Selectable:                  812 / 812
Licensing resolved:          812 / 812
Unexplained source objects:    0
Missing structures:            0
```

The final canonical count will be determined by the catalog audit. Phase 0 requires 100% coverage of that catalog rather than a predetermined marketing number.

Proposed outputs:

```text
data/anatomy/mesh_manifest.json
reports/anatomy_coverage.json
reports/anatomy_coverage.md
```

These outputs are now generated by
[`phase-0c-structure-manifest.md`](phase-0c-structure-manifest.md). The current
report has complete geometry identity, selection, and scoped licensing coverage.

### Phase 0D: Build the whole-body Godot proof

Create a Godot scene and interface demonstrating that the complete asset works as one coherent anatomy model.

The current interaction implementation and its remaining work are tracked in
[`phase-0d-godot-interaction.md`](phase-0d-godot-interaction.md).

Required capabilities:

- Render the entire body simultaneously.
- Toggle the complete skeleton and muscular system.
- Toggle superficial and deep structures.
- Navigate every anatomical region.
- Search for any canonical structure.
- Select every structure through search and on-model interaction.
- Hide, isolate, fade, and highlight individual structures.
- Display the canonical name, side, region, source, and coverage status of the selected structure.
- Preserve structure identity across visibility and material changes.
- Load the complete body within an agreed performance budget.
- Maintain an agreed minimum desktop frame rate in the whole-body overview.
- Regenerate the coverage report without manual bookkeeping.

## Performance Policy

Optimization may change how complete anatomy is loaded or rendered. It may not change whether the anatomy exists.

Permitted optimizations:

- Regional GLBs.
- Distance-based levels of detail.
- Loading high-detail regions on demand.
- Shared materials.
- Visibility and frustum culling.
- Simplified overview meshes backed by full-detail selectable structures.
- Instancing mirrored structures when anatomically appropriate.
- GPU-based selection or another indexed selection mechanism instead of thousands of physics colliders.
- Background or staged loading after the initial whole-body overview appears.

Prohibited shortcuts:

- Dropping small or deep muscles.
- Omitting structures that are difficult to select.
- Merging muscles so they cannot be identified individually.
- Omitting the hands, feet, pelvic floor, head, neck, or deep back.
- Including only muscles commonly discussed in fitness applications.
- Treating unavailable Open3DModel regions as optional.
- Reporting an import failure as zero engagement.

## Acceptance Criteria

Phase 0 passes only when all of the following are true:

1. The approved canonical catalog covers the complete adult musculoskeletal system defined above.
2. Every cataloged structure has a resolved, attributable baseline mesh source.
3. Every cataloged structure imports into Godot successfully.
4. Every cataloged structure is visible when requested.
5. Every cataloged structure is individually identifiable and selectable.
6. The assembled scene renders the entire body rather than a regional demonstration.
7. The manifest contains no unexplained source objects that may represent omitted anatomy.
8. The coverage report contains zero missing structures, import failures, and unresolved licenses.
9. The preprocessing pipeline is repeatable and does not depend on undocumented manual edits.
10. Whole-body load time, memory use, and frame rate have been measured and meet explicitly recorded budgets.
11. No performance optimization reduces canonical anatomical coverage.

## Completion Artifacts

Phase 0 is complete when the repository contains:

- The canonical anatomical catalog.
- Source and licensing provenance records.
- A repeatable asset preprocessing pipeline.
- Complete regional GLB outputs or reproducible instructions for generating them.
- A complete whole-body Godot scene.
- Search and structure-selection functionality.
- A machine-readable structure manifest.
- Machine-readable and human-readable coverage reports.
- Performance measurements for the complete scene.
- Documentation of known source limitations that do not constitute missing catalog entries.

## Relationship to Later Phases

Phase 0 establishes presence and identity. Later phases add meaning and behavior:

1. Exercise and workout data reference canonical muscle IDs.
2. Workout scoring produces values against those IDs.
3. Godot applies those values to the meshes recorded in the manifest.
4. OpenSim and MuscleMimic can later replace curated estimates without changing visual structure identities.
5. Animation and deformation can be added without changing the coverage contract.

Full-body anatomical coverage is therefore a foundation of BodySim, not a deferred enhancement.
