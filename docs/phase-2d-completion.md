# Phase 2D Completion: Review Council Studio

Phase 2D adds a separate, editor-authored Godot review application at
`scenes/exercises/exercise_review_council.tscn`. It reviews immutable candidate
revisions; it does not edit definitions and it does not promote exercises.

## Implemented workflow

1. The queue loads saved definition candidates and existing frozen revisions.
2. A draft can be frozen only when its saved Phase 2C report passes and contains all
   466 canonical muscles. Older drafts must be opened, validated, and saved again in
   the Definition Studio before they become eligible.
3. Freezing snapshots the source record, author context, structured authoring result,
   provider metadata, deterministic gate report, and full tracer profile. Canonical
   JSON is SHA-256 addressed and never overwritten.
4. The council displays both source frames and instructions, the visual interpretation,
   definition JSON, affected-muscle tree grouped by role, the real full-body heatmap,
   validation provenance, aliases/variant comparisons, and prior feedback.
5. The OpenAI reviewer receives the frozen hash and JSON, controlled reviewer context,
   and one horizontal contact sheet. Its strict schema records accept/reject, summary,
   field-addressed blocking and non-blocking findings, corrections, and confidence.
6. The owner records an independent human vote. One rejection produces
   `changes_requested`; only two accepts produce `accepted`.
7. Rejection findings are recovered by the Definition Studio and inserted into its
   additional-context field for the next authored revision.
8. An explicit **Reject selected candidate** action also handles legacy or otherwise
   ineligible drafts that cannot be frozen. It requires a human rationale, marks the
   draft `review_rejected`, and retains it for audit. On a frozen revision, the same
   action records a hash-bound human rejection and immediately requests changes.

## Storage and audit boundary

- Frozen candidates: `data/exercises/authoring/revisions/<sha256>.json`
- Council records: `data/exercises/authoring/reviews/<sha256>.json`
- Reviewer schema: `data/exercises/authoring/schemas/kinematic_review_response.schema.json`
- Reviewer prompt: `data/exercises/authoring/prompts/review_openai_v1.md`

The exported `openai_api_key` remains only on the scene root and is never added to a
revision, prompt payload, review record, or console message. Model/provider response
metadata is retained with the model vote.

## Intentional boundary

An `accepted` council state is not canonical product data. Phase 2E will re-run every
gate and perform the atomic promotion transaction. The existing two local drafts
predate saved Phase 2C reports, so the queue correctly labels them **Needs Phase 2C
save** until they are revalidated in the Definition Studio.

## Verification

```bash
godot --headless --path . --script res://tools/exercises/verify_exercise_review_council.gd
python3 -m unittest discover -s tests -p 'test_*.py'
```
