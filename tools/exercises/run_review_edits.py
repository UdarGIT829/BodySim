#!/usr/bin/env python3
"""Apply a council reviewer's proposed edits to a rejected revision.

Used by the Review Council ("Apply suggested edits" and auto mode), and
runnable by hand:

    python3 tools/exercises/run_review_edits.py <revision_sha256> [--dry-run]
    python3 tools/exercises/run_review_edits.py --input in.json --output out.json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.exercises.review_edits import apply_to_revision  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("revision", nargs="?")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        if args.input:
            request = json.loads(args.input.read_text(encoding="utf-8"))
            revision, dry_run = request.get("revision_sha256", ""), bool(request.get("dry_run", False))
        else:
            revision, dry_run = args.revision or "", args.dry_run
        report = apply_to_revision(revision, dry_run=dry_run)
    except Exception as exc:  # the bridge must always return a readable report
        report = {"ok": False, "errors": [f"applying edits crashed: {type(exc).__name__}: {exc}"]}
    text = json.dumps(report, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text)
    return 0 if report.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
