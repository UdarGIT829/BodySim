"""Kinematic tracer v2 rules, using the real v2 muscle-action table."""

import pytest

from tools.exercises.kinematic_tracer import (
    PRIMARY_THRESHOLD, STABILIZER_SCALE, TRACER_VERSION, load_inputs, trace_exercise_kinematics)

IDS, ACTIONS, _ = load_inputs()


def trace(actions, demands=(), laterality="bilateral"):
    exercise = {"laterality": laterality, "kinematic_profile": {
        "primary_joint_actions": [{"joint": j, "movement": m} for j, m in actions],
        "stabilization_demands": list(demands)}}
    return {e["muscle_id"]: e for e in trace_exercise_kinematics(exercise, IDS, ACTIONS)}


CURL = [("elbow_joint", "flexion")]


def test_every_muscle_gets_exactly_one_entry():
    profile = trace(CURL)
    assert len(profile) == 466
    assert all(e["derivation_method"] == TRACER_VERSION for e in profile.values())


def test_roles_follow_table_weights():
    profile = trace(CURL)
    for muscle_id, entry in profile.items():
        weight = max((a["weight"] for a in ACTIONS[muscle_id]["actions"]
                      if (a["joint"], a["movement"]) == CURL[0]), default=0.0) if muscle_id in ACTIONS else 0.0
        if weight >= PRIMARY_THRESHOLD:
            assert entry["role"] == "primary" and entry["coefficient"] == pytest.approx(weight)
        elif weight > 0:
            assert entry["role"] == "synergist" and entry["coefficient"] == pytest.approx(weight)
    assert profile["muscle.brachialis.left"]["role"] == "primary"
    assert profile["muscle.coracobrachialis.left"]["role"] == "none"


def test_stabilizers_are_scaled_and_only_when_not_moving():
    profile = trace(CURL, demands=["intra_abdominal_pressure"])
    tva = profile["muscle.transversus_abdominis.left"]
    assert tva["role"] == "stabilizer"
    assert 0 < tva["coefficient"] <= STABILIZER_SCALE


def test_non_movement_muscles_stay_zero_even_with_postural_demand():
    profile = trace(CURL, demands=["postural_stabilization", "anti_rotation_torso"])
    for muscle_id, entry in profile.items():
        if muscle_id in ACTIONS and not ACTIONS[muscle_id]["movement_muscle"]:
            assert entry["role"] == "none" and entry["coefficient"] == 0, muscle_id
    assert profile["muscle.zygomaticus_major.left"]["role"] == "none"


def test_bilateral_engages_both_arms():
    profile = trace(CURL)
    assert profile["muscle.brachialis.left"]["role"] == profile["muscle.brachialis.right"]["role"] == "primary"


@pytest.mark.parametrize("laterality,working,resting", [("unilateral", "right", "left"), ("left", "left", "right")])
def test_one_sided_exercises_only_move_the_working_limb(laterality, working, resting):
    profile = trace(CURL, demands=["elbow_stability"], laterality=laterality)
    assert profile[f"muscle.brachialis.{working}"]["role"] == "primary"
    assert profile[f"muscle.brachialis.{resting}"]["role"] in ("none", "stabilizer")
    assert "rule.kinematic_tracer_v2.non_working_side" in " ".join(
        profile[f"muscle.brachialis.{resting}"]["evidence_refs"]) or profile[f"muscle.brachialis.{resting}"]["role"] == "none"


def test_trunk_braces_on_both_sides_in_one_sided_exercises():
    profile = trace(CURL, demands=["anti_rotation_torso"], laterality="unilateral")
    left = profile["muscle.external_abdominal_oblique.left"]["role"]
    right = profile["muscle.external_abdominal_oblique.right"]["role"]
    assert left == right != "none"


def test_trunk_based_arm_movers_follow_the_working_side():
    # Pectoralis major lies on the thorax but moves the arm (horizontal adduction).
    profile = trace([("glenohumeral_joint", "horizontal_adduction")], laterality="unilateral")
    assert profile["muscle.sternocostal_head_of_pectoralis_major.right"]["role"] == "primary"
    assert profile["muscle.sternocostal_head_of_pectoralis_major.left"]["role"] == "none"


def test_spinal_actions_count_on_both_sides_when_one_sided():
    profile = trace([("lumbar_spine", "flexion")], laterality="unilateral")
    assert profile["muscle.rectus_abdominis.left"]["role"] == profile["muscle.rectus_abdominis.right"]["role"] == "primary"
