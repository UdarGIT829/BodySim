"""Isolated Phase 2C compatibility gate for an authored exercise definition."""

from __future__ import annotations

import json
import hashlib
from pathlib import Path
from typing import Any, Dict, List

from src.exercises.schemas import validate_exercises
from tools.exercises.kinematic_tracer import trace_exercise_kinematics


PROJECT_ROOT = Path(__file__).resolve().parents[2]
STRUCTURES_PATH = PROJECT_ROOT / "data/anatomy/structures.json"
MUSCLE_ACTIONS_PATH = PROJECT_ROOT / "data/anatomy/muscle_actions.json"
CANONICAL_EXERCISES_PATH = PROJECT_ROOT / "data/exercises/exercises.json"


def evaluate_candidate(definition: Dict[str, Any]) -> Dict[str, Any]:
    errors: List[str] = []
    warnings: List[str] = []

    is_valid, schema_errors = validate_exercises([definition])
    errors.extend(f"definition: {message}" for message in schema_errors)

    canonical_exercises = _read_json(CANONICAL_EXERCISES_PATH)
    canonical_ids = {entry["id"] for entry in canonical_exercises}
    exercise_id = definition.get("id", "")
    if exercise_id in canonical_ids:
        errors.append(f"definition.id: '{exercise_id}' already exists in the canonical catalog")

    structures = _read_json(STRUCTURES_PATH)["structures"]
    canonical_muscle_ids = [
        structure["id"]
        for structure in structures
        if structure.get("id", "").startswith("muscle.")
    ]
    action_records = _read_json(MUSCLE_ACTIONS_PATH)
    muscle_actions = {record["muscle_id"]: record for record in action_records}

    profile_entries: List[Dict[str, Any]] = []
    if not errors:
        profile_entries = trace_exercise_kinematics(definition, canonical_muscle_ids, muscle_actions)
        errors.extend(_validate_trace(profile_entries, canonical_muscle_ids))

    action_coverage = _joint_action_coverage(definition, action_records)
    for coverage in action_coverage:
        if coverage["matching_muscles"] == 0:
            errors.append(
                "kinematic_profile.primary_joint_actions: "
                f"{coverage['joint']} + {coverage['movement']} maps to no canonical muscles"
            )

    stabilization_coverage = _stabilization_coverage(definition, action_records)
    for coverage in stabilization_coverage:
        if coverage["matching_muscles"] == 0:
            errors.append(
                "kinematic_profile.stabilization_demands: "
                f"{coverage['demand']} maps to no canonical muscles"
            )

    role_counts = {role: 0 for role in ("primary", "synergist", "stabilizer", "none")}
    for entry in profile_entries:
        role_counts[entry.get("role", "none")] = role_counts.get(entry.get("role", "none"), 0) + 1
    mapped_muscles = sum(1 for entry in profile_entries if entry.get("coefficient", 0) > 0)
    if profile_entries and mapped_muscles == 0:
        errors.append("trace: definition produced zero affected muscles")
    if profile_entries and role_counts["primary"] == 0 and role_counts["synergist"] == 0:
        warnings.append("Trace has stabilizers but no primary movers or synergists.")

    return {
        "gate_version": "candidate_trace_gate_v1",
        "ok": not errors,
        "exercise_id": exercise_id,
        "errors": errors,
        "warnings": warnings,
        "summary": {
            "total_muscles": len(profile_entries),
            "mapped_muscles": mapped_muscles,
            "zero_muscles": len(profile_entries) - mapped_muscles,
            "role_counts": role_counts,
            "joint_action_coverage": action_coverage,
            "stabilization_coverage": stabilization_coverage,
        },
        "provenance": {
            "tracer": "kinematic_tracer_v1",
            "structures_sha256": _sha256(STRUCTURES_PATH),
            "muscle_actions_sha256": _sha256(MUSCLE_ACTIONS_PATH),
            "canonical_exercises_sha256": _sha256(CANONICAL_EXERCISES_PATH),
        },
        "profile": {
            "exercise_id": exercise_id,
            "total_muscles": len(profile_entries),
            "mapped_muscles": mapped_muscles,
            "zero_muscles": len(profile_entries) - mapped_muscles,
            "muscles": profile_entries,
        },
    }


def _validate_trace(entries: List[Dict[str, Any]], canonical_ids: List[str]) -> List[str]:
    errors: List[str] = []
    if len(entries) != 466:
        errors.append(f"trace: expected 466 muscle entries, received {len(entries)}")
    entry_ids = [entry.get("muscle_id") for entry in entries]
    if len(set(entry_ids)) != len(entry_ids):
        errors.append("trace: duplicate canonical muscle IDs")
    if set(entry_ids) != set(canonical_ids):
        errors.append("trace: output muscle IDs do not exactly match the canonical 466-muscle set")
    for index, entry in enumerate(entries):
        role = entry.get("role")
        coefficient = entry.get("coefficient")
        if role not in {"primary", "synergist", "stabilizer", "none"}:
            errors.append(f"trace.muscles[{index}].role: unknown value '{role}'")
        if not isinstance(coefficient, (int, float)) or not 0.0 <= coefficient <= 1.0:
            errors.append(f"trace.muscles[{index}].coefficient: must be between 0 and 1")
        if role == "none" and coefficient != 0.0:
            errors.append(f"trace.muscles[{index}]: role none must have coefficient 0")
        if role != "none" and coefficient == 0.0:
            errors.append(f"trace.muscles[{index}]: active role must have a positive coefficient")
        if entry.get("confidence") not in {"high", "medium", "low"}:
            errors.append(f"trace.muscles[{index}].confidence: unknown value")
        expected_status = "reviewed_zero" if role == "none" else "kinematic_trace"
        if entry.get("evidence_status") != expected_status:
            errors.append(
                f"trace.muscles[{index}].evidence_status: expected '{expected_status}'"
            )
        if entry.get("derivation_method") != "kinematic_tracer_v1":
            errors.append(f"trace.muscles[{index}].derivation_method: unexpected tracer version")
        refs = entry.get("evidence_refs")
        if not isinstance(refs, list) or not refs or not all(isinstance(ref, str) for ref in refs):
            errors.append(f"trace.muscles[{index}].evidence_refs: must contain rule references")
    return errors


def _joint_action_coverage(definition: Dict[str, Any], records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    result = []
    actions = definition.get("kinematic_profile", {}).get("primary_joint_actions", [])
    for target in actions:
        count = 0
        for record in records:
            if any(
                action.get("joint") == target.get("joint")
                and action.get("movement") == target.get("movement")
                for action in record.get("actions", [])
            ):
                count += 1
        result.append({
            "joint": target.get("joint", ""),
            "movement": target.get("movement", ""),
            "matching_muscles": count,
        })
    return result


def _stabilization_coverage(definition: Dict[str, Any], records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    result = []
    demands = definition.get("kinematic_profile", {}).get("stabilization_demands", [])
    for demand in demands:
        count = sum(
            1 for record in records
            if demand in record.get("stabilization_capabilities", [])
        )
        result.append({"demand": demand, "matching_muscles": count})
    return result


def _read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()
