# Phase 1: Workout Summary MVP

## Status

**Planned.** Phase 0 is complete and supplies the immutable anatomical identity,
geometry, selection, and visualization foundation described in
[`phase-0-completion.md`](phase-0-completion.md).

## Purpose

Phase 1 makes BodySim useful for its original workout-analysis goal. A user enters
the exercises and sets performed in one workout, and BodySim produces:

1. A muscle-by-muscle summary for each exercise.
2. A combined muscle-by-muscle summary for the complete workout.
3. A full-body visualization of those results in Godot.

The hard output requirement is:

> Every workout summary must account for every one of the 466 canonical skeletal
> muscles, including explicit zero exposure, mapped exposure, and unresolved mapping
> states.

Phase 1 is not limited to the body region suggested by an exercise's common name. A
back exercise may engage muscles in the shoulders, arms, trunk, pelvis, or lower body;
all mapped canonical muscle IDs contribute to the same workout result.

## MVP User Experience

The user can:

- Create a workout session.
- Search and add supported exercises.
- Choose an exercise variant when mechanics materially differ, such as grip, stance,
  implement, incline, or unilateral execution.
- Enter sets and repetitions, with optional load, duration, and perceived effort.
- Review each exercise's muscle exposure before or after saving it.
- Review the aggregate workout exposure across the entire canonical musculature.
- Select a muscle to see which exercises contributed to its total.
- Select an exercise to see its primary, secondary, and stabilizing muscles.
- Toggle between raw exposure, normalized workout emphasis, anatomical region, and
  confidence views.
- Save and reload the workout locally.

The initial interface may prioritize desktop mouse and keyboard entry. Mobile layout,
accounts, cloud synchronization, and social features are not Phase 1 requirements.

## Interpretation of “Used to What Degree”

Phase 1 reports **modeled workout exposure**, not literal tissue strain, force,
activation, fatigue, hypertrophy, injury risk, or calories.

Each exercise variant has a versioned engagement profile mapping canonical muscle IDs
to:

- `role`: `primary`, `secondary`, or `stabilizer`.
- `coefficient`: relative involvement from `0.0` to `1.0`.
- `confidence`: `high`, `medium`, or `low`.
- `evidence_status`: `reviewed`, `provisional`, or `unresolved`.
- `evidence_refs`: sources or rationale supporting the mapping.

Each performed set contributes an **exposure unit**:

```text
set exposure = engagement coefficient × set effort factor
```

The MVP effort factor uses deliberately bounded inputs:

```text
effort factor = repetition factor × perceived-effort factor
```

- Repetition factor reflects the amount of performed work without pretending that
  repetitions from unrelated exercises are mechanically equivalent.
- Perceived-effort factor uses RPE or repetitions-in-reserve when provided and a
  documented neutral default otherwise.
- External load is recorded and displayed but is not directly compared across
  mechanically different exercises in the initial scoring formula.
- Timed/isometric exercises use duration instead of repetitions.

For muscle `m`, exercise `e`, and its performed sets `s`:

```text
exercise_exposure[m, e] = Σs(coefficient[m, e] × effort_factor[s])
workout_exposure[m]     = Σe(exercise_exposure[m, e])
```

The summary exposes both:

- **Raw exposure units**, which remain additive across the workout.
- **Workout emphasis from 0–100**, normalized against the highest-exposure muscle in
  that workout for visualization and comparison within that session.

Normalization never replaces the raw value. A score of `100` means “highest modeled
exposure in this workout,” not maximal physiological capacity.

## Zero, Unknown, and Confidence Semantics

These states must never be conflated:

| State | Meaning |
|---|---|
| `zero` | The exercise profile was reviewed and assigns no meaningful exposure. |
| `mapped` | A nonzero coefficient exists for the canonical muscle. |
| `unresolved` | The profile lacks enough evidence to make a claim. |
| `not_applicable` | The canonical structure is not skeletal muscle or is outside this scoring output. |

The 466-muscle summary includes every muscle. Unmapped or uncertain anatomy cannot be
silently reported as zero. Confidence is aggregated conservatively so a low-confidence
contribution remains visible in the workout result.

## Exercise Identity and Variants

Exercise names are not stable identifiers. Phase 1 assigns stable IDs to the movement
and mechanically meaningful variants, for example:

