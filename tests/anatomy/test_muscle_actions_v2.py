"""Rule checks for the v2 muscle-action table and its review groups."""

import copy
import json

import pytest

from src.anatomy import muscle_actions_v2 as table


def _doc(group, entries):
    return {"format_version": 2, "group": group, "entries": entries}


def _entry(base_id, **overrides):
    entry = {"base_id": base_id, "movement_muscle": True, "status": "draft", "confidence": "high",
             "rationale": "test", "actions": [], "stabilizes": []}
    entry.update(overrides)
    return entry


def _full_arm(**changes):
    entries = [_entry(m["base_id"]) for m in table.group_muscles()["arm"]]
    return _doc("arm", entries)


def test_every_muscle_is_in_exactly_one_group():
    groups = table.group_muscles()
    ids = [m for g in groups.values() for b in g for m in b["muscle_ids"]]
    assert len(ids) == 466 and len(set(ids)) == 466
    assert sum(len(g) for g in groups.values()) == 234
    assert set(groups) == set(table.GROUP_ORDER) and all(groups.values())


@pytest.mark.parametrize("base,group", [
    ("muscle.lateral_head_of_triceps_brachii", "arm"),         # filed under head_neck in structures.json
    ("muscle.brachioradialis", "forearm"),
    ("muscle.acromial_part_of_deltoid", "shoulder_girdle"),
    ("muscle.descending_part_of_trapezius", "shoulder_girdle"),
    ("muscle.rectus_abdominis", "abdomen"),
    ("muscle.zygomaticus_major", "head"),
    ("muscle.ary_epiglottic_part_of_oblique_arytenoid", "neck"),
])
def test_known_muscles_land_in_the_right_group(base, group):
    found = {m["base_id"]: g for g, ms in table.group_muscles().items() for m in ms}
    assert found[base] == group


def test_left_and_right_share_one_entry():
    arm = {m["base_id"]: m for m in table.group_muscles()["arm"]}
    assert arm["muscle.brachialis"]["muscle_ids"] == ["muscle.brachialis.left", "muscle.brachialis.right"]


def test_drafting_schema_matches_vocabulary_and_api_subset():
    vocab = table.load_vocabulary()
    schema = table.drafting_schema(vocab)
    text = json.dumps(schema)
    for unsupported in ("minimum", "maximum", "minLength", "maxLength", "pattern"):
        assert f'"{unsupported}"' not in text
    alternatives = schema["properties"]["entries"]["items"]["properties"]["actions"]["items"]["anyOf"]
    assert {a["properties"]["joint"]["enum"][0] for a in alternatives} == set(vocab["joints"])


def test_valid_group_passes():
    assert table.validate_group("arm", _full_arm()) == []


def test_missing_and_foreign_muscles_are_reported():
    doc = _full_arm()
    doc["entries"].pop()
    doc["entries"].append(_entry("muscle.zygomaticus_major"))
    problems = " ".join(table.validate_group("arm", doc))
    assert "missing muscles" in problems and "not a muscle of this group" in problems


def test_non_movement_muscle_cannot_act_or_stabilize():
    doc = _full_arm()
    doc["entries"][0].update(movement_muscle=False,
                             stabilizes=[{"demand": "postural_stabilization", "weight": 0.2}])
    assert any("non-movement" in p for p in table.validate_group("arm", doc))


@pytest.mark.parametrize("action,needle", [
    ({"joint": "elbow_joint", "movement": "abduction", "weight": 0.5}, "unknown action"),
    ({"joint": "elbow_joint", "movement": "flexion", "weight": 0.05}, "weight"),
    ({"joint": "elbow_joint", "movement": "flexion", "weight": 1.5}, "weight"),
])
def test_bad_actions_are_reported(action, needle):
    doc = _full_arm()
    doc["entries"][0]["actions"] = [action]
    assert any(needle in p for p in table.validate_group("arm", doc))


def test_duplicate_action_is_reported():
    doc = _full_arm()
    a = {"joint": "elbow_joint", "movement": "flexion", "weight": 1.0}
    doc["entries"][0]["actions"] = [a, copy.deepcopy(a)]
    assert any("listed twice" in p for p in table.validate_group("arm", doc))


def test_committed_group_files_pass_rule_checks():
    for group in table.GROUP_ORDER:
        path = table.TABLE_DIR / f"{group}.json"
        if path.exists():
            assert table.validate_group(group, json.loads(path.read_text())) == [], group
