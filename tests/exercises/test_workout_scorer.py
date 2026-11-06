"""
Pytest unit tests for WorkoutScorer engine and golden-file summary checks.
"""

import json
from pathlib import Path
import pytest

from src.exercises.workout_scorer import WorkoutScorer, calculate_effort_factor


def test_calculate_effort_factor():
    set_rpe8 = {"repetitions": 10, "rpe": 8.0}
    assert calculate_effort_factor(set_rpe8) == 10.0

    set_rpe10 = {"repetitions": 10, "rpe": 10.0}
    assert calculate_effort_factor(set_rpe10) == 12.0

    set_duration = {"duration_seconds": 30, "rpe": 8.0}
    assert calculate_effort_factor(set_duration) == 6.0


def test_workout_scorer_execution():
    scorer = WorkoutScorer(
        catalog_path="data/anatomy/structures.json",
        profiles_path="data/exercises/engagement_profiles.json",
        opensim_path="data/exercises/opensim_calibration.json"
    )

    with open("data/workouts/example_workout.json", "r", encoding="utf-8") as f:
        workout_data = json.load(f)

    summary = scorer.score_workout(workout_data)

    assert summary["session_id"] == "session_2026_08_10_legs_and_pull"
    assert summary["total_canonical_muscles"] == 466
    assert summary["active_muscles"] > 0
    assert summary["zero_exposure_muscles"] + summary["active_muscles"] == 466

    # Verify rectus femoris received exposure from squat
    rectus_fem = summary["muscles"]["muscle.rectus_femoris.left"]
    assert rectus_fem["raw_exposure"] > 0
    assert rectus_fem["opensim_estimated_force_n"] > 0
    assert len(rectus_fem["contributions"]) > 0

    # Verify latissimus dorsi received exposure from pull-up
    lat_left = summary["muscles"]["muscle.latissimus_dorsi.left"]
    assert lat_left["raw_exposure"] > 0
    assert lat_left["opensim_estimated_force_n"] > 0

    # Save summary output report for inspection
    report_file = Path("reports/example_workout_summary.json")
    report_file.parent.mkdir(parents=True, exist_ok=True)
    with open(report_file, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    assert report_file.is_file()