```text
exercise.barbell_back_squat.high_bar
exercise.barbell_back_squat.low_bar
exercise.pull_up.pronated
exercise.chin_up.supinated
exercise.row.cable.seated_neutral_grip
```

Cosmetic naming differences become aliases. A new variant is required when grip,
stance, implement, range of motion, support, or unilateral execution changes the
muscle mapping enough to matter.

Profiles may map muscles from any anatomical region. There is no upper-body versus
lower-body partition in scoring; those categories are only filters in the interface.

## Initial Exercise Catalog

Phase 1 should begin with a reviewed vertical slice rather than hundreds of shallow
exercise entries. The initial catalog should cover representative movement families:

- Squat and split-squat patterns.
- Hip hinges and deadlift variants.
- Horizontal and vertical pushes.
- Horizontal and vertical pulls.
- Loaded carries.
- Elbow flexion and extension.
- Knee flexion and extension.
- Ankle plantarflexion and dorsiflexion.
- Trunk flexion, extension, lateral flexion, and anti-rotation.
- Hip abduction, adduction, flexion, and extension.

A target of approximately 25–40 reviewed variants is sufficient for the MVP if those
profiles exercise the complete data model. Catalog size may not substitute for mapping
quality.

[`free-exercise-db`](free-exercise-db-assessment.md) will seed the searchable source
catalog and review queue. Its 873 names and general metadata are useful for discovery,
but its 17 broad muscle-region labels are not engagement evidence. Only explicitly
reviewed records are promoted into the canonical 25–40-variant MVP catalog.

Proposed repository layout:

```text
data/anatomy/
└── muscle_actions.json

data/exercises/
├── exercises.json
├── engagement_profiles.json
├── opensim_calibration.json
├── evidence.json
├── aliases.json
└── sources/
    ├── free_exercise_db.json
    └── crosswalk.json

data/workouts/
└── example_workout.json

reports/
├── exercise_mapping_coverage.json
├── exercise_mapping_coverage.md
├── example_workout_summary.json
└── example_workout_summary.md
```

### Muscle Action Matrix definition (`data/anatomy/muscle_actions.json`)

Maps each of the 466 canonical muscle IDs to its anatomical joint degrees of freedom, movement vector polarities, and stabilizer capabilities:

```json
{
  "muscle_id": "muscle.rectus_femoris.left",
  "spanned_joints": ["hip_joint.left", "knee_joint.left"],
  "actions": [
    {"joint": "knee_joint", "movement": "extension", "type": "primary"},
    {"joint": "hip_joint", "movement": "flexion", "type": "synergist"}
  ],
  "stabilization_capabilities": ["anti_extension_hip"]
}
```

### Kinematic Exercise definition (`data/exercises/exercises.json`)

```json
{
  "id": "exercise.barbell_back_squat.high_bar",
  "name": "Barbell Back Squat",
  "variant": "High bar stance",
  "aliases": ["squat", "back squat"],
  "movement_families": ["squat"],
  "laterality": "bilateral",
  "input_mode": "repetitions",
  "kinematic_profile": {
    "kinetic_chain_type": "closed_chain",
    "primary_joint_actions": [
      {"joint": "hip_joint", "movement": "extension"},
      {"joint": "knee_joint", "movement": "extension"}
    ],
    "load_vector": "axial_compression_c7",
    "stabilization_demands": ["anti_flexion_spine", "anti_flexion_trunk"]
  }
}
```

### Generated / Derived Engagement profile entry (`data/exercises/engagement_profiles.json`)

```json
{
  "muscle_id": "muscle.rectus_femoris.left",
  "role": "primary",
  "coefficient": 0.85,
  "confidence": "high",
  "evidence_status": "kinematic_trace",
  "derivation_method": "kinematic_tracer_v1",
  "evidence_refs": ["rule.knee_extension.primary_mover"]
}
```

### OpenSim Calibration Anchor (`data/exercises/opensim_calibration.json`)

```json
{
  "exercise_id": "exercise.barbell_back_squat.high_bar",
  "opensim_model": "rajagopal_2016",
  "primary_mover_muscle_id": "muscle.rectus_femoris.left",
  "opensim_force_n": 1420.5,
  "opensim_activation": 0.88,
  "confidence": "high"
}
```

### Performed workout exercise (`data/workouts/example_workout.json`)

