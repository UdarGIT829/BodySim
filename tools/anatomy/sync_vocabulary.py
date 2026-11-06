#!/usr/bin/env python3
"""Sync the exercise-definition vocabulary from the muscle-action table v2.

    python3 tools/anatomy/sync_vocabulary.py          # rewrite
    python3 tools/anatomy/sync_vocabulary.py --check  # exit 1 if out of sync

Source of truth: data/anatomy/joint_action_vocabulary.json, restricted to the
joint actions at least one movement muscle in the v2 table performs (so an
exercise can never name an action the tracer maps to nothing). Writes:
  - the primary_joint_actions and stabilization_demands enums of the
    authoring schema (bumped to bodysim.kinematic_authoring_response.v2)
  - JOINT_ACTIONS and STABILIZATION_DEMANDS in candidate_validators.gd
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Dict, List

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.anatomy.muscle_actions_v2 import load_vocabulary, merged_table  # noqa: E402

SCHEMA_PATH = PROJECT_ROOT / "data/exercises/authoring/schemas/kinematic_authoring_response.schema.json"
VALIDATORS_PATH = PROJECT_ROOT / "src/exercises/authoring/candidate_validators.gd"
SCHEMA_ID = "bodysim.kinematic_authoring_response.v2"


def usable_actions() -> Dict[str, List[str]]:
    vocabulary = load_vocabulary()
    records, missing = merged_table()
    if missing:
        raise SystemExit(f"table incomplete: {', '.join(missing)}")
    performed = {(a["joint"], a["movement"]) for r in records if r["movement_muscle"] for a in r["actions"]}
    return {joint: [m for m in movements if (joint, m) in performed]
            for joint, movements in sorted(vocabulary["joints"].items())
            if any((joint, m) in performed for m in movements)}


def render_schema(actions: Dict[str, List[str]], demands: List[str]) -> str:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    schema["$id"] = SCHEMA_ID
    schema["title"] = "BodySim kinematic authoring response v2"
    profile = schema["properties"]["proposed_definition"]["anyOf"][1]["properties"]["kinematic_profile"]["properties"]
    profile["primary_joint_actions"]["items"]["anyOf"] = [{
        "type": "object",
        "additionalProperties": False,
        "required": ["joint", "movement"],
        "properties": {
            "joint": {"type": "string", "enum": [joint]},
            "movement": {"type": "string", "enum": sorted(movements)},
        },
    } for joint, movements in actions.items()]
    profile["stabilization_demands"]["items"]["enum"] = demands
    return json.dumps(schema, indent=2) + "\n"


def render_validators(actions: Dict[str, List[str]], demands: List[str]) -> str:
    text = VALIDATORS_PATH.read_text(encoding="utf-8")
    body = "\n".join(f'\t"{joint}": {json.dumps(sorted(movements))},' for joint, movements in actions.items())
    joint_block = "const JOINT_ACTIONS := {\n" + body.replace('", "', '", "') + "\n}"
    text, n1 = re.subn(r"const JOINT_ACTIONS := \{.*?\n\}", lambda _: joint_block, text, count=1, flags=re.S)
    text, n2 = re.subn(r"const STABILIZATION_DEMANDS := \[.*?\]", lambda _: "const STABILIZATION_DEMANDS := " + json.dumps(demands),
                       text, count=1, flags=re.S)
    if n1 != 1 or n2 != 1:
        raise SystemExit("could not locate the vocabulary constants in candidate_validators.gd")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    actions = usable_actions()
    demands = sorted(load_vocabulary()["stabilization_demands"])
    outputs = {SCHEMA_PATH: render_schema(actions, demands), VALIDATORS_PATH: render_validators(actions, demands)}
    stale = [p for p, text in outputs.items() if p.read_text(encoding="utf-8") != text]
    if args.check:
        for p in stale:
            print(f"out of sync: {p.relative_to(PROJECT_ROOT)}")
        return 1 if stale else 0
    for p in stale:
        p.write_text(outputs[p], encoding="utf-8")
        print(f"updated {p.relative_to(PROJECT_ROOT)}")
    print(f"{sum(len(m) for m in actions.values())} joint actions across {len(actions)} joints; {len(demands)} stabilization demands")
    return 0


if __name__ == "__main__":
    sys.exit(main())
