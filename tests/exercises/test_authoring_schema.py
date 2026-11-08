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


def test_joint_action_schema_lists_only_vocabulary_joints_and_movements():
    """Actions are one flat object (a per-joint branch made the compiled
    grammar too large for the API); valid pairs are enforced in code, by the
    GDScript validators' JOINT_ACTIONS, generated from the same vocabulary."""
    from tools.anatomy.sync_vocabulary import usable_actions
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    definition = schema["properties"]["proposed_definition"]["anyOf"][1]
    item = definition["properties"]["kinematic_profile"]["properties"]["primary_joint_actions"]["items"]
    pairs = usable_actions()
    assert item["properties"]["joint"]["enum"] == list(pairs)
    assert set(item["properties"]["movement"]["enum"]) == {m for ms in pairs.values() for m in ms}
    assert "rotation" not in pairs["scapulothoracic_joint"]            # only up/downward rotation exist
    assert "horizontal_abduction" in pairs["glenohumeral_joint"]
    validators = (Path(__file__).resolve().parents[2] / "src/exercises/authoring/candidate_validators.gd").read_text()
    for joint, movements in pairs.items():
        assert f'"{joint}": {json.dumps(sorted(movements))}' in validators, joint


def test_schemas_stay_small_enough_for_structured_outputs():
    """A tripwire: the API rejects schemas whose compiled grammar is too large
    (the authoring schema hit it at ~29 KB with per-joint action branches). Both schemas
    compiled at their current sizes; keep them well below that."""
    root = Path(__file__).resolve().parents[2] / "data/exercises/authoring/schemas"
    assert len((root / "kinematic_authoring_response.schema.json").read_bytes()) < 15000
    assert len((root / "kinematic_review_response.schema.json").read_bytes()) < 20000


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
    item = profile["properties"]["primary_joint_actions"]["items"]
    assert item["properties"]["emphasis"]["enum"] == ["primary", "assist"]
    assert item["properties"]["sides"]["enum"] == ["working", "both"]
    assert profile["properties"]["one_sided_limbs"]["items"]["enum"] == ["arm", "leg"]
    assert "one_sided_limbs" in profile["required"]


def test_movement_families_come_from_the_vocabulary():
    root = Path(__file__).resolve().parents[2]
    vocabulary = list(json.loads((root / "data/anatomy/joint_action_vocabulary.json").read_text())["movement_families"])
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    definition = schema["properties"]["proposed_definition"]["anyOf"][1]["properties"]
    assert definition["primary_movement_family"]["enum"] == vocabulary
    assert definition["additional_movement_families"]["items"]["enum"] == vocabulary
    for gd, const in (("src/exercises/authoring/candidate_validators.gd", "MOVEMENT_FAMILIES"),
                      ("src/exercises/exercise_selector.gd", "FAMILY_ORDER")):
        text = (root / gd).read_text()
        block = text[text.index(f"const {const} := ["):]
        block = block[:block.index("]") + 1]
        assert all(f'"{family}"' in block for family in vocabulary), (gd, const)
    # Every canonical exercise uses known families.
    for exercise in json.loads((root / "data/exercises/exercises.json").read_text()):
        assert set(exercise["movement_families"]) <= set(vocabulary), exercise["id"]
