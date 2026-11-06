#!/usr/bin/env python3
"""Promote an accepted council revision (Phase 2E).

Used by the Review Council's "Promote" button, and runnable by hand:

    python3 tools/exercises/run_promotion.py <revision_sha256> [--dry-run]
    python3 tools/exercises/run_promotion.py --input in.json --output out.json

The council verifies the frozen revision's content hash before calling this.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.exercises.promotion import promote_revision  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("revision", nargs="?", help="frozen revision SHA-256")
    parser.add_argument("--dry-run", action="store_true", help="validate without writing")
    parser.add_argument("--input", type=Path, help="JSON file with {revision_sha256, dry_run} (Godot bridge)")
    parser.add_argument("--output", type=Path, help="write the report here instead of stdout")
    args = parser.parse_args()

    try:
        if args.input:
            request = json.loads(args.input.read_text(encoding="utf-8"))
            revision, dry_run = request.get("revision_sha256", ""), bool(request.get("dry_run", False))
        else:
            revision, dry_run = args.revision or "", args.dry_run
        report = promote_revision(revision, dry_run=dry_run)
    except Exception as exc:  # the bridge must always return a readable report
        report = {"ok": False, "errors": [f"promotion crashed: {type(exc).__name__}: {exc}"]}

    text = json.dumps(report, indent=2)
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text)
    return 0 if report.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
