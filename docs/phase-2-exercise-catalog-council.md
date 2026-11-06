# Phase 2: Exercise Catalog Authoring and Review Council

## Status

**In progress.** Phases 2A, 2B, 2C, 2D, and 2E are complete (see [`phase-2e-completion.md`](phase-2e-completion.md)). Phase 1 supplies the canonical anatomy, kinematic tracer, engagement
profiles, scoring, exercise selector, heatmap, and imported demonstration-media
foundation. Phase 2 scales the supported catalog without treating unreviewed LLM
output as biomechanical truth.

## Objective

Import every free-exercise-db record as a searchable catalog candidate, use an LLM to
propose structured kinematic definitions, validate and edit those proposals visually,
review frozen revisions through a small council, and promote only accepted definitions
into fully visualizable BodySim exercises.

Catalog availability and biomechanical support are separate states. An exercise may
be searchable and have images without having a trusted heatmap.

## State Machine

```text
catalog_only
    |
    v
authoring_draft <---------------------------+
    |                                       |
    +--> unsupported                        |
    +--> ambiguous                          |
    +--> validation_rejected                |
    |                                       |
    v                                       |
definition_candidate                        |
    |                                       |
    v                                       |
review_pending                              |
    |                                       |
    +--> changes_requested + feedback ------+
    +--> review_rejected
    |
    v
accepted
    |
    v
promoted -> canonical exercise + engagement profile + visualizer
```

An accepted review applies to one immutable definition revision. Editing an accepted
definition creates a new revision and invalidates its prior votes.

## Phase 2A: Complete Catalog and Media Import

**Status: Complete (2026-08-10).**

1. Import all 873 free-exercise-db records into a source catalog.
2. Import their local demonstration images and record checksums, source IDs, source
   URLs, and the repository's license declaration.
3. Retain source instructions, equipment, difficulty, category, mechanic, force, and
   broad muscle tags as quarantined source metadata.
4. Assign every record a catalog status without generating canonical biomechanical
   claims.
5. Record content checksums so exact media duplicates are detectable and can be
   consolidated later without changing selector identities.

Implemented result:

- 873 source candidate records: 853 `catalog_only` and 20 already promoted source
  records mapping to 21 canonical variants.
- 1,746 local JPEG resources covering both images for every source record.
- 894 media-manifest identities: one for every source record and one for each of the
  21 canonical visualizable variants.
- A merged selector containing 874 rows: 853 catalog-only source records plus 21
  canonical variants. The count differs from 873 because the promoted Barbell Squat
  source record intentionally maps to separate high-bar and low-bar variants.
- Catalog-only selection disables the heatmap and explicitly states that definition
  and review are required.
- Right-click image viewing works for catalog-only and visualizable exercises without
  runtime network access.

The exercise selector shows all records. Records without accepted BodySim definitions
are visibly marked **Catalog only** and do not produce a heatmap.

Selecting a catalog-only exercise may show its source metadata, instructions, and
images. It must never infer that omitted muscles have zero exposure.

## Phase 2B: Kinematic Definition Studio

**Status: Complete (2026-08-10).** See `phase-2b-completion.md` for the implemented
workflow, file map, current tracer vocabulary boundary, and verification commands.

Create a standalone Godot scene for authoring one exercise definition at a time.

### Visual layout

The scene should expose:

- Source exercise name, aliases, equipment, instructions, and demonstration images.
- Existing crosswalk matches and possible alias/variant conflicts.
- Canonical BodySim ID and mechanically meaningful variant name.
- Laterality and repetition/duration input mode.
- Open-chain or closed-chain classification.
- A visual joint/action editor rather than a raw JSON-only field.
- Stabilization-demand controls grouped by body region.
- The exact schema-generated JSON in a synchronized advanced editor.
- A structural diff between the last saved revision and the current draft.
- Deterministic validation errors attached to the relevant visual controls.
- A large additional-context field for clarifications or feedback from a failed review.
- Generate, regenerate, validate, save draft, discard, and submit-for-review actions.

LLM output populates editable controls. It never writes directly to canonical
`exercises.json`.

