# Phase 2B Completion: Kinematic Definition Studio

## Status

**Complete (2026-08-10).** Phase 2B provides the internal authoring environment and
strict proposal contract. It does not review or promote exercises; those remain Phase
2D and Phase 2E responsibilities.

## Implemented workflow

Open `res://scenes/exercises/kinematic_definition_studio.tscn` in Godot. Set the
scene root's exported `openai_api_key` value and, if desired, `openai_model`. The key
defaults to empty and Generate remains unavailable until both a source exercise and
key exist. A populated exported key is serialized into the scene, so clear it before
sharing or committing the project.

The scene also provides a visible model selector with GPT-5.6 Sol, Terra, Luna, GPT-5
mini, and an exact custom-model-ID option. The last selection persists in the local
Godot user settings without copying the API key. Terra is the balanced default; Sol is
the highest-quality preset for difficult biomechanical interpretation.

The editor-authored scene contains:

- all 853 catalog-only source records with search, metadata, numbered instructions,
  and both local demonstration images;
- automatic composition of both demonstration frames into one chronological,
  left-to-right JPEG contact sheet sent as a single high-detail Responses API vision
  input alongside the source text;
- visual fields for canonical identity, variant, aliases, movement families,
  laterality, input mode, kinetic chain, joint/action pairs, and
  stabilization demands;
- an additional-context field for setup clarification and failed-review feedback;
- model classification, reasons, assumptions, unresolved questions, and confidence;
- synchronized visual and advanced-JSON editing;
- deterministic gate results and a structural diff from the saved draft;
- automatic navigation to the candidate-gate tab on failure, with the first concrete
  error repeated in the footer;
- separate Save draft and Submit definition candidate actions.

Generate calls the OpenAI Responses API directly through the standalone provider
scene. The request uses strict Structured Outputs and the versioned JSON Schema. Its
user message contains one `input_text` item and one `input_image` data URL; the latter
is an in-memory contact sheet rather than two separate image uploads. The prompt states
that frames are chronological from left to right and warns that still endpoints do not
prove the complete path between them. The
provider explicitly rejects API errors, incomplete responses, refusals, and responses
without parseable `output_text`. It stores response ID, model, usage, and status, but
never stores the API key.

## Advancement rules

`supported` is not synonymous with accepted. A supported proposal advances only when
the local candidate gate also accepts every field. `ambiguous` and `unsupported`
responses can be retained as authoring drafts and their questions can inform another
generation, but they cannot be submitted as definition candidates.

The gate currently enforces the tracer's exact finite vocabulary:

- 22 valid joint/action pairs across eight joint identifiers;
- 22 stabilization demands;
- 13 movement families;
- canonical laterality, input-mode, and kinetic-chain enums;
- no collision with an existing canonical exercise ID;
- at least one known primary joint action and movement family;
- no unresolved questions on a supported response.

This boundary is intentional. Exercises needing a joint action or resistance path the
tracer cannot express are rejected rather than coerced into a misleading heatmap.

### Load-vector deprecation

`load_vector` was removed from the active authoring contract after Phase 2B testing
showed that it encouraged the model to force new exercises into superficially similar
legacy labels. The tracer, coefficients, heatmap, and workout scorer never consumed
the field. Existing values remain in the initial 21 canonical definitions as ignored
legacy metadata, while new definitions neither request nor require one. Loading an old
authoring draft removes the field and its confidence entry from the editable response
but preserves the untouched raw provider response in provenance.

Any future replacement should decompose external loading into independently useful
facts—such as source, contact point, side, direction, support, and body orientation—and
should be introduced only when those facts actually affect tracing or scoring.

## Files

- `scenes/exercises/kinematic_definition_studio.tscn` — complete editor-visible studio.
- `src/exercises/authoring/definition_studio_controller.gd` — source loading, visual/JSON synchronization, generation, diff, validation, and actions.
- `scenes/exercises/openai_authoring_provider.tscn` and `src/exercises/authoring/providers/openai_authoring_provider.gd` — direct Responses API adapter.
- `data/exercises/authoring/schemas/kinematic_authoring_response.schema.json` — strict response contract v1.
- `data/exercises/authoring/prompts/authoring_openai_v1.md` — versioned author system prompt.
- `src/exercises/authoring/candidate_validators.gd` — deterministic compatibility gate.
- `src/exercises/authoring/candidate_repository.gd` — per-source draft persistence under `data/exercises/authoring/drafts/`.
- `tools/exercises/verify_kinematic_definition_studio.gd` — headless scene and contract verifier.

## Verification

```bash
pytest -q
XDG_DATA_HOME=/tmp/bodysim-godot-data \
XDG_CONFIG_HOME=/tmp/bodysim-godot-config \
/home/vudar/Applications/godot --headless \
  --path /home/vudar/Documents/code/BodySim \
  --script res://tools/exercises/verify_kinematic_definition_studio.gd
```

Current result: 50 Python tests pass, and the Godot verifier confirms the authored UI,
853-record catalog, strict Responses request, output/refusal parsing, valid proposal
path, unresolved-question rejection, and ambiguous-proposal rejection.

## Next phase

Phase 2C should deepen the deterministic gate by running the actual Python kinematic
tracer against a candidate without mutating canonical files and confirming a complete
466-muscle profile. Phase 2D then freezes that validated revision for the human plus
OpenAI review council.
