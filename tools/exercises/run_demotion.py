#!/usr/bin/env python3
"""Demote a council-promoted exercise back to catalog-only.

Used by the Kinematic Definition Studio's "Demote…" dialog, and runnable by hand:

    python3 tools/exercises/run_demotion.py --list
    python3 tools/exercises/run_demotion.py <exercise_id> --reason "why" [--dry-run]
    python3 tools/exercises/run_demotion.py --input in.json --output out.json

The Godot bridge request is {"action": "list"} or
{"action": "demote", "exercise_id", "reason", "dry_run"}.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.exercises.demotion import demotable_exercises, demote_exercise  # noqa: E402


def handle(request: dict) -> dict:
    if request.get("action") == "list":
        return {"ok": True, "exercises": demotable_exercises()}
    return demote_exercise(str(request.get("exercise_id", "")), str(request.get("reason", "")),
                           dry_run=bool(request.get("dry_run", False)))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("exercise_id", nargs="?")
    parser.add_argument("--reason", default="")
    parser.add_argument("--list", action="store_true", help="list council-promoted exercises")
    parser.add_argument("--dry-run", action="store_true", help="validate without writing")
    parser.add_argument("--input", type=Path, help="JSON request file (Godot bridge)")
    parser.add_argument("--output", type=Path, help="write the report here instead of stdout")
    args = parser.parse_args()

    try:
        if args.input:
            request = json.loads(args.input.read_text(encoding="utf-8"))
        elif args.list:
            request = {"action": "list"}
        else:
            request = {"action": "demote", "exercise_id": args.exercise_id or "", "reason": args.reason, "dry_run": args.dry_run}
        report = handle(request)
    except Exception as exc:  # the bridge must always return a readable report
        report = {"ok": False, "errors": [f"demotion crashed: {type(exc).__name__}: {exc}"]}

    text = json.dumps(report, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text)
    return 0 if report.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
