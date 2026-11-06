#!/usr/bin/env python3
"""Bridge between Godot and Claude for the authoring studio and review council.

    run_claude.py --input request.json --output response.json
    run_claude.py --models            # list selectable models as JSON

The request JSON carries the task ("author" or "review"), the chosen model and
effort, the context text or frozen revision, an optional contact-sheet data
URL, and the path of the Godot user settings file (for the API key). The API
key itself is never passed through these files.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.exercises.llm.claude_client import models_payload, run_task  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--input", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--models", action="store_true", help="print the selectable models and exit")
    args = parser.parse_args()
    if args.models:
        print(json.dumps(models_payload(), indent=2))
        return 0
    if not args.input or not args.output:
        parser.error("--input and --output are required")
    try:
        request = json.loads(args.input.read_text(encoding="utf-8"))
        result = run_task(request)
    except ModuleNotFoundError as exc:
        result = {"ok": False, "error": f"Missing Python package ({exc.name}). Run: python3 -m pip install --user -r requirements.txt"}
    except Exception as exc:  # the bridge must always leave a readable result
        result = {"ok": False, "error": f"Claude bridge crashed: {type(exc).__name__}: {exc}"}
    args.output.write_text(json.dumps(result, indent=2), encoding="utf-8")
    return 0 if result.get("ok") else 2


if __name__ == "__main__":
    sys.exit(main())
