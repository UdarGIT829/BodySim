"""Muscle-action table v2: review groups, drafting schema, validation, merge.

The v1 table (data/anatomy/muscle_actions.json) was generated from substring
rules, which gave facial and laryngeal muscles trunk actions, gave 376
muscles a catch-all postural-stabilization tag, and used flat coefficients.
v2 is curated per muscle, one file per review group in
data/anatomy/muscle_actions_v2/<group>.json. Each entry describes one muscle
(both sides share it) with weighted actions and weighted stabilization roles.

Weights (see data/anatomy/joint_action_vocabulary.json):
  1.0 prime mover · 0.7-0.9 major contributor · 0.3-0.6 synergist ·
  0.1-0.2 minor. Omit an action the muscle does not meaningfully perform.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Tuple

PROJECT_ROOT = Path(__file__).resolve().parents[2]
STRUCTURES_PATH = PROJECT_ROOT / "data/anatomy/structures.json"
VOCABULARY_PATH = PROJECT_ROOT / "data/anatomy/joint_action_vocabulary.json"
TABLE_DIR = PROJECT_ROOT / "data/anatomy/muscle_actions_v2"

STATUSES = ("draft", "reviewed")
CONFIDENCE = ("high", "medium", "low")

# Review groups, in the order they should be curated. The structures'
# `region` field is unreliable (e.g. triceps heads are filed under
# head_neck), so groups come from the anatomical parent chain instead.
GROUP_ORDER = [
    "shoulder_girdle", "arm", "forearm", "hand", "thorax", "abdomen", "back",
    "pelvis", "hip_and_thigh", "leg", "foot", "neck", "head",
]
GROUP_TITLES = {
    "shoulder_girdle": "Shoulder girdle (deltoid, rotator cuff, teres major, trapezius)",
    "arm": "Arm (biceps, brachialis, coracobrachialis, triceps)",
    "forearm": "Forearm (wrist, finger and forearm-rotation muscles)",
    "hand": "Hand intrinsics",
    "thorax": "Thorax (pectorals, serratus, intercostals, diaphragm)",
    "abdomen": "Abdominal wall",
    "back": "Back (erector spinae, multifidus, latissimus, splenius, suboccipitals)",
    "pelvis": "Pelvis and pelvic floor",
    "hip_and_thigh": "Hip and thigh",
    "leg": "Leg (below the knee)",
    "foot": "Foot intrinsics",
    "neck": "Neck",
    "head": "Head, face, eye, jaw, tongue and palate",
}


def _chain(structure: Dict[str, Any]) -> List[str]:
    refs = structure.get("source_refs") or [{}]
    return [c.replace(".g", "").strip() for c in refs[0].get("parent_chain", [])]


def group_for(structure: Dict[str, Any]) -> str:
    """Review group for one muscle structure."""
    chain = " | ".join(_chain(structure)).lower()
    name = structure["id"]
    if "scapulohumeral" in chain or "trapezius" in chain:
        return "shoulder_girdle"
    if "compartment of arm" in chain:
        return "arm"
    if "compartment of forearm" in chain:
        return "forearm"
    if "muscles of hand" in chain:
        return "hand"
    if "muscles of foot" in chain:
        return "foot"
    if "lower limb" in chain:
        leg_words = ("compartment of leg", "triceps surae", "gastrocnemius", "soleus", "tibialis",
                     "fibularis", "peroneus", "popliteus", "plantaris", "extensor_hallucis_longus",
                     "extensor_digitorum_longus", "flexor_hallucis_longus", "flexor_digitorum_longus")
        return "leg" if any(w in chain or w in name for w in leg_words) else "hip_and_thigh"
    if "muscles of pelvis" in chain or "pelvic" in chain or "perine" in chain:
        return "pelvis"
    if "muscles of abdomen" in chain:
        return "abdomen"
    if "muscles of thorax" in chain or "thoracic part of muscular system" in chain:
        return "thorax"
    if "muscles of neck" in chain:
        return "neck"
    if any(w in chain for w in ("back", "iliocostalis", "longissimus", "spinalis", "multifidus",
                                "rotatores", "interspinales", "splenius", "suboccipital", "semispinalis")):
        return "back"
    return "head"


def base_id(muscle_id: str) -> str:
    """'muscle.brachialis.left' -> 'muscle.brachialis'."""
    for suffix in (".left", ".right"):
        if muscle_id.endswith(suffix):
            return muscle_id[: -len(suffix)]
    return muscle_id


def load_structures() -> List[Dict[str, Any]]:
    data = json.loads(STRUCTURES_PATH.read_text(encoding="utf-8"))
    return [s for s in data["structures"] if s["id"].startswith("muscle.")]


def load_vocabulary() -> Dict[str, Any]:
    return json.loads(VOCABULARY_PATH.read_text(encoding="utf-8"))


def group_muscles() -> Dict[str, List[Dict[str, Any]]]:
    """Group -> list of base muscles: {base_id, name, muscle_ids, hierarchy}."""
    bases: Dict[str, Dict[str, Any]] = {}
    for s in load_structures():
        b = base_id(s["id"])
        entry = bases.setdefault(b, {"base_id": b, "name": s["name"], "muscle_ids": [],
                                     "hierarchy": " > ".join(_chain(s)[:3]), "group": group_for(s)})
        entry["muscle_ids"].append(s["id"])
    groups: Dict[str, List[Dict[str, Any]]] = {g: [] for g in GROUP_ORDER}
    for entry in sorted(bases.values(), key=lambda e: e["base_id"]):
        entry["muscle_ids"].sort()
        groups[entry["group"]].append(entry)
    return groups


# ── Drafting schema (structured output) ─────────────────────────────────────

def drafting_schema(vocabulary: Dict[str, Any]) -> Dict[str, Any]:
    action_alternatives = [{
        "type": "object",
        "properties": {
            "joint": {"type": "string", "enum": [joint]},
            "movement": {"type": "string", "enum": movements},
            "weight": {"type": "number"},
        },
        "required": ["joint", "movement", "weight"],
        "additionalProperties": False,
    } for joint, movements in vocabulary["joints"].items()]
    return {
        "type": "object",
        "properties": {
            "entries": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "base_id": {"type": "string"},
                        "movement_muscle": {"type": "boolean"},
                        "actions": {"type": "array", "items": {"anyOf": action_alternatives}},
                        "stabilizes": {"type": "array", "items": {
                            "type": "object",
                            "properties": {
                                "demand": {"type": "string", "enum": sorted(vocabulary["stabilization_demands"])},
                                "weight": {"type": "number"},
                            },
                            "required": ["demand", "weight"],
                            "additionalProperties": False,
                        }},
                        "confidence": {"type": "string", "enum": list(CONFIDENCE)},
                        "rationale": {"type": "string"},
                    },
                    "required": ["base_id", "movement_muscle", "actions", "stabilizes", "confidence", "rationale"],
                    "additionalProperties": False,
                },
            },
        },
        "required": ["entries"],
        "additionalProperties": False,
    }


# ── Validation ──────────────────────────────────────────────────────────────

def validate_group(group: str, document: Dict[str, Any]) -> List[str]:
    """Rule checks for one group file. Returns a list of problems."""
    vocabulary = load_vocabulary()
    expected = {m["base_id"]: m for m in group_muscles().get(group, [])}
    problems: List[str] = []
    if document.get("group") != group:
        problems.append(f"file declares group {document.get('group')!r}, expected {group!r}")
    seen = set()
    for entry in document.get("entries", []):
        b = entry.get("base_id")
        where = f"{group}:{b}"
        if b not in expected:
            problems.append(f"{where}: not a muscle of this group")
            continue
        if b in seen:
            problems.append(f"{where}: listed twice")
        seen.add(b)
        if entry.get("status") not in STATUSES:
            problems.append(f"{where}: status must be one of {STATUSES}")
        if entry.get("confidence") not in CONFIDENCE:
            problems.append(f"{where}: confidence must be one of {CONFIDENCE}")
        actions = entry.get("actions", [])
        stabilizes = entry.get("stabilizes", [])
        if not entry.get("movement_muscle") and (actions or stabilizes):
            problems.append(f"{where}: a non-movement muscle must have no actions or stabilization roles")
        pairs = set()
        for a in actions:
            joint, movement, weight = a.get("joint"), a.get("movement"), a.get("weight")
            if movement not in vocabulary["joints"].get(joint, []):
                problems.append(f"{where}: unknown action {joint}/{movement}")
            if not isinstance(weight, (int, float)) or not 0.1 <= weight <= 1.0:
                problems.append(f"{where}: {joint}/{movement} weight {weight!r} must be 0.1-1.0 (omit weaker actions)")
            if (joint, movement) in pairs:
                problems.append(f"{where}: {joint}/{movement} listed twice")
            pairs.add((joint, movement))
        for s in stabilizes:
            if s.get("demand") not in vocabulary["stabilization_demands"]:
                problems.append(f"{where}: unknown stabilization demand {s.get('demand')!r}")
            if not isinstance(s.get("weight"), (int, float)) or not 0.1 <= s["weight"] <= 1.0:
                problems.append(f"{where}: stabilization weight {s.get('weight')!r} must be 0.1-1.0")
    missing = sorted(set(expected) - seen)
    if missing:
        problems.append(f"{group}: missing muscles {', '.join(missing)}")
    return problems


def merged_table() -> Tuple[List[Dict[str, Any]], List[str]]:
    """Expand every group file to per-side records (v1-compatible shape plus
    weights). Returns (records, groups_missing)."""
    groups = group_muscles()
    records: List[Dict[str, Any]] = []
    missing: List[str] = []
    for group in GROUP_ORDER:
        path = TABLE_DIR / f"{group}.json"
        if not path.exists():
            missing.append(group)
            continue
        document = json.loads(path.read_text(encoding="utf-8"))
        sides = {m["base_id"]: m["muscle_ids"] for m in groups[group]}
        for entry in document["entries"]:
            for muscle_id in sides[entry["base_id"]]:
                records.append({
                    "muscle_id": muscle_id,
                    "group": group,
                    "movement_muscle": entry["movement_muscle"],
                    "actions": entry["actions"],
                    "stabilizes": entry["stabilizes"],
                    "confidence": entry["confidence"],
                    "status": entry["status"],
                })
    return records, missing