```json
{
  "exercise_id": "exercise.barbell_back_squat.high_bar",
  "sets": [
    {"repetitions": 8, "load_kg": 100, "rpe": 8},
    {"repetitions": 8, "load_kg": 100, "rpe": 8.5}
  ]
}
```

All muscle references must resolve to IDs in `data/anatomy/structures.json`. Display
names are never used as foreign keys.

## Architecture

```text
Canonical Anatomy Catalog (466 Muscle IDs)
              ↓
  Muscle Action Matrix (data/anatomy/muscle_actions.json)
              ↓
  Kinematic Exercise Definitions (Joint actions + load vectors)
              ↓
  Kinematic Tracer Engine (Kinematic chain traversal & synergist propagation)
              ↓
  OpenSim Calibration Scaling (F_m = c_m × F_primary_OpenSim)
              ↓
  Derived Versioned Engagement Profiles (100% 466-muscle coverage)
              ↓
  Performed Workout Session
              ↓
  Deterministic Exposure Scorer
    ↙ per exercise          ↘ workout aggregate
  Machine-readable summary  Godot presentation model (Mesh colors via structure_registry.gd)
```

The scorer must be independent of Godot rendering. Given the same versioned catalog,
profiles, and workout JSON, it must produce byte-stable numerical results regardless
of interface state.

The Godot layer consumes canonical muscle IDs and applies results through the existing
Phase 0 structure registry. It must not contain a second exercise-to-mesh mapping.

## Work Breakdown

### Phase 1A: Schemas & Kinematic-Aware Data Contracts

1. Define stable schemas & Python validators for:
   - `muscle_actions.json`: Anatomical function matrix mapping 466 muscles to joints and action polarities.
   - `exercises.json`: Kinematic exercise schema (joint actions, kinetic chain types, load vectors, stabilization demands).
   - `engagement_profiles.json`: Derived profile schema with derivation provenance (`kinematic_trace`, `opensim_calibrated`, `manual_override`).
   - `opensim_calibration.json`: Physics anchor calibration entries.
   - `workouts.json`: Workout session and set input schema.
2. Build the `free-exercise-db` source adapter and review crosswalk (`crosswalk.json`) mapping catalog names/aliases to BodySim kinematic exercises.
3. Add valid and invalid fixture tests for all schemas.

Deliverables:
- `data/anatomy/muscle_actions.json` schema & base rules.
- `data/exercises/exercises.json` schema.
- Pinned `free_exercise_db` source adapter & normalized catalog.
- Review crosswalk (`crosswalk.json`).
- Python JSON schema validators and pytest suite.

### Phase 1B: Kinematic Tracer Engine & Profile Generator

1. Build `tools/exercises/kinematic_tracer.py`:
   - Step through the skeletal joint tree for an exercise's load vector and joint DOFs.
   - Propagate force demands to primary movers, synergists, bi-articular counter-torque muscles, and axial stabilizers.
   - Compute relative engagement coefficients $c_m \in [0.0, 1.0]$ across all 466 canonical skeletal muscles.
2. Generate initial `data/exercises/engagement_profiles.json` for 25–40 MVP exercise variants with 100% full-body coverage.
3. Produce a profile coverage report distinguishing `kinematic_trace`, `opensim_calibrated`, and `unresolved` states.

Deliverables:
- Kinematic Tracer engine module (`tools/exercises/kinematic_tracer.py`).
- 25–40 generated engagement profiles with 100% 466-muscle coverage.
- Profile coverage report generation tool.

### Phase 1C: OpenSim Calibration & Exposure Scorer

1. Build OpenSim calibration anchor scaling module:
   - Calculate scaled force/activation estimates ($F_m = c_m \times F_{\text{primary}}^{\text{OpenSim}}$) when OpenSim physics data is available.
2. Build the deterministic workout exposure scorer:
   - Calculate effort factors, per-set exposure, per-exercise exposure, and aggregate 466-muscle workout values (raw + 0–100 normalized emphasis).
3. Add golden-file unit tests verifying byte-stable outputs across representative workouts.

Deliverables:
- OpenSim calibration & workout exposure scoring engine.
- Machine-readable workout summary output.
- Pytest suite and golden summary benchmarks.6. Preserve contribution provenance and confidence.
7. Add golden-file tests for representative workouts.

Deliverables:

