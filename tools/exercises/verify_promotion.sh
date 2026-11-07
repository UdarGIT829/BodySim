#!/usr/bin/env bash
# Runs the Phase 2E end-to-end check in a disposable copy of the project, so
# the real data/ catalog is never modified.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GODOT=${GODOT:-$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64}
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
# Large read-only inputs are hard-linked; data/ and code are real copies.
cp -al "$ROOT/assets" "$ROOT/build" "$SANDBOX/"
rsync -a --exclude assets --exclude build --exclude .git "$ROOT/" "$SANDBOX/"
# The frozen fixture draft (tests/fixtures/) is re-keyed to the first
# unpromoted catalog source under a fixture-only ID, and traced with the
# current tracer, as a draft re-validated in the Definition Studio would be.
python3 - "$SANDBOX" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1]); sys.path.insert(0, str(root))
from src.exercises.candidate_gate import evaluate_candidate
draft = json.loads((root / "tests/fixtures/promotion_draft.json").read_text())
catalog = json.loads((root / "data/exercises/catalog/candidates.json").read_text())
target = next(c for c in catalog if c["status"] == "catalog_only" and c.get("category") != "stretching")
for key in ("source_id", "catalog_id", "source_snapshot_sha256"):
    draft[key] = target[key]
draft["authoring_response"]["proposed_definition"]["id"] = "exercise.promotion_fixture.standing_bilateral"
draft["candidate_trace_report"] = evaluate_candidate(draft["authoring_response"]["proposed_definition"])
(root / "data/exercises/authoring/drafts/_promotion_fixture.json").write_text(json.dumps(draft, indent=2))
PY
BODYSIM_SANDBOX=1 "$GODOT" --headless --path "$SANDBOX" --script res://tools/exercises/verify_promotion.gd
