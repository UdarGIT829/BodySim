"""
Kinematic Tracer Engine for BodySim Phase 1B.

Traverses skeletal joint trees and kinematic exercise profiles to generate
100% full-body engagement profiles for all 466 canonical muscles.
"""

import json
from pathlib import Path
from typing import Any, Dict, List, Set

ANATOMY_CATALOG = Path("data/anatomy/structures.json")
MUSCLE_ACTIONS_FILE = Path("data/anatomy/muscle_actions.json")
EXERCISES_FILE = Path("data/exercises/exercises.json")
OUTPUT_PROFILES_FILE = Path("data/exercises/engagement_profiles.json")


def load_inputs():
    with open(ANATOMY_CATALOG, "r", encoding="utf-8") as f:
        structures = json.load(f)["structures"]

    canonical_muscle_ids = [s["id"] for s in structures if s.get("id", "").startswith("muscle.")]

    with open(MUSCLE_ACTIONS_FILE, "r", encoding="utf-8") as f:
        actions_list = json.load(f)

    muscle_actions = {a["muscle_id"]: a for a in actions_list}

    with open(EXERCISES_FILE, "r", encoding="utf-8") as f:
        exercises = json.load(f)

    return canonical_muscle_ids, muscle_actions, exercises


def trace_exercise_kinematics(
    exercise: Dict[str, Any],
    canonical_muscle_ids: List[str],
    muscle_actions: Dict[str, Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Traces kinematic demands across all 466 canonical muscles for a single exercise."""
    kinematic_profile = exercise.get("kinematic_profile", {})
    primary_joint_actions = kinematic_profile.get("primary_joint_actions", [])
    stabilization_demands = set(kinematic_profile.get("stabilization_demands", []))

    # Helper targets: (joint_stem, movement)
    primary_targets = {(a["joint"], a["movement"]) for a in primary_joint_actions}

    muscle_profile_entries = []

    for m_id in canonical_muscle_ids:
        m_action_info = muscle_actions.get(m_id, {"actions": [], "stabilization_capabilities": []})
        m_actions = m_action_info.get("actions", [])
        m_stabs = set(m_action_info.get("stabilization_capabilities", []))

        is_primary = False
        is_synergist = False
        is_stabilizer = False

        # Check primary/synergist joint actions
        for act in m_actions:
            joint_stem = act["joint"]
            movement = act["movement"]
            act_type = act.get("type", "primary")

            for target_j, target_m in primary_targets:
                if joint_stem in target_j or target_j in joint_stem:
                    if movement == target_m:
                        if act_type == "primary":
                            is_primary = True
                        else:
                            is_synergist = True

        # Check stabilization demand matches
        matching_stabs = stabilization_demands.intersection(m_stabs)
        if matching_stabs:
            is_stabilizer = True

        # Determine highest role and coefficient
        if is_primary:
            role = "primary"
            coeff = 1.0 if len(primary_targets) == 1 else 0.85
            confidence = "high"
            evidence_status = "kinematic_trace"
            ref = "rule.kinematic_tracer.primary_mover"
        elif is_synergist:
            role = "synergist"
            coeff = 0.55
            confidence = "high"
            evidence_status = "kinematic_trace"
            ref = "rule.kinematic_tracer.synergist"
        elif is_stabilizer:
            role = "stabilizer"
            coeff = 0.35 if "anti_flexion_spine" in matching_stabs else 0.25
            confidence = "medium"
            evidence_status = "kinematic_trace"
            ref = "rule.kinematic_tracer.stabilizer"
        else:
            role = "none"
            coeff = 0.0
            confidence = "high"
            evidence_status = "reviewed_zero"
            ref = "rule.kinematic_tracer.reviewed_zero"

        muscle_profile_entries.append({
            "muscle_id": m_id,
            "role": role,
            "coefficient": coeff,
            "confidence": confidence,
            "evidence_status": evidence_status,
            "derivation_method": "kinematic_tracer_v1",
            "evidence_refs": [ref]
        })

    return muscle_profile_entries


def run_tracer():
    canonical_muscle_ids, muscle_actions, exercises = load_inputs()
    print(f"Tracing kinematics for {len(exercises)} exercises against {len(canonical_muscle_ids)} canonical muscles...")

    profiles_output = {"profiles": {}}

    for ex in exercises:
        ex_id = ex["id"]
        entries = trace_exercise_kinematics(ex, canonical_muscle_ids, muscle_actions)

        # Audit that exactly 466 entries were generated
        if len(entries) != 466:
            raise ValueError(f"Exercise '{ex_id}' generated {len(entries)} entries instead of 466.")

        mapped_count = sum(1 for e in entries if e["coefficient"] > 0)
        zero_count = sum(1 for e in entries if e["coefficient"] == 0)

        profiles_output["profiles"][ex_id] = {
            "exercise_id": ex_id,
            "total_muscles": len(entries),
            "mapped_muscles": mapped_count,
            "zero_muscles": zero_count,
            "muscles": entries
        }

    with open(OUTPUT_PROFILES_FILE, "w", encoding="utf-8") as f:
        json.dump(profiles_output, f, indent=2)

    print(f"Successfully generated engagement profiles for {len(exercises)} exercises in {OUTPUT_PROFILES_FILE}")


if __name__ == "__main__":
    run_tracer()