- A rendering-independent scoring module.
- Machine-readable workout summary.
- Unit tests and golden summaries.

### Phase 1D: Workout entry interface

1. Add exercise search and variant selection. **Implemented:** the Godot preview loads
   all currently supported canonical exercises, groups them by movement family, and
   renders the selected variant's engagement profile as a full-body heatmap. The
   selector also lists every affected canonical muscle grouped by role, with its
   coefficient and confidence. Derivation and evidence references remain available in
   each structure's tooltip;
   selecting a result focuses that structure on the body.
   Right-clicking an exercise opens an editor-authored modal with its locally imported
   free-exercise-db starting and movement-position images. The media manifest records
   the source record, license declaration, local resource paths, and checksums.
2. Add, edit, duplicate, reorder, and remove sets.
3. Support repetitions and timed exercises.
4. Save and reload local workout sessions.
5. Show validation errors without discarding entered data.

### Phase 1E: Full-body workout summary

1. Color all 466 muscles by raw exposure or normalized emphasis.
2. Show explicit zero and unresolved states with distinct presentation.
3. Switch between individual exercise and whole-workout results.
4. Show each selected muscle's exercise contribution breakdown.
5. Preserve Phase 0 search, tree, picking, layer controls, and camera interaction.
6. Generate an example workout report without manual bookkeeping.

## Acceptance Criteria

Phase 1 passes only when:

1. A user can create, save, reload, and edit a workout containing multiple exercises
   and sets.
2. Every supported exercise variant resolves to one versioned engagement profile.
3. Every profile muscle reference resolves to a canonical Phase 0 muscle ID.
4. The scorer produces individual-exercise and combined-workout results.
5. Every result contains exactly all 466 canonical skeletal muscles.
6. Zero, unresolved, and nonzero exposure are distinguishable.
7. Raw exposure is additive and normalized emphasis is reproducible.
8. Cross-region engagement works without special cases; a single exercise can affect
   upper body, trunk, pelvis, and lower body simultaneously.
9. Bilateral and unilateral variants preserve correct laterality.
10. Every nonzero coefficient has a role, confidence, and evidence status.
11. Selecting a muscle identifies every contributing exercise and amount.
12. Selecting an exercise displays every mapped muscle and role.
13. Godot colors meshes exclusively through canonical IDs from the Phase 0 registry.
14. Golden tests prove deterministic scoring for representative workouts.
15. The interface makes clear that values are modeled exposure rather than measured
    physiological strain.

## Explicit Exclusions

- Skeletal animation and exercise-specific character motion.
- Muscle deformation.
- OpenSim or MuscleMimic runtime simulation.
- EMG-derived personalized activation.
- Exact muscle force, fiber strain, tendon load, or joint reaction force.
- Fatigue, recovery, soreness, hypertrophy, or injury prediction.
- Medical or rehabilitation recommendations.
- Automatic exercise recognition from video or wearable sensors.
- User accounts, cloud synchronization, and social features.

These capabilities may refine later phases, but none may change the stable Phase 0
muscle identities or silently rewrite historical workout summaries.

## Known Limitations and Guardrails

- Exercise coefficients are curated model inputs, not universal biological facts.
- Imported catalog muscle tags are triage hints only and may never populate engagement
  profiles or turn unlisted muscles into reviewed zeroes.
- Technique, anthropometry, range of motion, intent, tempo, fatigue, and equipment can
  materially change recruitment.
- Stabilizer mappings are especially sensitive to technique and should avoid false
  precision.
- Load cannot be compared naively between exercises with different mechanics.
- Confidence and profile version must remain attached to every saved summary.
- Updating a profile must not silently change an already saved historical workout;
  recalculation requires an explicit action and records the new profile version.

## Relationship to Later Phases

Phase 1 establishes the application data flow:

```text
exercise input → canonical muscle exposure → workout aggregation → 3D visualization
```

Later phases can replace or calibrate curated coefficients with OpenSim,
MuscleMimic, EMG literature, motion capture, or personalized simulation. They must
produce results against the same canonical muscle IDs, allowing Phase 1 workouts and
the Phase 0 visualizer to remain compatible.

Catalog-scale LLM-assisted definition authoring, deterministic candidate gating, and
human/model council review are specified separately in
[`phase-2-exercise-catalog-council.md`](phase-2-exercise-catalog-council.md).
