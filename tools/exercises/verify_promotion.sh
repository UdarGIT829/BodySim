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
BODYSIM_SANDBOX=1 "$GODOT" --headless --path "$SANDBOX" --script res://tools/exercises/verify_promotion.gd