### Authoring response contract

The authoring provider returns a strict schema with:

- `classification`: `supported`, `ambiguous`, or `unsupported`.
- `classification_reasons`.
- `assumptions`.
- `questions_requiring_context`.
- A complete proposed BodySim kinematic definition when supported.
- Confidence for each interpretation-sensitive field.
- Source-instruction excerpts or step numbers used as rationale, without treating
  free-exercise-db muscle tags as evidence.

Ambiguous and unsupported responses cannot become populated candidates.

## Phase 2C: Deterministic Candidate Gate

**Status: Complete (2026-08-10).** See `phase-2c-completion.md` for the isolated
tracer bridge, validation contract, provenance, UI integration, and verification.

Before a proposal becomes `definition_candidate`, local code rejects it when:

- The response fails its JSON Schema.
- Required fields or enumerated values are missing.
- The canonical ID collides with an incompatible exercise.
- Joint actions or stabilization demands are unknown to the tracer.
- Laterality or input mode contradicts required fields.
- A claimed supported definition contains unresolved questions.
- The tracer cannot generate a complete 466-muscle profile.
- Generated coefficients, roles, confidence values, or canonical muscle references
  fail existing validators.
- The model refused, truncated, or returned an incomplete response.

These are deterministic compatibility checks, not proof of biomechanical correctness.
A proposal can pass them and still be rejected during review.

## Phase 2D: Review Council Studio

**Status: Complete (2026-08-10).** See `phase-2d-completion.md` for the immutable
revision boundary, council UI, vote policy, feedback loop, and verification command.

Create a second standalone Godot scene focused on reviewing a frozen candidate
revision.

### Visual layout

The scene should show:

- Source instructions and demonstration images.
- The proposed kinematic definition in visual and JSON forms.
- Assumptions and field-level confidence.
- Tracer-generated affected muscles grouped by role and coefficient.
- The full-body candidate heatmap.
- Differences from aliases, neighboring variants, and any prior revision.
- Deterministic validation results.
- Prior rejection feedback and the author's response to it.
- Separate human and model review decisions.
- A controlled context field used only for this review request.

### Review response contract

The review provider returns a strict schema with:

- `decision`: `accept` or `reject`.
- `summary`.
- `blocking_findings`.
- `non_blocking_findings`.
- Field paths for every finding.
- Suggested corrections.
- Confidence in the review decision.

The review model receives a reviewer system prompt distinct from the authoring prompt.
It critiques the frozen proposal and may not silently rewrite it.

### Initial council policy

The initial council has two members:

1. The human project owner.
2. One OpenAI review provider.

Promotion requires unanimous acceptance by default. Any rejection returns the exact
revision to `changes_requested` with feedback available to the Kinematic Definition
Studio. Council policy is configuration, allowing future majority rules, additional
system prompts, repeated model reviewers, or providers such as Gemini.

## Phase 2E: Promotion

**Status: Complete (2026-11-06).** See [`phase-2e-completion.md`](phase-2e-completion.md).

Promotion is a deterministic transaction:

1. Verify that votes refer to the current immutable revision hash.
2. Re-run all definition, tracer, profile, evidence, and canonical-ID validators.
3. Write or update the canonical exercise definition.
4. Generate and store its versioned engagement profile.
5. Update aliases and the source crosswalk.
6. Mark the source record `promoted` with definition, prompt, model, and review
   provenance.
7. Make the exercise heatmap available in the runtime selector.
8. Preserve all prior drafts, rejected revisions, feedback, votes, and API metadata.

Promotion must be atomic: validation failure leaves canonical product data unchanged.

## Provider Architecture

Godot scenes depend on provider-neutral application interfaces:

```text
Kinematic Definition Studio
        -> AuthoringProvider.generate(request, schema)

Review Council Studio
        -> ReviewProvider.review(request, schema)
```

For the initial internal tool, the scene root owns its provider credentials and model
selection directly:

```gdscript
@export_category("Internal OpenAI")
@export var openai_api_key: String = ""
@export var openai_model: String = "<configured OpenAI model ID>"
```

