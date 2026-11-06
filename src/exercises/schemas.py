"""
Data contracts, schema definitions, and validators for BodySim Phase 1A.

Covers:
- Muscle Action Matrix (data/anatomy/muscle_actions.json)
- Kinematic Exercise Definitions (data/exercises/exercises.json)
- Derived Engagement Profiles (data/exercises/engagement_profiles.json)
- OpenSim Calibration Anchors (data/exercises/opensim_calibration.json)
- Source Crosswalk (data/exercises/sources/crosswalk.json)
- Performed Workouts (data/workouts/example_workout.json)
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple


VALID_DERIVATION_METHODS = {"kinematic_tracer_v1", "opensim_calibrated", "manual_override"}
VALID_EVIDENCE_STATUSES = {"kinematic_trace", "opensim_calibrated", "reviewed", "provisional", "unresolved"}
VALID_CONFIDENCE_LEVELS = {"high", "medium", "low"}
VALID_ROLES = {"primary", "synergist", "stabilizer"}
VALID_LATERALITIES = {"bilateral", "left", "right", "unilateral"}
VALID_INPUT_MODES = {"repetitions", "duration"}
VALID_KINETIC_CHAIN_TYPES = {"open_chain", "closed_chain"}
VALID_CROSSWALK_STATUSES = {"candidate", "accepted", "merged_alias", "split_into_variants", "excluded"}


def load_canonical_muscle_ids(catalog_path: str | Path = "data/anatomy/structures.json") -> Set[str]:
    """Loads all 466 canonical skeletal muscle IDs from structures.json."""
    path = Path(catalog_path)
    if not path.is_file():
        raise FileNotFoundError(f"Catalog file not found: {path}")

    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    structures = data.get("structures", [])
    muscle_ids = {s["id"] for s in structures if isinstance(s, dict) and s.get("id", "").startswith("muscle.")}

    if len(muscle_ids) != 466:
        raise ValueError(f"Expected exactly 466 canonical muscle IDs, found {len(muscle_ids)}")

    return muscle_ids


def validate_muscle_actions(
    data: List[Dict[str, Any]], canonical_muscle_ids: Set[str] | None = None
) -> Tuple[bool, List[str]]:
    """Validates data/anatomy/muscle_actions.json content."""
    errors = []
    if not isinstance(data, list):
        return False, ["Root structure must be a JSON array of muscle action entries."]

    seen_ids = set()
    for idx, entry in enumerate(data):
        if not isinstance(entry, dict):
            errors.append(f"Entry {idx} is not an object.")
            continue

        muscle_id = entry.get("muscle_id")
        if not muscle_id or not isinstance(muscle_id, str):
            errors.append(f"Entry {idx} missing valid 'muscle_id'.")
            continue

        if muscle_id in seen_ids:
            errors.append(f"Duplicate muscle_id '{muscle_id}' in muscle_actions.")
        seen_ids.add(muscle_id)

        if canonical_muscle_ids and muscle_id not in canonical_muscle_ids:
            errors.append(f"Entry {idx}: muscle_id '{muscle_id}' is not in canonical structures catalog.")

        spanned_joints = entry.get("spanned_joints")
        if not isinstance(spanned_joints, list) or not spanned_joints:
            errors.append(f"Entry {idx} ({muscle_id}): 'spanned_joints' must be a non-empty list.")

        actions = entry.get("actions")
        if not isinstance(actions, list):
            errors.append(f"Entry {idx} ({muscle_id}): 'actions' must be a list.")
        else:
            for a_idx, action in enumerate(actions):
                if not isinstance(action, dict):
                    errors.append(f"Entry {idx} ({muscle_id}) action {a_idx} is not an object.")
                    continue
                if "joint" not in action or "movement" not in action:
                    errors.append(f"Entry {idx} ({muscle_id}) action {a_idx} missing 'joint' or 'movement'.")

        stabilization = entry.get("stabilization_capabilities", [])
        if not isinstance(stabilization, list):
            errors.append(f"Entry {idx} ({muscle_id}): 'stabilization_capabilities' must be a list.")

    return len(errors) == 0, errors


def validate_exercises(data: List[Dict[str, Any]]) -> Tuple[bool, List[str]]:
    """Validates data/exercises/exercises.json content."""
    errors = []
    if not isinstance(data, list):
        return False, ["Root structure must be a JSON array of exercise entries."]

    seen_ids = set()
    for idx, entry in enumerate(data):
        if not isinstance(entry, dict):
            errors.append(f"Entry {idx} is not an object.")
            continue

        ex_id = entry.get("id")
        if not ex_id or not isinstance(ex_id, str) or not ex_id.startswith("exercise."):
            errors.append(f"Entry {idx}: 'id' must start with 'exercise.'. Got '{ex_id}'")
            continue

        if ex_id in seen_ids:
            errors.append(f"Duplicate exercise id '{ex_id}'.")
        seen_ids.add(ex_id)

        name = entry.get("name")
        if not name or not isinstance(name, str):
            errors.append(f"Exercise '{ex_id}' missing 'name'.")

        variant = entry.get("variant")
        if not variant or not isinstance(variant, str):
            errors.append(f"Exercise '{ex_id}' missing 'variant'.")

        laterality = entry.get("laterality")
        if laterality not in VALID_LATERALITIES:
            errors.append(f"Exercise '{ex_id}': invalid laterality '{laterality}'. Must be one of {VALID_LATERALITIES}.")

        input_mode = entry.get("input_mode")
        if input_mode not in VALID_INPUT_MODES:
            errors.append(f"Exercise '{ex_id}': invalid input_mode '{input_mode}'. Must be one of {VALID_INPUT_MODES}.")

        kinematic_profile = entry.get("kinematic_profile")
        if not isinstance(kinematic_profile, dict):
            errors.append(f"Exercise '{ex_id}' missing valid 'kinematic_profile' dict.")
        else:
            chain_type = kinematic_profile.get("kinetic_chain_type")
            if chain_type not in VALID_KINETIC_CHAIN_TYPES:
                errors.append(f"Exercise '{ex_id}': invalid kinetic_chain_type '{chain_type}'.")

            primary_actions = kinematic_profile.get("primary_joint_actions")
            if not isinstance(primary_actions, list) or not primary_actions:
                errors.append(f"Exercise '{ex_id}': 'primary_joint_actions' must be a non-empty list.")

            # Deprecated legacy metadata: load_vector never affected tracing or scoring.
            # Existing canonical records may retain it, but new definitions do not need it.

    return len(errors) == 0, errors


def validate_engagement_profiles(
    data: Dict[str, Any], canonical_muscle_ids: Set[str] | None = None
) -> Tuple[bool, List[str]]:
    """Validates data/exercises/engagement_profiles.json content."""
    errors = []
    if not isinstance(data, dict):
        return False, ["Root structure must be a JSON dict keyed by exercise_id."]

    profiles = data.get("profiles", {})
    if not isinstance(profiles, dict):
        return False, ["Engagement profiles must contain a 'profiles' dict."]

    for ex_id, profile in profiles.items():
        if not isinstance(profile, dict):
            errors.append(f"Profile for '{ex_id}' is not a dict.")
            continue

        muscles = profile.get("muscles")
        if not isinstance(muscles, list):
            errors.append(f"Profile '{ex_id}' missing 'muscles' list.")
            continue

        profile_muscle_ids = set()
        for idx, entry in enumerate(muscles):
            if not isinstance(entry, dict):
                errors.append(f"Profile '{ex_id}' muscle {idx} is not an object.")
                continue

            m_id = entry.get("muscle_id")
            if not m_id or not isinstance(m_id, str):
                errors.append(f"Profile '{ex_id}' muscle {idx} missing 'muscle_id'.")
                continue

            if m_id in profile_muscle_ids:
                errors.append(f"Profile '{ex_id}' has duplicate muscle_id '{m_id}'.")
            profile_muscle_ids.add(m_id)

            if canonical_muscle_ids and m_id not in canonical_muscle_ids:
                errors.append(f"Profile '{ex_id}' muscle '{m_id}' is not in canonical structures catalog.")

            role = entry.get("role")
            if role not in VALID_ROLES:
                errors.append(f"Profile '{ex_id}' muscle '{m_id}' invalid role '{role}'.")

            coeff = entry.get("coefficient")
            if not isinstance(coeff, (int, float)) or not (0.0 <= coeff <= 1.0):
                errors.append(f"Profile '{ex_id}' muscle '{m_id}' coefficient must be between 0.0 and 1.0. Got {coeff}")

            conf = entry.get("confidence")
            if conf not in VALID_CONFIDENCE_LEVELS:
                errors.append(f"Profile '{ex_id}' muscle '{m_id}' invalid confidence '{conf}'.")

            status = entry.get("evidence_status")
            if status not in VALID_EVIDENCE_STATUSES:
                errors.append(f"Profile '{ex_id}' muscle '{m_id}' invalid evidence_status '{status}'.")

    return len(errors) == 0, errors


def validate_opensim_calibration(
    data: List[Dict[str, Any]], canonical_muscle_ids: Set[str] | None = None
) -> Tuple[bool, List[str]]:
    """Validates data/exercises/opensim_calibration.json content."""
    errors = []
    if not isinstance(data, list):
        return False, ["Root structure must be a JSON array of calibration entries."]

    for idx, entry in enumerate(data):
        if not isinstance(entry, dict):
            errors.append(f"Entry {idx} is not an object.")
            continue

        ex_id = entry.get("exercise_id")
        if not ex_id or not isinstance(ex_id, str):
            errors.append(f"Calibration entry {idx} missing 'exercise_id'.")

        model = entry.get("opensim_model")
        if not model or not isinstance(model, str):
            errors.append(f"Calibration entry {idx} missing 'opensim_model'.")

        p_muscle = entry.get("primary_mover_muscle_id")
        if not p_muscle or not isinstance(p_muscle, str):
            errors.append(f"Calibration entry {idx} missing 'primary_mover_muscle_id'.")
        elif canonical_muscle_ids and p_muscle not in canonical_muscle_ids:
            errors.append(f"Calibration entry {idx} primary mover '{p_muscle}' is not in canonical catalog.")

        force_n = entry.get("opensim_force_n")
        if force_n is not None and (not isinstance(force_n, (int, float)) or force_n < 0):
            errors.append(f"Calibration entry {idx} invalid 'opensim_force_n': {force_n}")

        act = entry.get("opensim_activation")
        if act is not None and (not isinstance(act, (int, float)) or not (0.0 <= act <= 1.0)):
            errors.append(f"Calibration entry {idx} invalid 'opensim_activation': {act}")

    return len(errors) == 0, errors


def validate_crosswalk(data: List[Dict[str, Any]]) -> Tuple[bool, List[str]]:
    """Validates data/exercises/sources/crosswalk.json content."""
    errors = []
    if not isinstance(data, list):
        return False, ["Root structure must be a JSON array of crosswalk records."]

    for idx, entry in enumerate(data):
        if not isinstance(entry, dict):
            errors.append(f"Crosswalk entry {idx} is not an object.")
            continue

        src = entry.get("source")
        if not src or not isinstance(src, str):
            errors.append(f"Crosswalk entry {idx} missing 'source'.")

        src_id = entry.get("source_id")
        if not src_id or not isinstance(src_id, str):
            errors.append(f"Crosswalk entry {idx} missing 'source_id'.")

        status = entry.get("review_status")
        if status not in VALID_CROSSWALK_STATUSES:
            errors.append(f"Crosswalk entry {idx} invalid review_status '{status}'.")

        bs_ids = entry.get("body_sim_exercise_ids", [])
        if not isinstance(bs_ids, list):
            errors.append(f"Crosswalk entry {idx} 'body_sim_exercise_ids' must be a list.")

    return len(errors) == 0, errors


def validate_workout(data: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """Validates data/workouts/*.json files."""
    errors = []
    if not isinstance(data, dict):
        return False, ["Workout root must be a JSON object."]

    session_id = data.get("session_id")
    if not session_id or not isinstance(session_id, str):
        errors.append("Workout missing 'session_id'.")

    exercises = data.get("exercises")
    if not isinstance(exercises, list) or not exercises:
        errors.append("Workout 'exercises' must be a non-empty list.")
    else:
        for idx, ex in enumerate(exercises):
            if not isinstance(ex, dict):
                errors.append(f"Workout exercise {idx} is not an object.")
                continue

            ex_id = ex.get("exercise_id")
            if not ex_id or not isinstance(ex_id, str):
                errors.append(f"Workout exercise {idx} missing 'exercise_id'.")

            sets = ex.get("sets")
            if not isinstance(sets, list) or not sets:
                errors.append(f"Workout exercise '{ex_id}' must have a non-empty 'sets' list.")
            else:
                for s_idx, set_entry in enumerate(sets):
                    if not isinstance(set_entry, dict):
                        errors.append(f"Workout exercise '{ex_id}' set {s_idx} is not an object.")
                        continue
                    reps = set_entry.get("repetitions")
                    dur = set_entry.get("duration_seconds")
                    if reps is None and dur is None:
                        errors.append(f"Workout exercise '{ex_id}' set {s_idx} must specify repetitions or duration_seconds.")

    return len(errors) == 0, errors
