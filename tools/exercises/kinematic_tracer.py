"""
Kinematic tracer v3 for BodySim.

Turns an exercise's kinematic profile (joint actions + stabilization demands
+ laterality) into an engagement profile covering all 466 canonical muscles,
using the curated, weighted muscle-action table v2
(data/anatomy/muscle_actions_v2/, see src/anatomy/muscle_actions_v2.py).

Rules
- Action score = the muscle's highest table weight among the exercise's
  joint actions (exact joint + movement match). An action marked
  ``"emphasis": "assist"`` counts at ASSIST_SCALE x its weight, so it can
  make a muscle a synergist but never a primary mover (e.g. the calves in a
  squat, or the light knee bend of a bicycle crunch).
    score >= 0.7  -> primary,   coefficient = score
    score >  0    -> synergist, coefficient = score
- Otherwise, if the muscle serves one of the exercise's stabilization
  demands: stabilizer, coefficient = STABILIZER_SCALE x its highest demand
  weight (stabilizing is lower-intensity than moving the load).
- Otherwise: none, coefficient 0 (an explicit, reviewed zero).
- Laterality, for "left"/"right"/"unilateral" ("unilateral" is shown with
  the right side working, by convention):
  - Actions at limb joints count only on the working side, decided by the
    joint (so pectoralis major and latissimus follow the working arm),
    unless the action is marked ``"sides": "both"`` (e.g. the two-legged
    hip hinge of a one-arm kettlebell windmill). Spinal actions count on
    both sides.
  - Limb demands (arm: grip, wrist, elbow, shoulder and scapular demands;
    leg: knee, patella, ankle and femoral-head demands) count only on the
    working side for the limbs that carry the one-sided load, so the free
    arm of a one-arm push-up isn't loaded. Those limbs are
    ``kinematic_profile.one_sided_limbs`` (any of "arm", "leg") when given,
    otherwise inferred from the working-side limb actions (both when there
    are none). Trunk and posture demands always count on both sides.
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

TRACER_VERSION = "kinematic_tracer_v3"
ANATOMY_CATALOG = PROJECT_ROOT / "data/anatomy/structures.json"
EXERCISES_FILE = PROJECT_ROOT / "data/exercises/exercises.json"
OUTPUT_PROFILES_FILE = PROJECT_ROOT / "data/exercises/engagement_profiles.json"

PRIMARY_THRESHOLD = 0.7
STABILIZER_SCALE = 0.35
ASSIST_SCALE = 0.4   # max assisted score 0.4 < PRIMARY_THRESHOLD
AXIAL_JOINTS = {"cervical_spine", "lumbar_spine"}
WORKING_SIDE = {"left": "left", "right": "right", "unilateral": "right"}
LIMB_OF_JOINT = {
    "scapulothoracic_joint": "arm", "glenohumeral_joint": "arm", "elbow_joint": "arm", "radioulnar_joint": "arm",
    "wrist_joint": "arm", "finger_joints": "arm", "thumb_joints": "arm",
    "hip_joint": "leg", "knee_joint": "leg", "ankle_joint": "leg", "subtalar_joint": "leg", "toe_joints": "leg",
}
LIMB_OF_DEMAND = {
    **{d: "arm" for d in ("grip", "wrist_stability", "elbow_joint_integrity", "elbow_stability", "shoulder_position_hold",
                          "glenohumeral_stabilization", "humeral_head_stabilization", "anterior_shoulder_stability",
                          "scapular_stabilization", "scapular_anchoring", "scapular_retraction_stability")},
    **{d: "leg" for d in ("knee_joint_stability", "patellar_tracking", "ankle_stability", "femoral_head_stabilization")},
}
LIMBS = ("arm", "leg")


def one_sided_limbs(profile: Dict[str, Any]) -> set:
    """Limbs whose demands follow the working side in a one-sided exercise."""
    explicit = profile.get("one_sided_limbs")
    if isinstance(explicit, list):
        return {limb for limb in explicit if limb in LIMBS}
    inferred = {LIMB_OF_JOINT[a.get("joint")] for a in profile.get("primary_joint_actions", [])
                if a.get("joint") in LIMB_OF_JOINT and a.get("sides", "working") != "both"}
    return inferred or set(LIMBS)


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
    actions = profile.get("primary_joint_actions", [])
    demands = set(profile.get("stabilization_demands", []))
    working_side = WORKING_SIDE.get(exercise.get("laterality", "bilateral"))
    lateral_limbs = one_sided_limbs(profile) if working_side else set()

    entries = []
    for muscle_id in canonical_muscle_ids:
        record = muscle_actions.get(muscle_id)
        role, coefficient, refs = "none", 0.0, []
        if record and record.get("movement_muscle"):
            base = muscle_id.rsplit(".", 1)[0] if _side(muscle_id) != "unpaired" else muscle_id
            off_side = working_side is not None and _side(muscle_id) not in (working_side, "unpaired")
            scores, off_side_limb, assisted = [], False, False
            for target in actions:
                weight = max((a["weight"] for a in record["actions"]
                              if (a["joint"], a["movement"]) == (target.get("joint"), target.get("movement"))), default=0.0)
                if weight <= 0:
                    continue
                # On the non-working side only spinal actions and "both sides" actions move the load.
                if off_side and target.get("joint") not in AXIAL_JOINTS and target.get("sides", "working") != "both":
                    off_side_limb = True
                    continue
                if target.get("emphasis", "primary") == "assist":
                    weight *= ASSIST_SCALE
                scores.append((weight, target.get("emphasis", "primary") == "assist"))
            action_score = max((w for w, _ in scores), default=0.0)
            assisted = bool(scores) and all(a for w, a in scores if w == action_score)
            served = [s for s in record["stabilizes"] if s["demand"] in demands
                      and not (off_side and LIMB_OF_DEMAND.get(s["demand"]) in lateral_limbs)]
            off_side_limb = off_side_limb or (off_side and any(
                s["demand"] in demands and LIMB_OF_DEMAND.get(s["demand"]) in lateral_limbs for s in record["stabilizes"]))
            stability = max((s["weight"] for s in served), default=0.0)
            if action_score >= PRIMARY_THRESHOLD:
                role, coefficient = "primary", action_score
            elif action_score > 0:
                role, coefficient = "synergist", action_score
            elif stability > 0:
                role, coefficient = "stabilizer", STABILIZER_SCALE * stability
            if role != "none":
                refs = [f"muscle_actions_v2:{base}", f"rule.{TRACER_VERSION}.{role}"]
                if assisted and role == "synergist":
                    refs.append(f"rule.{TRACER_VERSION}.assist")
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
    # Keep every key other than the traced muscles and counts (e.g. a council
    # promotion's metadata), so re-tracing never drops provenance.
    existing = json.loads(OUTPUT_PROFILES_FILE.read_text(encoding="utf-8")).get("profiles", {}) if OUTPUT_PROFILES_FILE.exists() else {}
    output = {"profiles": {}}
    for exercise in exercises:
        entries = trace_exercise_kinematics(exercise, canonical_muscle_ids, muscle_actions)
        if len(entries) != 466:
            raise ValueError(f"{exercise['id']} produced {len(entries)} entries instead of 466")
        mapped = sum(1 for e in entries if e["coefficient"] > 0)
        output["profiles"][exercise["id"]] = {
            **existing.get(exercise["id"], {}),
            "exercise_id": exercise["id"],
            "total_muscles": len(entries),
            "mapped_muscles": mapped,
            "zero_muscles": len(entries) - mapped,
            "muscles": entries,
        }
    OUTPUT_PROFILES_FILE.write_text(json.dumps(output, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Wrote {len(exercises)} engagement profiles to {OUTPUT_PROFILES_FILE.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    run_tracer()
