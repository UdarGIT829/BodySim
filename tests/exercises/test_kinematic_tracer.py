"""Kinematic tracer v3 rules, using the real v2 muscle-action table."""

import pytest

from tools.exercises.kinematic_tracer import (
    ASSIST_SCALE, PRIMARY_THRESHOLD, STABILIZER_SCALE, TRACER_VERSION, load_inputs, trace_exercise_kinematics)
from pathlib import Path

IDS, ACTIONS, _ = load_inputs()


def trace(actions, demands=(), laterality="bilateral", one_sided_limbs=None):
    """actions: (joint, movement) or (joint, movement, {"emphasis"/"sides": ...})."""
    profile = {"primary_joint_actions": [{"joint": a[0], "movement": a[1], **(a[2] if len(a) > 2 else {})} for a in actions],
               "stabilization_demands": list(demands)}
    if one_sided_limbs is not None:
        profile["one_sided_limbs"] = one_sided_limbs
    exercise = {"laterality": laterality, "kinematic_profile": profile}
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
    assert "rule.kinematic_tracer_v3.non_working_side" in " ".join(
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


# ── Tracer v3 ───────────────────────────────────────────────────────────────

def test_assist_actions_never_make_a_primary_mover():
    squat = [("knee_joint", "extension"), ("ankle_joint", "plantarflexion", {"emphasis": "assist"})]
    profile = trace(squat)
    soleus = profile["muscle.soleus.left"]
    assert soleus["role"] == "synergist" and soleus["coefficient"] <= ASSIST_SCALE < PRIMARY_THRESHOLD
    assert "rule.kinematic_tracer_v3.assist" in soleus["evidence_refs"]
    assert profile["muscle.vastus_lateralis.left"]["role"] == "primary"     # primary actions are unaffected
    # A muscle reached by both a primary and an assisted action keeps its primary score.
    both = trace([("knee_joint", "flexion"), ("hip_joint", "extension", {"emphasis": "assist"})])
    assert both["muscle.semitendinosus.left"]["role"] == "primary"


def test_one_arm_push_up_leaves_the_free_arm_unloaded():
    push_up = [("elbow_joint", "extension"), ("glenohumeral_joint", "horizontal_adduction")]
    demands = ["wrist_stability", "glenohumeral_stabilization", "scapular_stabilization", "anti_rotation_torso"]
    profile = trace(push_up, demands, laterality="unilateral")          # one_sided_limbs inferred: arm
    for muscle in ("infraspinatus", "extensor_carpi_radialis_brevis", "rhomboid_major"):
        assert profile[f"muscle.{muscle}.right"]["role"] != "none", muscle
        assert profile[f"muscle.{muscle}.left"]["role"] == "none", muscle
    assert profile["muscle.external_abdominal_oblique.left"]["role"] == "stabilizer"   # trunk braces both sides


def test_windmill_hinges_both_hips_with_the_load_in_one_hand():
    windmill = [("hip_joint", "extension", {"sides": "both"}), ("lumbar_spine", "lateral_flexion")]
    profile = trace(windmill, ["grip", "knee_joint_stability"], laterality="unilateral", one_sided_limbs=["arm"])
    assert profile["muscle.gluteus_maximus.left"]["role"] == profile["muscle.gluteus_maximus.right"]["role"] == "primary"
    assert profile["muscle.flexor_digitorum_profundus.right"]["role"] == "stabilizer"
    assert profile["muscle.flexor_digitorum_profundus.left"]["role"] == "none"
    assert profile["muscle.vastus_medialis.left"]["role"] == profile["muscle.vastus_medialis.right"]["role"] == "stabilizer"


def test_one_sided_limbs_inference_and_overrides():
    from tools.exercises.kinematic_tracer import one_sided_limbs
    assert one_sided_limbs({"primary_joint_actions": [{"joint": "elbow_joint"}]}) == {"arm"}
    assert one_sided_limbs({"primary_joint_actions": [{"joint": "knee_joint"}, {"joint": "lumbar_spine"}]}) == {"leg"}
    assert one_sided_limbs({"primary_joint_actions": [{"joint": "hip_joint", "sides": "both"}]}) == {"arm", "leg"}
    assert one_sided_limbs({"one_sided_limbs": [], "primary_joint_actions": [{"joint": "elbow_joint"}]}) == set()
    # An explicit [] keeps every demand on both sides.
    profile = trace(CURL, ["grip"], laterality="unilateral", one_sided_limbs=[])
    assert profile["muscle.flexor_digitorum_profundus.left"]["role"] == "stabilizer"


def test_bilateral_exercises_ignore_sides_and_one_sided_limbs():
    plain = trace(CURL, ["grip"])
    marked = trace([("elbow_joint", "flexion", {"sides": "both"})], ["grip"], one_sided_limbs=["arm"])
    assert {k: (v["role"], v["coefficient"]) for k, v in plain.items()} == {k: (v["role"], v["coefficient"]) for k, v in marked.items()}


def test_godot_pipeline_knows_the_current_tracer_version():
    gd = (Path(__file__).resolve().parents[2] / "src/exercises/auto/auto_pipeline.gd").read_text()
    assert f'const CURRENT_TRACER := "{TRACER_VERSION}"' in gd
