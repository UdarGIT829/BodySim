"""
Kinematic tracer v2 for BodySim.

Turns an exercise's kinematic profile (joint actions + stabilization demands
+ laterality) into an engagement profile covering all 466 canonical muscles,
using the curated, weighted muscle-action table v2
(data/anatomy/muscle_actions_v2/, see src/anatomy/muscle_actions_v2.py).

Rules
- Action score = the muscle's highest table weight among the exercise's
  joint actions (exact joint + movement match).
    score >= 0.7  -> primary,   coefficient = score
    score >  0    -> synergist, coefficient = score
- Otherwise, if the muscle serves one of the exercise's stabilization
  demands: stabilizer, coefficient = STABILIZER_SCALE x its highest demand
  weight (stabilizing is lower-intensity than moving the load).
- Otherwise: none, coefficient 0 (an explicit, reviewed zero).
- Laterality: actions at limb joints (shoulder girdle, shoulder, elbow,
  forearm, wrist, hand, hip, knee, ankle, foot) only count on the working
  side ("left"/"right"; "unilateral" is shown with the right side working, by
  convention). This is decided by the joint, not by where the muscle lies, so
  pectoralis major and latissimus dorsi, which sit on the trunk but move the
  arm, follow the working side too. Spinal actions and every stabilization
  role count on both sides, because one-sided loading is braced by both
  sides of the trunk.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict, List

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.anatomy.muscle_actions_v2 import merged_table  # noqa: E402

TRACER_VERSION = "kinematic_tracer_v2"
ANATOMY_CATALOG = PROJECT_ROOT / "data/anatomy/structures.json"
EXERCISES_FILE = PROJECT_ROOT / "data/exercises/exercises.json"
OUTPUT_PROFILES_FILE = PROJECT_ROOT / "data/exercises/engagement_profiles.json"

PRIMARY_THRESHOLD = 0.7
STABILIZER_SCALE = 0.35
AXIAL_JOINTS = {"cervical_spine", "lumbar_spine"}
WORKING_SIDE = {"left": "left", "right": "right", "unilateral": "right"}


def load_muscle_actions() -> Dict[str, Dict[str, Any]]:
    records, missing = merged_table()
    if missing:
        raise ValueError(f"muscle-action table v2 is missing groups: {', '.join(missing)}")
    return {r["muscle_id"]: r for r in records}


def load_inputs():
    structures = json.loads(ANATOMY_CATALOG.read_text(encoding="utf-8"))["structures"]
    canonical_muscle_ids = [s["id"] for s in structures if s.get("id", "").startswith("muscle.")]
    exercises = json.loads(EXERCISES_FILE.read_text(encoding="utf-8"))
    return canonical_muscle_ids, load_muscle_actions(), exercises


def _side(muscle_id: str) -> str:
    if muscle_id.endswith(".left"):
        return "left"
    if muscle_id.endswith(".right"):
        return "right"
    return "unpaired"


def trace_exercise_kinematics(
    exercise: Dict[str, Any],
    canonical_muscle_ids: List[str],
    muscle_actions: Dict[str, Dict[str, Any]],
) -> List[Dict[str, Any]]:
    """Engagement profile entries for all canonical muscles for one exercise."""
    profile = exercise.get("kinematic_profile", {})
    targets = {(a["joint"], a["movement"]) for a in profile.get("primary_joint_actions", [])}
    demands = set(profile.get("stabilization_demands", []))
    working_side = WORKING_SIDE.get(exercise.get("laterality", "bilateral"))

    entries = []
    for muscle_id in canonical_muscle_ids:
        record = muscle_actions.get(muscle_id)
        role, coefficient, refs = "none", 0.0, []
        if record and record.get("movement_muscle"):
            base = muscle_id.rsplit(".", 1)[0] if _side(muscle_id) != "unpaired" else muscle_id
            off_side = working_side is not None and _side(muscle_id) not in (working_side, "unpaired")
            matching = [a for a in record["actions"] if (a["joint"], a["movement"]) in targets]
            # On the non-working side only spinal actions move the load.
            off_side_limb = off_side and any(a["joint"] not in AXIAL_JOINTS for a in matching)
            if off_side:
                matching = [a for a in matching if a["joint"] in AXIAL_JOINTS]
            action_score = max((a["weight"] for a in matching), default=0.0)
            stability = max((s["weight"] for s in record["stabilizes"] if s["demand"] in demands), default=0.0)
            if action_score >= PRIMARY_THRESHOLD:
                role, coefficient = "primary", action_score
            elif action_score > 0:
                role, coefficient = "synergist", action_score
            elif stability > 0:
                role, coefficient = "stabilizer", STABILIZER_SCALE * stability
            if role != "none":
                refs = [f"muscle_actions_v2:{base}", f"rule.{TRACER_VERSION}.{role}"]
                if off_side_limb:
                    refs.append(f"rule.{TRACER_VERSION}.non_working_side")
        coefficient = round(coefficient, 4)
        entries.append({
            "muscle_id": muscle_id,
            "role": role,
            "coefficient": coefficient,
            "confidence": record["confidence"] if role != "none" and record else "high",
            "evidence_status": "kinematic_trace" if role != "none" else "reviewed_zero",
            "derivation_method": TRACER_VERSION,
            "evidence_refs": refs or [f"rule.{TRACER_VERSION}.reviewed_zero"],
        })
    return entries


def run_tracer() -> None:
    canonical_muscle_ids, muscle_actions, exercises = load_inputs()
    print(f"Tracing {len(exercises)} exercises against {len(canonical_muscle_ids)} canonical muscles…")
    output = {"profiles": {}}
    for exercise in exercises:
        entries = trace_exercise_kinematics(exercise, canonical_muscle_ids, muscle_actions)
        if len(entries) != 466:
            raise ValueError(f"{exercise['id']} produced {len(entries)} entries instead of 466")
        mapped = sum(1 for e in entries if e["coefficient"] > 0)
        output["profiles"][exercise["id"]] = {
            "exercise_id": exercise["id"],
            "total_muscles": len(entries),
            "mapped_muscles": mapped,
            "zero_muscles": len(entries) - mapped,
            "muscles": entries,
        }
    OUTPUT_PROFILES_FILE.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(f"Wrote {len(exercises)} engagement profiles to {OUTPUT_PROFILES_FILE.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    run_tracer()
