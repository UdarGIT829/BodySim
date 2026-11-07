import json
from pathlib import Path

from src.exercises.candidate_gate import evaluate_candidate


def candidate_definition():
    return {
        "id": "exercise.phase2c_test.standard",
        "name": "Phase 2C Test Squat",
        "variant": "Standard",
        "aliases": ["phase 2c squat"],
        "movement_families": ["squat"],
        "laterality": "bilateral",
        "input_mode": "repetitions",
        "kinematic_profile": {
            "kinetic_chain_type": "closed_chain",
            "primary_joint_actions": [
                {"joint": "hip_joint", "movement": "extension"},
                {"joint": "knee_joint", "movement": "extension"},
            ],
            "stabilization_demands": ["anti_flexion_spine"],
        },
    }


def test_candidate_gate_generates_complete_isolated_profile():
    result = evaluate_candidate(candidate_definition())
    assert result["ok"], result["errors"]
    assert result["gate_version"] == "candidate_trace_gate_v3"
    assert result["provenance"]["tracer"] == "kinematic_tracer_v3"
    assert result["summary"]["total_muscles"] == 466
    assert result["summary"]["mapped_muscles"] > 0
    assert result["summary"]["zero_muscles"] + result["summary"]["mapped_muscles"] == 466
    assert len(result["profile"]["muscles"]) == 466
    assert all(item["matching_muscles"] > 0 for item in result["summary"]["joint_action_coverage"])


def test_candidate_gate_rejects_unmapped_joint_action():
    definition = candidate_definition()
    definition["kinematic_profile"]["primary_joint_actions"] = [
        {"joint": "imaginary_joint", "movement": "extension"}
    ]
    result = evaluate_candidate(definition)
    assert not result["ok"]
    assert any("maps to no canonical muscles" in error for error in result["errors"])


def test_candidate_gate_rejects_canonical_id_collision():
    definition = candidate_definition()
    definition["id"] = "exercise.push_up.standard"
    result = evaluate_candidate(definition)
    assert not result["ok"]
    assert any("already exists" in error for error in result["errors"])


def test_candidate_gate_does_not_mutate_canonical_outputs():
    exercises_path = Path("data/exercises/exercises.json")
    profiles_path = Path("data/exercises/engagement_profiles.json")
    before_exercises = exercises_path.read_bytes()
    before_profiles = profiles_path.read_bytes()
    evaluate_candidate(candidate_definition())
    assert exercises_path.read_bytes() == before_exercises
    assert profiles_path.read_bytes() == before_profiles


def test_candidate_gate_cli_writes_machine_readable_report(tmp_path):
    input_path = tmp_path / "candidate.json"
    output_path = tmp_path / "report.json"
    input_path.write_text(json.dumps(candidate_definition()), encoding="utf-8")

    import subprocess
    completed = subprocess.run(
        [
            "python3",
            "tools/exercises/run_candidate_gate.py",
            "--input",
            str(input_path),
            "--output",
            str(output_path),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    assert completed.returncode == 0, completed.stderr
    report = json.loads(output_path.read_text(encoding="utf-8"))
    assert report["ok"]
    assert report["summary"]["total_muscles"] == 466



def test_gate_checks_the_tracer_v3_fields():
    definition = candidate_definition()
    definition["kinematic_profile"]["primary_joint_actions"][0].update({"emphasis": "assist", "sides": "both"})
    definition["kinematic_profile"]["one_sided_limbs"] = ["arm"]
    assert evaluate_candidate(definition)["ok"]
    definition["kinematic_profile"]["primary_joint_actions"][0]["emphasis"] = "huge"
    definition["kinematic_profile"]["one_sided_limbs"] = ["arm", "arm"]
    errors = " ".join(evaluate_candidate(definition)["errors"])
    assert "emphasis" in errors and "one_sided_limbs" in errors
