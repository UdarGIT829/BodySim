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


# ── Whole-table sanity (runs once every group is drafted) ───────────────────

def _complete_table():
    records, missing = table.merged_table()
    if missing:
        pytest.skip(f"groups not drafted yet: {', '.join(missing)}")
    return {r["muscle_id"]: r for r in records}


def _weight(record, joint, movement):
    return next((a["weight"] for a in record["actions"] if (a["joint"], a["movement"]) == (joint, movement)), 0.0)


def test_table_covers_all_466_muscles():
    assert len(_complete_table()) == 466


def test_every_action_exercises_can_use_has_a_prime_mover():
    records = _complete_table()
    from tools.anatomy.sync_vocabulary import usable_actions   # the pairs exercises can use
    missing = []
    for joint, movements in usable_actions().items():
        for movement in movements:
            if not any(_weight(r, joint, movement) >= 0.7 for r in records.values()):
                missing.append(f"{joint}/{movement}")
    assert not missing, f"no muscle with weight >= 0.7 for: {missing}"


def test_every_stabilization_demand_has_muscles():
    records = _complete_table()
    used = {s["demand"] for r in records.values() for s in r["stabilizes"]}
    assert set(table.load_vocabulary()["stabilization_demands"]) <= used


def test_head_muscles_never_move_or_stabilize():
    for r in _complete_table().values():
        if r["group"] == "head":
            assert not r["movement_muscle"] and not r["actions"] and not r["stabilizes"], r["muscle_id"]


@pytest.mark.parametrize("fragment", ["arytenoid", "zygomaticus", "lateral_rectus", "levator_palpebrae", "orbicularis", "genioglossus"])
def test_known_non_movement_muscles(fragment):
    hits = [r for m, r in _complete_table().items() if fragment in m]
    for r in hits:
        assert not r["actions"] and not r["stabilizes"], r["muscle_id"]


def test_postural_stabilization_is_limited_to_antigravity_regions():
    allowed = {"back", "abdomen", "hip_and_thigh", "leg", "pelvis", "thorax"}
    offenders = [m for m, r in _complete_table().items()
                 if any(s["demand"] == "postural_stabilization" for s in r["stabilizes"]) and r["group"] not in allowed]
    assert not offenders, offenders


def test_council_flagged_errors_are_fixed():
    t = _complete_table()
    assert _weight(t["muscle.coracobrachialis.left"], "elbow_joint", "flexion") == 0.0
    assert _weight(t["muscle.brachioradialis.left"], "elbow_joint", "flexion") >= 0.3
    assert _weight(t["muscle.brachialis.left"], "elbow_joint", "flexion") >= 0.7
    assert _weight(t["muscle.scapular_spinal_part_of_deltoid.left"], "glenohumeral_joint", "abduction") < 0.3
    assert _weight(t["muscle.long_head_of_triceps_brachii.left"], "glenohumeral_joint", "extension") > 0.0
    assert _weight(t["muscle.lateral_head_of_triceps_brachii.left"], "glenohumeral_joint", "extension") == 0.0
    tva = t["muscle.transversus_abdominis.left"]
    assert any(s["demand"] == "intra_abdominal_pressure" for s in tva["stabilizes"])


def test_sides_mirror_each_other():
    t = _complete_table()
    for m, r in t.items():
        if m.endswith(".left"):
            other = t[m[:-5] + ".right"]
            assert (r["actions"], r["stabilizes"]) == (other["actions"], other["stabilizes"]), m
