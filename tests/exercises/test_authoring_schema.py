import json
from pathlib import Path


SCHEMA_PATH = Path("data/exercises/authoring/schemas/kinematic_authoring_response.schema.json")
UNSUPPORTED_STRUCTURED_OUTPUT_KEYWORDS = {
    "uniqueItems",
    "minItems",
    "maxItems",
    "minLength",
    "maxLength",
    "pattern",
    "format",
    "minimum",
    "maximum",
    "multipleOf",
}


def _walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from _walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from _walk(child)


def test_api_schema_uses_structured_outputs_subset():
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    found = {
        keyword
        for node in _walk(schema)
        for keyword in UNSUPPORTED_STRUCTURED_OUTPUT_KEYWORDS.intersection(node)
    }
    assert not found, f"Unsupported structured-output keywords: {sorted(found)}"


def test_every_object_is_closed_and_all_properties_are_required():
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    for node in _walk(schema):
        if node.get("type") != "object":
            continue
        assert node.get("additionalProperties") is False
        assert set(node.get("required", [])) == set(node.get("properties", {}))


def test_joint_action_schema_encodes_only_valid_joint_movement_pairs():
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    definition = schema["properties"]["proposed_definition"]["anyOf"][1]
    action_items = definition["properties"]["kinematic_profile"]["properties"]["primary_joint_actions"]["items"]
    encoded = {
        branch["properties"]["joint"]["enum"][0]: set(branch["properties"]["movement"]["enum"])
        for branch in action_items["anyOf"]
    }
    vocabulary = json.loads((Path(__file__).resolve().parents[2] / "data/anatomy/joint_action_vocabulary.json").read_text())
    for joint, movements in encoded.items():
        assert movements <= set(vocabulary["joints"][joint]), joint
    assert "rotation" not in encoded["scapulothoracic_joint"]          # only up/downward rotation exist
    assert "horizontal_abduction" in encoded["glenohumeral_joint"]


def test_schema_and_validators_are_in_sync_with_the_muscle_action_table():
    import subprocess, sys
    root = Path(__file__).resolve().parents[2]
    result = subprocess.run([sys.executable, str(root / "tools/anatomy/sync_vocabulary.py"), "--check"],
                            capture_output=True, text=True, cwd=root)
    assert result.returncode == 0, result.stdout + result.stderr


def test_movement_family_is_structurally_non_empty_without_array_constraints():
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    definition = schema["properties"]["proposed_definition"]["anyOf"][1]
    assert "primary_movement_family" in definition["required"]
    assert definition["properties"]["primary_movement_family"]["type"] == "string"
    assert definition["properties"]["primary_movement_family"]["enum"]
    assert "minItems" not in json.dumps(schema)



def test_joint_actions_carry_the_tracer_v3_fields():
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    profile = schema["properties"]["proposed_definition"]["anyOf"][1]["properties"]["kinematic_profile"]
    for branch in profile["properties"]["primary_joint_actions"]["items"]["anyOf"]:
        assert branch["properties"]["emphasis"]["enum"] == ["primary", "assist"]
        assert branch["properties"]["sides"]["enum"] == ["working", "both"]
    assert profile["properties"]["one_sided_limbs"]["items"]["enum"] == ["arm", "leg"]
    assert "one_sided_limbs" in profile["required"]
