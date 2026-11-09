"""The web build's compact engagement profiles expand back exactly."""

import json

import pytest

from tools.web.compact_profiles import FORMAT, compact, expand


def _profile(ids, nonzero):
    muscles = []
    for i, muscle_id in enumerate(ids):
        if i in nonzero:
            muscles.append({"muscle_id": muscle_id, "role": "primary", "coefficient": 0.8, "confidence": "high",
                            "evidence_status": "kinematic_trace", "derivation_method": "kinematic_tracer_v3",
                            "evidence_refs": ["muscle_actions_v2:x", "rule.kinematic_tracer_v3.primary"]})
        else:
            muscles.append({"muscle_id": muscle_id, "role": "none", "coefficient": 0.0, "confidence": "high",
                            "evidence_status": "reviewed_zero", "derivation_method": "kinematic_tracer_v3",
                            "evidence_refs": ["rule.kinematic_tracer_v3.reviewed_zero"]})
    return {"exercise_id": "x", "total_muscles": len(ids), "mapped_muscles": len(nonzero), "muscles": muscles}


def test_round_trip_is_exact_and_much_smaller():
    ids = [f"muscle.m{i}" for i in range(466)]
    full = {"profiles": {"exercise.a.b": _profile(ids, {3, 7}),
                         "exercise.c.d": {**_profile(ids, {1}), "promotion": {"revision_sha256": "f" * 64}}}}
    full["profiles"]["exercise.c.d"]["muscles"][5]["confidence"] = "low"     # a zero that differs from the template
    data = compact(json.loads(json.dumps(full)))
    assert data["format"] == FORMAT and data["muscle_ids"] == ids
    assert expand(data) == full
    assert len(data["profiles"]["exercise.c.d"]["entries"]) == 2              # the nonzero entry and the odd zero
    assert len(json.dumps(data, separators=(",", ":"))) < len(json.dumps(full, indent=2)) / 10


def test_refuses_profiles_in_a_different_muscle_order():
    ids = [f"muscle.m{i}" for i in range(4)]
    full = {"profiles": {"a": _profile(ids, {0}), "b": _profile(list(reversed(ids)), {0})}}
    with pytest.raises(SystemExit):
        compact(full)
