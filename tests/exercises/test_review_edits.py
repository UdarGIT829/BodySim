"""Council-proposed edits: applied deterministically, re-traced by the real
candidate gate, saved as a new draft (in a temporary root)."""

import json
from pathlib import Path

import pytest

from src.exercises.promotion import REL_REVIEWS, REL_REVISIONS
from src.exercises.review_edits import REL_DRAFTS, EditError, apply_edits, apply_to_revision

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = json.loads((ROOT / "tests/fixtures/promotion_draft.json").read_text())
HASH = "e" * 64


def definition():
    d = json.loads(json.dumps(FIXTURE["authoring_response"]["proposed_definition"]))
    d["id"] = "exercise.edit_fixture.standard"
    return d


def test_every_operation_applies():
    d = definition()
    original = json.loads(json.dumps(d))
    first = d["kinematic_profile"]["primary_joint_actions"][0]
    edits = [
        {"op": "set_kinetic_chain_type", "value": "closed_chain"},
        {"op": "set_laterality", "value": "unilateral"},
        {"op": "set_movement_families", "value": ["elbow_flexion", "wrist_and_grip", "elbow_flexion"]},
        {"op": "set_one_sided_limbs", "value": ["arm"]},
        {"op": "add_joint_action", "joint": "radioulnar_joint", "movement": "supination", "emphasis": "assist", "sides": "working"},
        {"op": "set_action_emphasis", "joint": first["joint"], "movement": first["movement"], "emphasis": "assist"},
        {"op": "set_action_sides", "joint": first["joint"], "movement": first["movement"], "sides": "both"},
        {"op": "add_stabilization_demand", "demand": "grip"},
    ]
    edited, described = apply_edits(d, edits)
    p = edited["kinematic_profile"]
    assert p["kinetic_chain_type"] == "closed_chain" and edited["laterality"] == "unilateral"
    assert edited["movement_families"] == ["elbow_flexion", "wrist_and_grip"]          # deduplicated, order kept
    assert p["one_sided_limbs"] == ["arm"]
    assert {"joint": "radioulnar_joint", "movement": "supination", "emphasis": "assist", "sides": "working"} in p["primary_joint_actions"]
    assert p["primary_joint_actions"][0]["emphasis"] == "assist" and p["primary_joint_actions"][0]["sides"] == "both"
    assert "grip" in p["stabilization_demands"]
    assert len(described) == len(edits)
    assert d == original                                                              # the input isn't modified


def test_removals_and_refusals():
    d = definition()
    first = d["kinematic_profile"]["primary_joint_actions"][0]
    demand = d["kinematic_profile"]["stabilization_demands"][0]
    edited, _ = apply_edits(d, [{"op": "remove_stabilization_demand", "demand": demand}])
    assert demand not in edited["kinematic_profile"]["stabilization_demands"]
    with pytest.raises(EditError, match="not in the definition"):
        apply_edits(d, [{"op": "remove_stabilization_demand", "demand": "neck_brace"}])
    with pytest.raises(EditError, match="not a joint action"):
        apply_edits(d, [{"op": "add_joint_action", "joint": "elbow_joint", "movement": "plantarflexion", "emphasis": "primary", "sides": "working"}])
    with pytest.raises(EditError, match="no joint actions"):
        apply_edits(d, [{"op": "remove_joint_action", "joint": a["joint"], "movement": a["movement"]}
                        for a in d["kinematic_profile"]["primary_joint_actions"]])
    with pytest.raises(EditError, match="no edits"):
        apply_edits(d, [])
    assert first == d["kinematic_profile"]["primary_joint_actions"][0]


def _sandbox(tmp_path, votes):
    for rel in (REL_REVISIONS, REL_REVIEWS, REL_DRAFTS):
        (tmp_path / rel).mkdir(parents=True)
    revision = {"revision_sha256": HASH, "source_id": "Edit_Fixture", "catalog_id": "catalog.x", "source_snapshot_sha256": "s",
                "additional_context": "owner note", "authoring_response": {**FIXTURE["authoring_response"], "proposed_definition": definition()},
                "authoring_provider_metadata": {"provider": "anthropic"}}
    (tmp_path / REL_REVISIONS / f"{HASH}.json").write_text(json.dumps(revision))
    (tmp_path / REL_REVIEWS / f"{HASH}.json").write_text(json.dumps({"revision_sha256": HASH, "status": "changes_requested", "votes": votes}))


def test_rejected_revision_becomes_an_edited_draft(tmp_path):
    vote = {"decision": "reject", "proposed_edits": [{"op": "set_kinetic_chain_type", "value": "closed_chain"}],
            "edits_resolve_all_blocking_findings": True, "provider_metadata": {"model": "claude-sonnet-5-5"}}
    _sandbox(tmp_path, {"human_owner": {"decision": "accept"}, "model_reviewer": vote})
    report = apply_to_revision(HASH, root=tmp_path, now=5.0)
    assert report["ok"], report
    draft = json.loads((tmp_path / REL_DRAFTS / "Edit_Fixture.json").read_text())
    assert draft["status"] == "definition_candidate" and draft["candidate_trace_report"]["ok"]
    assert draft["authoring_response"]["proposed_definition"]["kinematic_profile"]["kinetic_chain_type"] == "closed_chain"
    assert draft["provider_metadata"]["edited_by_council"]["from_revision_sha256"] == HASH
    assert draft["additional_context"] == "owner note" and draft["saved_at_unix"] == 5.0
    assert "Edited by the council" in draft["authoring_response"]["assumptions"][-1]


def test_refuses_when_someone_else_rejected_or_nothing_to_apply(tmp_path):
    vote = {"decision": "reject", "proposed_edits": [{"op": "set_kinetic_chain_type", "value": "closed_chain"}]}
    _sandbox(tmp_path, {"human_owner": {"decision": "reject"}, "model_reviewer": vote})
    assert "human_owner" in apply_to_revision(HASH, root=tmp_path)["errors"][0]
    assert not (tmp_path / REL_DRAFTS / "Edit_Fixture.json").exists()


def test_dry_run_writes_nothing(tmp_path):
    vote = {"decision": "reject", "proposed_edits": [{"op": "set_laterality", "value": "unilateral"}]}
    _sandbox(tmp_path, {"model_reviewer": vote})
    assert apply_to_revision(HASH, root=tmp_path, dry_run=True)["ok"]
    assert not (tmp_path / REL_DRAFTS / "Edit_Fixture.json").exists()
