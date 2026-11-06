"""
Pytest validation tests for Phase 1A exercise schemas, muscle action matrix, crosswalk, and fixtures.
"""

import json
from pathlib import Path
import pytest

from src.exercises.schemas import (
    load_canonical_muscle_ids,
    validate_muscle_actions,
    validate_exercises,
    validate_engagement_profiles,
    validate_opensim_calibration,
    validate_crosswalk,
    validate_workout,
)


@pytest.fixture(scope="module")
def canonical_muscle_ids():
    return load_canonical_muscle_ids("data/anatomy/structures.json")


def test_canonical_muscle_ids_count(canonical_muscle_ids):
    assert len(canonical_muscle_ids) == 466
    assert "muscle.rectus_femoris.left" in canonical_muscle_ids
    assert "muscle.latissimus_dorsi.right" in canonical_muscle_ids


def test_muscle_actions_file_validity(canonical_muscle_ids):
    actions_file = Path("data/anatomy/muscle_actions.json")
    assert actions_file.is_file()

    with open(actions_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_valid, errors = validate_muscle_actions(data, canonical_muscle_ids)
    assert is_valid, f"Muscle actions validation failed: {errors}"
    assert len(data) == 466


def test_exercises_file_validity():
    exercises_file = Path("data/exercises/exercises.json")
    assert exercises_file.is_file()

    with open(exercises_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_valid, errors = validate_exercises(data)
    assert is_valid, f"Exercises validation failed: {errors}"
    assert len(data) >= 4


def test_crosswalk_file_validity():
    crosswalk_file = Path("data/exercises/sources/crosswalk.json")
    assert crosswalk_file.is_file()

    with open(crosswalk_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_valid, errors = validate_crosswalk(data)
    assert is_valid, f"Crosswalk validation failed: {errors}"
    assert len(data) == 873


def test_opensim_calibration_file_validity(canonical_muscle_ids):
    calib_file = Path("data/exercises/opensim_calibration.json")
    assert calib_file.is_file()

    with open(calib_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_valid, errors = validate_opensim_calibration(data, canonical_muscle_ids)
    assert is_valid, f"OpenSim calibration validation failed: {errors}"


def test_example_workout_file_validity():
    workout_file = Path("data/workouts/example_workout.json")
    assert workout_file.is_file()

    with open(workout_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    is_valid, errors = validate_workout(data)
    assert is_valid, f"Workout validation failed: {errors}"


def test_invalid_exercise_id_rejected():
    invalid_data = [
        {
            "id": "invalid_prefix_squat",
            "name": "Invalid Squat",
            "variant": "Standard",
            "laterality": "bilateral",
            "input_mode": "repetitions",
            "kinematic_profile": {
                "kinetic_chain_type": "closed_chain",
                "primary_joint_actions": [{"joint": "knee_joint", "movement": "extension"}],
                "stabilization_demands": []
            }
        }
    ]
    is_valid, errors = validate_exercises(invalid_data)
    assert not is_valid
    assert any("must start with 'exercise.'" in e for e in errors)


def test_new_exercise_does_not_require_deprecated_load_vector():
    exercise = {
        "id": "exercise.test_press.standard",
        "name": "Test Press",
        "variant": "Standard",
        "aliases": [],
        "movement_families": ["vertical_push"],
        "laterality": "bilateral",
        "input_mode": "repetitions",
        "kinematic_profile": {
            "kinetic_chain_type": "open_chain",
            "primary_joint_actions": [
                {"joint": "glenohumeral_joint", "movement": "flexion"}
            ],
            "stabilization_demands": ["glenohumeral_stabilization"],
        },
    }
    is_valid, errors = validate_exercises([exercise])
    assert is_valid, errors
