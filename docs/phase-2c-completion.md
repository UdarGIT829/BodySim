# Phase 2C Completion: Deterministic Candidate Gate

## Status

**Complete (2026-08-10).** A definition cannot become `definition_candidate` merely
by satisfying the authoring JSON Schema and GDScript vocabulary checks. It must also
pass the existing Python kinematic tracer against the complete canonical anatomy.

## Isolated tracer transaction

The Definition Studio writes the current definition to a unique temporary file under
Godot `user://`, runs `tools/exercises/run_candidate_gate.py`, reads its machine-readable
report, and removes both temporary files. The bridge reads canonical project inputs but
never writes `data/exercises/exercises.json` or
`data/exercises/engagement_profiles.json`.

The gate requires:

- a structurally valid BodySim exercise definition;
- no collision with an existing canonical exercise ID;
- exactly 466 unique output entries matching the canonical muscle-ID set;
- valid roles and coefficients, including explicit `none`/zero entries;
- valid confidence, evidence status, derivation method, and evidence references;
- at least one affected muscle;
- at least one canonical muscle mapping for every requested joint/action pair;
- at least one canonical muscle mapping for every stabilization demand.

The report contains the complete provisional 466-muscle profile, role counts, mapped
and zero counts, per-action coverage, per-stabilization coverage, warnings, errors, and
SHA-256 provenance for structures, muscle actions, and canonical exercises.

## Studio behavior

The Candidate gate tab displays a concise Python tracer PASS/FAIL summary with affected,
primary, synergist, stabilizer, and zero-muscle counts. Detailed failures appear in the
gate tree and Godot console. Save draft and Submit both persist the complete trace report;
Submit remains disabled unless the authoring gate and tracer gate both pass.

Legacy or ambiguous model output never invokes the Python tracer until the deterministic
authoring checks pass. Validation is synchronous because a single 466-muscle trace is
small; it can move to a worker thread if future biomechanical simulation makes the gate
materially slower.

## Files

- `src/exercises/candidate_gate.py` — pure isolated gate and trace validation.
- `tools/exercises/run_candidate_gate.py` — file-based command bridge.
- `src/exercises/authoring/candidate_trace_gate.gd` — Godot temporary-file runner.
- `scenes/exercises/candidate_trace_gate.tscn` — standalone runner scene.
- `src/exercises/authoring/definition_studio_controller.gd` — gate orchestration and summary.
- `src/exercises/authoring/candidate_repository.gd` — persisted trace report.
- `tests/exercises/test_candidate_gate.py` — isolation and failure-path coverage.
- `tools/exercises/verify_kinematic_definition_studio.gd` — end-to-end Godot bridge verification.

## Verification

```bash
pytest -q
XDG_DATA_HOME=/tmp/bodysim-godot-data \
XDG_CONFIG_HOME=/tmp/bodysim-godot-config \
/home/vudar/Applications/godot --headless \
  --path /home/vudar/Documents/code/BodySim \
  --script res://tools/exercises/verify_kinematic_definition_studio.gd
```

The Python suite verifies successful 466-muscle generation, unmapped-action rejection,
canonical-ID collision rejection, CLI output, and byte-for-byte non-mutation of both
canonical outputs. The Godot verifier runs the real Python bridge and requires a complete,
nonzero profile.

## Next phase

Phase 2D freezes a passing definition and its trace report into an immutable review
revision, then presents it to the human and OpenAI review council.
