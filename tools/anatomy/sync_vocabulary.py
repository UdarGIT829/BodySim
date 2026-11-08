#!/usr/bin/env python3
"""Sync the exercise-definition vocabulary from the muscle-action table v2.

    python3 tools/anatomy/sync_vocabulary.py          # rewrite
    python3 tools/anatomy/sync_vocabulary.py --check  # exit 1 if out of sync

Source of truth: data/anatomy/joint_action_vocabulary.json, restricted to the
joint actions at least one movement muscle in the v2 table performs (so an
exercise can never name an action the tracer maps to nothing). Writes:
  - the primary_joint_actions and stabilization_demands enums of the
    authoring schema (bodysim.kinematic_authoring_response.v3), with the
    tracer v3 per-action fields (emphasis, sides) and one_sided_limbs
  - JOINT_ACTIONS and STABILIZATION_DEMANDS in candidate_validators.gd
  - the review schema's proposed_edits operations (bodysim.kinematic_review_response.v2)
  - the movement-family enums of the authoring schema, MOVEMENT_FAMILIES in
    candidate_validators.gd and FAMILY_ORDER in exercise_selector.gd, from
    the vocabulary's movement_families (in that order)
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
SELECTOR_PATH = PROJECT_ROOT / "src/exercises/exercise_selector.gd"
REVIEW_SCHEMA_PATH = PROJECT_ROOT / "data/exercises/authoring/schemas/kinematic_review_response.schema.json"
REVIEW_SCHEMA_ID = "bodysim.kinematic_review_response.v2"
LATERALITIES = ["bilateral", "left", "right", "unilateral"]
CHAIN_TYPES = ["open_chain", "closed_chain"]
SCHEMA_ID = "bodysim.kinematic_authoring_response.v3"


def usable_actions() -> Dict[str, List[str]]:
    vocabulary = load_vocabulary()
    records, missing = merged_table()
    if missing:
        raise SystemExit(f"table incomplete: {', '.join(missing)}")
    performed = {(a["joint"], a["movement"]) for r in records if r["movement_muscle"] for a in r["actions"]}
    return {joint: [m for m in movements if (joint, m) in performed]
            for joint, movements in sorted(vocabulary["joints"].items())
            if any((joint, m) in performed for m in movements)}


def families() -> List[str]:
    return list(load_vocabulary()["movement_families"])


def render_schema(actions: Dict[str, List[str]], demands: List[str]) -> str:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    schema["$id"] = SCHEMA_ID
    schema["title"] = "BodySim kinematic authoring response v3"
    profile = schema["properties"]["proposed_definition"]["anyOf"][1]["properties"]["kinematic_profile"]["properties"]
    # Every property is required (structured outputs); emphasis and sides
    # carry the tracer's defaults, "primary" and "working".
    profile["primary_joint_actions"]["items"]["anyOf"] = [{
        "type": "object",
        "additionalProperties": False,
        "required": ["joint", "movement", "emphasis", "sides"],
        "properties": {
            "joint": {"type": "string", "enum": [joint]},
            "movement": {"type": "string", "enum": sorted(movements)},
            "emphasis": {"type": "string", "enum": ["primary", "assist"]},
            "sides": {"type": "string", "enum": ["working", "both"]},
        },
    } for joint, movements in actions.items()]
    profile["stabilization_demands"]["items"]["enum"] = demands
    profile["one_sided_limbs"] = {"type": "array", "items": {"type": "string", "enum": ["arm", "leg"]}}
    kinematic_profile = schema["properties"]["proposed_definition"]["anyOf"][1]["properties"]["kinematic_profile"]
    kinematic_profile["required"] = ["kinetic_chain_type", "primary_joint_actions", "stabilization_demands", "one_sided_limbs"]
    definition = schema["properties"]["proposed_definition"]["anyOf"][1]["properties"]
    definition["primary_movement_family"]["enum"] = families()
    definition["additional_movement_families"]["items"]["enum"] = families()
    return json.dumps(schema, indent=2) + "\n"


def render_validators(actions: Dict[str, List[str]], demands: List[str]) -> str:
    text = VALIDATORS_PATH.read_text(encoding="utf-8")
    body = "\n".join(f'\t"{joint}": {json.dumps(sorted(movements))},' for joint, movements in actions.items())
    joint_block = "const JOINT_ACTIONS := {\n" + body.replace('", "', '", "') + "\n}"
    text, n1 = re.subn(r"const JOINT_ACTIONS := \{.*?\n\}", lambda _: joint_block, text, count=1, flags=re.S)
    text, n2 = re.subn(r"const STABILIZATION_DEMANDS := \[.*?\]", lambda _: "const STABILIZATION_DEMANDS := " + json.dumps(demands),
                       text, count=1, flags=re.S)
    text, n3 = re.subn(r"const MOVEMENT_FAMILIES := \[.*?\]", lambda _: "const MOVEMENT_FAMILIES := " + json.dumps(families()),
                       text, count=1, flags=re.S)
    if n1 != 1 or n2 != 1 or n3 != 1:
        raise SystemExit("could not locate the vocabulary constants in candidate_validators.gd")
    return text


def _op(name: str, **fields) -> dict:
    props = {"op": {"type": "string", "enum": [name]}, **fields}
    return {"type": "object", "additionalProperties": False, "required": list(props), "properties": props}


def render_review_schema(actions: Dict[str, List[str]], demands: List[str]) -> str:
    """The review schema, with the edit operations a reviewer can propose.

    Every operation is a closed object with all fields required (structured
    outputs). Joint and movement are separate enums; the edit applier checks
    the pair against the vocabulary."""
    schema = json.loads(REVIEW_SCHEMA_PATH.read_text(encoding="utf-8"))
    schema["$id"] = REVIEW_SCHEMA_ID
    joint = {"type": "string", "enum": list(actions)}
    movement = {"type": "string", "enum": sorted({m for ms in actions.values() for m in ms})}
    emphasis = {"type": "string", "enum": ["primary", "assist"]}
    sides = {"type": "string", "enum": ["working", "both"]}
    demand = {"type": "string", "enum": demands}
    ops = [
        _op("set_kinetic_chain_type", value={"type": "string", "enum": CHAIN_TYPES}),
        _op("set_laterality", value={"type": "string", "enum": LATERALITIES}),
        _op("set_movement_families", value={"type": "array", "items": {"type": "string", "enum": families()}}),
        _op("set_one_sided_limbs", value={"type": "array", "items": {"type": "string", "enum": ["arm", "leg"]}}),
        _op("add_joint_action", joint=joint, movement=movement, emphasis=emphasis, sides=sides),
        _op("remove_joint_action", joint=joint, movement=movement),
        _op("set_action_emphasis", joint=joint, movement=movement, emphasis=emphasis),
        _op("set_action_sides", joint=joint, movement=movement, sides=sides),
        _op("add_stabilization_demand", demand=demand),
        _op("remove_stabilization_demand", demand=demand),
    ]
    schema["properties"]["proposed_edits"] = {"type": "array", "items": {"anyOf": ops}}
    schema["properties"]["edits_resolve_all_blocking_findings"] = {"type": "boolean"}
    schema["required"] = ["decision", "summary", "blocking_findings", "non_blocking_findings", "confidence",
                          "proposed_edits", "edits_resolve_all_blocking_findings"]
    return json.dumps(schema, indent=2) + "\n"


def render_selector() -> str:
    text = SELECTOR_PATH.read_text(encoding="utf-8")
    block = "const FAMILY_ORDER := [\n" + "".join(f'\t"{f}",\n' for f in families()) + "]"
    text, n = re.subn(r"const FAMILY_ORDER := \[.*?\n\]", lambda _: block, text, count=1, flags=re.S)
    if n != 1:
        raise SystemExit("could not locate FAMILY_ORDER in exercise_selector.gd")
    return text


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    actions = usable_actions()
    demands = sorted(load_vocabulary()["stabilization_demands"])
    outputs = {SCHEMA_PATH: render_schema(actions, demands), VALIDATORS_PATH: render_validators(actions, demands),
               SELECTOR_PATH: render_selector(), REVIEW_SCHEMA_PATH: render_review_schema(actions, demands)}
    stale = [p for p, text in outputs.items() if p.read_text(encoding="utf-8") != text]
    if args.check:
        for p in stale:
            print(f"out of sync: {p.relative_to(PROJECT_ROOT)}")
        return 1 if stale else 0
    for p in stale:
        p.write_text(outputs[p], encoding="utf-8")
        print(f"updated {p.relative_to(PROJECT_ROOT)}")
    print(f"{sum(len(m) for m in actions.values())} joint actions across {len(actions)} joints; {len(demands)} stabilization demands; {len(families())} movement families")
    return 0


if __name__ == "__main__":
    sys.exit(main())
