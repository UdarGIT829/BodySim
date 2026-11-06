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
# The fake authoring response is the Barbell Curl definition, traced by the
# current tracer.
python3 - "$SANDBOX" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
draft = json.loads((root / "data/exercises/authoring/drafts/Barbell_Curl.json").read_text())
(root / "fake_authoring_response.json").write_text(json.dumps(draft["authoring_response"]))
PY
chmod +x "$SANDBOX/tools/exercises/fake_claude_bridge.py"
BODYSIM_SANDBOX=1 FAKE_AUTHORING_RESPONSE="$SANDBOX/fake_authoring_response.json" \
	"$GODOT" --headless --path "$SANDBOX" --script res://tools/exercises/verify_auto_mode.gd