Both `KinematicDefinitionStudio` and `ExerciseReviewCouncil` expose these fields in the
Inspector. Their controller passes the configured values to the OpenAI provider
adapter. No companion service, environment-variable setup, account screen, or end-user
credential workflow is required.

Provider configuration records:

- Provider ID.
- Model ID and pinned snapshot when available.
- System-prompt ID and version/hash.
- JSON Schema ID and version/hash.
- Reasoning or generation settings.
- Request and response IDs.
- Token usage and latency.
- Timestamp and error information.

OpenAI is the first adapter. Provider interfaces may later support different OpenAI
system prompts, multiple independent OpenAI reviewers, Gemini, or other providers
without changing the scenes or stored definition schema.

## OpenAI Integration and Internal Key Handling

Use the Responses API with a model that supports Structured Outputs. Send the exact
authoring or review JSON Schema with each request and validate the returned object
again locally.

This is an internal authoring application, so the API key is a simple exported String
on the root node of each scene that makes OpenAI requests. The field defaults to empty;
the scene shows a clear validation message and disables generation or review until it
is populated.

The Godot provider adapter calls the Responses API directly with bearer
authentication. It owns JSON Schema enforcement, timeouts, retry behavior, response
parsing, and safe error presentation.

The key must still never be copied into prompts, candidate files, revisions, council
votes, response metadata, screenshots, or logs. Saving a populated exported field
serializes the key into the `.tscn`; that exposure is an accepted constraint of this
internal-only design. The scene should visually identify the field as sensitive and
provide a button to clear it before sharing or committing the project.

If BodySim later becomes distributable, this direct-key design must be replaced before
release. The provider interface remains separate from scene logic so a proxy or Gemini
adapter can replace the initial OpenAI implementation without redesigning the studios.

## Proposed Data Layout

```text
data/exercises/catalog/
├── candidates.json
└── media_manifest.json

data/exercises/authoring/
├── schemas/
│   ├── kinematic_authoring_response.schema.json
│   └── kinematic_review_response.schema.json
├── prompts/
│   ├── authoring_openai_v1.md
│   └── review_openai_v1.md
├── drafts/
├── revisions/
├── reviews/
└── council_config.json

scenes/exercises/
├── kinematic_definition_studio.tscn
└── exercise_review_council.tscn

src/exercises/authoring/
├── candidate_repository.gd
├── definition_studio_controller.gd
├── review_council_controller.gd
├── providers/
│   ├── authoring_provider.gd
│   └── openai_provider.gd
└── candidate_validators.gd
```

Exact storage may use per-record JSON files rather than large shared arrays to reduce
merge conflicts and make revision history inspectable.

## Audit and Reproducibility Requirements

Every LLM-derived revision records:

- Source exercise and snapshot checksum.
- Complete context supplied by the user.
- Prompt, schema, provider, and model versions.
- Raw structured response after secret redaction.
- Human edits as a field-level diff.
- Deterministic validation report.
- Tracer and muscle-action-matrix versions.
- Human and model review decisions.
- Immutable revision hash.
- Promotion timestamp and resulting canonical profile version.

Historical workouts remain pinned to their original profile versions. Promoting a new
revision must not silently recalculate saved summaries.

## Acceptance Criteria

Phase 2 is complete when:

1. All source records and media are locally available and searchable.
2. Catalog-only status is visually unmistakable and cannot enable a misleading
   heatmap.
3. The definition studio can generate, edit, validate, save, and submit a strict
   kinematic proposal with additional context.
4. Unsupported and ambiguous proposals cannot advance.
5. The review studio displays source, proposal, tracer result, context, and both
   council decisions.
6. Rejection feedback returns to the next authoring revision.
7. Provider, model, system prompt, and schema are versioned rather than hard-coded in
   scene logic.
8. API keys are configurable directly on the internal scene roots, never copied into
   prompts, generated records, revisions, votes, or logs, and the scenes cannot submit
   requests while their key field is empty.
9. Only the exact unanimously accepted revision can be promoted.
10. Promotion produces a validated, fully visualizable canonical exercise without
    mutating previously saved workout results.
