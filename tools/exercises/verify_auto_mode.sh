#!/usr/bin/env bash
# Auto-mode check for the Kinematic Definition Studio and the Review Council.
# Runs in a disposable copy of the project with a fake Claude bridge, so the
# real data/, user settings and API credits are never touched.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
GODOT=${GODOT:-$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64}
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
cp -al "$ROOT/assets" "$ROOT/build" "$SANDBOX/"
rsync -a --exclude assets --exclude build --exclude .git "$ROOT/" "$SANDBOX/"
# The fake authoring response is the frozen fixture definition under a fixture ID.
python3 - "$SANDBOX" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
draft = json.loads((root / "tests/fixtures/promotion_draft.json").read_text())
response = draft["authoring_response"]
# A fixture-only ID, so it never collides with an exercise promoted for real.
response["proposed_definition"]["id"] = "exercise.auto_mode_fixture.standard"
response["proposed_definition"]["variant"] = "standard"
(root / "fake_authoring_response.json").write_text(json.dumps(response))
PY
# Start from a clean authoring history (real catalog, no drafts, revisions,
# votes or promotion records), so the check doesn't depend on the owner's
# own council work, e.g. an exercise already rejected once and near the cap.
A="$SANDBOX/data/exercises/authoring"
rm -f "$A"/drafts/*.json "$A"/revisions/*.json "$A"/reviews/*.json "$A"/promotions/*.json "$A"/demotions/*.json "$A"/cleared.json
chmod +x "$SANDBOX/tools/exercises/fake_claude_bridge.py"
# The spending ledger and credit balance go to sandbox files, never the owner's.
BODYSIM_SPEND_LEDGER="$SANDBOX/spend.jsonl" BODYSIM_CREDITS_FILE="$SANDBOX/credits.cfg" \
BODYSIM_SANDBOX=1 FAKE_AUTHORING_RESPONSE="$SANDBOX/fake_authoring_response.json" \
	"$GODOT" --headless --path "$SANDBOX" --script res://tools/exercises/verify_auto_mode.gd
