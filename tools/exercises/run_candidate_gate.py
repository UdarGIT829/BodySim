#!/usr/bin/env python3
"""File-based bridge used by the internal Godot Definition Studio."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.exercises.candidate_gate import evaluate_candidate


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    try:
        definition = json.loads(args.input.read_text(encoding="utf-8"))
        result = evaluate_candidate(definition)
        args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
        return 0 if result["ok"] else 2
    except Exception as exc:  # Bridge must always leave a machine-readable diagnostic.
        result = {
            "gate_version": "candidate_trace_gate_v2",
            "ok": False,
            "errors": [f"candidate gate crashed: {type(exc).__name__}: {exc}"],
            "warnings": [],
            "summary": {},
            "profile": {},
        }
        args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
