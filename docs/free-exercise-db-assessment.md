# free-exercise-db Assessment

## Decision

**Adopt as a quarantined exercise-catalog seed, not as an anatomical or
biomechanical source.**

The dataset is valuable for giving BodySim a broad searchable vocabulary of exercise
names, equipment, categories, and candidate aliases. Its `primaryMuscles` and
`secondaryMuscles` fields are unsuitable for direct use in engagement profiles or
workout scoring.

BodySim must never expand one of its broad labels, such as `quadriceps`, into all
matching canonical muscles. That would manufacture anatomical claims the source does
not make.

## Sources Reviewed

- [Repository and README](https://github.com/yuhonas/free-exercise-db)
- [Combined exercise JSON](https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json)
- [JSON Schema](https://github.com/yuhonas/free-exercise-db/blob/main/schema.json)
- [Unlicense declaration](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE.md)
- [Declared upstream dataset](https://github.com/wrkout/exercises.json)

Audit date: **2026-08-10**

The audited `main` combined JSON had SHA-256:

```text
d68a817484964095e6af0be2cdcbcc2c2504168d1d190c7d5c725ce52f3ae1f4
```

This checksum identifies the research snapshot; production ingestion must pin a Git
commit rather than following `main`.

## What the Dataset Actually Contains

The current combined JSON audit found:

| Property | Result |
|---|---:|
| Exercise records | 873 |
| Unique source IDs | 873 |
| Case-insensitive unique names | 873 |
| Records with exactly one primary label | 873 |
| Records with no secondary label | 272 |
| Records with no force value | 29 |
| Records with no mechanic value | 87 |
| Records with no equipment value | 77 |
| Records with empty instructions | 5 |

The catalog covers strength, stretching, plyometrics, powerlifting, Olympic
weightlifting, strongman, and cardio. It includes useful fields for:

- Exercise name and source ID.
- Equipment.
- Difficulty level.
- Push, pull, or static force category.
- Compound or isolation mechanic.
- Broad exercise category.
- Instructions.
- Two referenced images per record in the current snapshot.
- Broad primary and secondary muscle labels.

The README itself identifies `force`, `mechanic`, and `equipment` as incomplete fields.

## The Anatomical Ceiling

The schema permits only these 17 muscle labels:

```text
abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes,
hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders,
traps, triceps
```

These are fitness-region labels, not anatomical structures. The taxonomy cannot
express:

- Canonical BodySim muscle IDs.
- Left versus right.
- Individual muscles within a group.
- Heads, portions, or mechanically meaningful subdivisions.
- Agonist, synergist, antagonist, and stabilizing roles beyond a binary
  primary/secondary split.
- Relative involvement coefficients.
- Contraction type, range-of-motion dependence, or phase of movement.
- Confidence, evidence, or competing interpretations.
- Technique-sensitive variants.

Every one of the 873 records has exactly one primary label. This is a strong signal
that the field is a catalog classification, not a complete statement of muscular
involvement.

## Ab Roller Example

The source record classifies Ab Roller as:

```json
{
  "primaryMuscles": ["abdominals"],
  "secondaryMuscles": ["shoulders"]
}
```

This is directionally understandable for exercise discovery, but it is not an
anatomically correct mapping. `abdominals` does not distinguish rectus abdominis,
external oblique, internal oblique, or transversus abdominis. `shoulders` likewise
does not identify any muscle, side, portion, or role. Other trunk and shoulder-girdle
stabilization cannot be represented by the schema at all.

Therefore even the apparently straightforward abdominal example is only a useful
search tag. It must be reviewed and remapped before BodySim presents a muscle-level
result.

## Value to BodySim

### Safe, high-value uses

- Seed the exercise search catalog so users can find familiar names immediately.
- Discover naming variants and candidate aliases.
- Bootstrap equipment, difficulty, category, force, and mechanic filters.
- Group candidates into BodySim movement families for human review.
- Find the 25–40 high-priority variants for the Phase 1 vertical slice.
- Use coarse muscle labels as review queues and sanity-check hints only.
- Use instructions as contextual input when deciding whether two names are aliases or
  mechanically distinct variants.

### Prohibited authoritative uses

- Directly populate BodySim engagement profiles.
- Convert a broad label to every canonical muscle in that region.
- Assign coefficients, stabilizers, or confidence from the source tags.
- Treat `primaryMuscles` as a validated primary mover claim.
- Infer zero exposure for unlisted muscles.
- Use source IDs as BodySim's permanent exercise identity.
- Present the dataset as evidence for activation, force, strain, fatigue, or injury
  risk.

## Proposed Ingestion Boundary

The source data remains separate from BodySim-owned exercise definitions:

```text
Pinned free-exercise-db snapshot
              |
              v
Normalized source catalog (names and metadata; muscle tags are hints)
              |
              v
Explicit review crosswalk
  candidate | accepted | merged_alias | split_into_variants | excluded
              |
              v
Canonical BodySim exercise + mechanically meaningful variant
              |
              v
Independently reviewed engagement profile + evidence
              |
              v
Workout scorer -> all 466 canonical muscles
```

Suggested source crosswalk record:

```json
{
  "source": "free_exercise_db",
  "source_version": "<pinned Git commit>",
  "source_id": "Ab_Roller",
  "review_status": "accepted",
  "body_sim_exercise_ids": ["exercise.ab_wheel_rollout.kneeling"],
  "imported_metadata": ["name", "equipment", "level", "force", "mechanic"],
  "muscle_tags_used_as_evidence": false
}
```

One source record may map to multiple BodySim variants, multiple source records may be
merged as aliases, and some records may be excluded. This many-to-many review boundary
is required because a name is not a stable biomechanical identity.

## Licensing and Provenance

The repository declares the dataset under the Unlicense and says it was restructured
from `wrkout/exercises.json`, which also declares itself public domain. This makes the
structured metadata an attractive candidate for reuse.

However, the reviewed repository pages do not provide per-item provenance for the
exercise photographs or instruction text. A repository-wide license declaration does
not by itself document how each inherited asset was created or acquired. Consequently:

- Metadata ingestion may proceed with the source, version, license, and checksum
  recorded.
- Bundled photographs must not ship in BodySim until an asset-level provenance audit
  establishes redistribution rights.
- Verbatim instruction text should remain quarantined until provenance is resolved;
  BodySim can write its own reviewed instructions for accepted exercises.
- Keep the source license notice with any imported source snapshot.

This is a project risk policy, not legal advice.

## Phase 1 Recommendation

Use free-exercise-db at the beginning of Phase 1A, but only to implement the source
adapter, search vocabulary, and review crosswalk. Then promote 25–40 mechanically
meaningful variants into the canonical catalog and create BodySim-owned engagement
profiles for them.

The result is the best of both worlds: the application starts with broad, familiar
exercise discovery instead of an empty search box, while every colored muscle still
comes from an explicit, versioned, reviewable BodySim claim.
