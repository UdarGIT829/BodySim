"""Phase 2E promotion tests.

Each test promotes inside a temporary copy of the canonical data files, using
a frozen authoring draft (tests/fixtures/promotion_draft.json) and the real
candidate gate, so nothing under data/ in the working tree is modified. The
draft is re-keyed to the first unpromoted catalog source under a fixture-only
exercise ID, so promoting real exercises never breaks these tests.
"""

import json
import shutil
from pathlib import Path

import pytest

from src.exercises import promotion
from src.exercises.candidate_gate import evaluate_candidate
from src.exercises.promotion import PROJECT_ROOT, promote_revision

FIXTURE_DRAFT = PROJECT_ROOT / "tests/fixtures/promotion_draft.json"
CANONICAL = [
    promotion.REL_EXERCISES,
    promotion.REL_PROFILES,
    promotion.REL_CANDIDATES,
    promotion.REL_MEDIA,
    promotion.REL_STRUCTURES,
]
HASH = "a" * 64
EXERCISE_ID = "exercise.promotion_fixture.standing_bilateral"


def _target(candidates: list) -> dict:
    """The catalog source the fixture is promoted as: the first unpromoted,
    non-stretch source in the sandbox's copy of the catalog."""
    return next(c for c in candidates if c["status"] == "catalog_only" and c.get("category") != "stretching")


def _target_catalog_id(root: Path) -> str:
    return json.loads((root / promotion.REL_REVISIONS / f"{HASH}.json").read_text())["catalog_id"]


def _write(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2), encoding="utf-8")


@pytest.fixture
def sandbox(tmp_path: Path) -> Path:
    for rel in CANONICAL:
        (tmp_path / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PROJECT_ROOT / rel, tmp_path / rel)
    draft = json.loads(FIXTURE_DRAFT.read_text(encoding="utf-8"))
    target = _target(json.loads((tmp_path / promotion.REL_CANDIDATES).read_text(encoding="utf-8")))
    draft["authoring_response"]["proposed_definition"]["id"] = EXERCISE_ID
    revision = {
        "format_version": 1,
        "source_id": target["source_id"],
        "catalog_id": target["catalog_id"],
        "source_snapshot_sha256": target["source_snapshot_sha256"],
        "source": {},
        "additional_context": draft.get("additional_context", ""),
        "authoring_response": draft["authoring_response"],
        "authoring_provider_metadata": draft.get("provider_metadata", {}),
        # Trace with the current tracer, as a freshly frozen revision would be.
        "candidate_trace_report": evaluate_candidate(draft["authoring_response"]["proposed_definition"]),
        "revision_sha256": HASH,
        "revision_id": f"{target['source_id']}@{HASH[:12]}",
        "status": "review_pending",
    }
    _write(tmp_path / promotion.REL_REVISIONS / f"{HASH}.json", revision)
    _write(tmp_path / promotion.REL_REVIEWS / f"{HASH}.json", {
        "format_version": 1,
        "revision_sha256": HASH,
        "status": "accepted",
        "votes": {
            "human_owner": {"decision": "accept", "summary": "ok"},
            "model_reviewer": {"decision": "accept", "summary": "ok",
                                "provider_metadata": {"provider": "anthropic", "model": "claude-opus-5-5"}},
        },
    })
    return tmp_path


def _snapshot(root: Path) -> dict:
    return {rel: (root / rel).read_bytes() for rel in CANONICAL}


def _set_vote(root: Path, member: str, decision: str) -> None:
    path = root / promotion.REL_REVIEWS / f"{HASH}.json"
    review = json.loads(path.read_text())
    review["votes"][member]["decision"] = decision
    path.write_text(json.dumps(review))


def test_promotes_accepted_revision(sandbox):
    before = len(json.loads((sandbox / promotion.REL_EXERCISES).read_text()))
    report = promote_revision(HASH, root=sandbox, now=1_800_000_000)
    assert report["ok"], report
    assert report["exercise_id"] == EXERCISE_ID

    exercises = json.loads((sandbox / promotion.REL_EXERCISES).read_text())
    assert exercises[-1]["id"] == EXERCISE_ID and len(exercises) == before + 1
    profile = json.loads((sandbox / promotion.REL_PROFILES).read_text())["profiles"][EXERCISE_ID]
    assert len(profile["muscles"]) == 466
    assert profile["profile_version"] == 1
    assert profile["promotion"]["revision_sha256"] == HASH
    candidate = next(c for c in json.loads((sandbox / promotion.REL_CANDIDATES).read_text())
                     if c["catalog_id"] == _target_catalog_id(sandbox))
    assert candidate["status"] == "promoted"
    assert candidate["body_sim_exercise_ids"] == [EXERCISE_ID]
    assert candidate["promotions"][0]["review_models"]["model_reviewer"] == {"provider": "anthropic", "model": "claude-opus-5-5"}
    media = json.loads((sandbox / promotion.REL_MEDIA).read_text())
    assert any(m["exercise_id"] == EXERCISE_ID for m in media)
    assert (sandbox / promotion.REL_PROMOTIONS / f"{HASH}.json").exists()


def test_only_the_new_exercise_is_added_to_hand_formatted_catalog(sandbox):
    before = (sandbox / promotion.REL_EXERCISES).read_text()
    assert promote_revision(HASH, root=sandbox)["ok"]
    after = (sandbox / promotion.REL_EXERCISES).read_text()
    assert after.startswith(before.rstrip()[:-1].rstrip())   # existing text untouched
    assert '"aliases": ["barbell_curl", "standing_barbell_curl", "straight_barbell_curl"]' in after


def test_secrets_and_raw_responses_are_not_copied_into_the_catalog(sandbox):
    assert promote_revision(HASH, root=sandbox)["ok"]
    text = (sandbox / promotion.REL_CANDIDATES).read_text()
    assert "raw_authoring_response" not in text and "input_contact_sheet" not in text


def test_promoting_twice_is_idempotent(sandbox):
    assert promote_revision(HASH, root=sandbox)["ok"]
    before = _snapshot(sandbox)
    again = promote_revision(HASH, root=sandbox)
    assert again["ok"] and again["already_promoted"]
    assert _snapshot(sandbox) == before


@pytest.mark.parametrize("member", ["human_owner", "model_reviewer"])
def test_requires_unanimous_accept(sandbox, member):
    _set_vote(sandbox, member, "reject")
    before = _snapshot(sandbox)
    report = promote_revision(HASH, root=sandbox)
    assert not report["ok"] and member in report["errors"][0]
    assert _snapshot(sandbox) == before


def test_missing_vote_blocks_promotion(sandbox):
    path = sandbox / promotion.REL_REVIEWS / f"{HASH}.json"
    review = json.loads(path.read_text())
    del review["votes"]["model_reviewer"]
    path.write_text(json.dumps(review))
    assert not promote_revision(HASH, root=sandbox)["ok"]


def test_votes_for_a_different_revision_are_rejected(sandbox):
    path = sandbox / promotion.REL_REVIEWS / f"{HASH}.json"
    review = json.loads(path.read_text())
    review["revision_sha256"] = "b" * 64
    path.write_text(json.dumps(review))
    report = promote_revision(HASH, root=sandbox)
    assert not report["ok"] and "different revision" in report["errors"][0]


def test_profile_drift_since_review_blocks_promotion(sandbox):
    path = sandbox / promotion.REL_REVISIONS / f"{HASH}.json"
    revision = json.loads(path.read_text())
    entry = next(m for m in revision["candidate_trace_report"]["profile"]["muscles"] if m["role"] == "primary")
    entry["coefficient"] = 0.123
    path.write_text(json.dumps(revision))
    before = _snapshot(sandbox)
    report = promote_revision(HASH, root=sandbox)
    assert not report["ok"] and "different muscle profile" in report["errors"][0]
    assert _snapshot(sandbox) == before


def test_gate_failure_blocks_promotion(sandbox):
    before = _snapshot(sandbox)
    report = promote_revision(HASH, root=sandbox, gate=lambda d: {"ok": False, "errors": ["boom"]})
    assert not report["ok"] and "boom" in report["errors"][0]
    assert _snapshot(sandbox) == before


def test_changed_source_record_blocks_promotion(sandbox):
    path = sandbox / promotion.REL_CANDIDATES
    candidates = json.loads(path.read_text())
    next(c for c in candidates if c["catalog_id"] == _target_catalog_id(sandbox))["source_snapshot_sha256"] = "0" * 64
    path.write_text(json.dumps(candidates, indent=2) + "\n")
    report = promote_revision(HASH, root=sandbox)
    assert not report["ok"] and "source record changed" in report["errors"][0]


def test_dry_run_writes_nothing(sandbox):
    before = _snapshot(sandbox)
    report = promote_revision(HASH, root=sandbox, dry_run=True)
    assert report["ok"] and report["dry_run"]
    assert _snapshot(sandbox) == before
    assert not (sandbox / promotion.REL_PROMOTIONS).exists()


def test_failed_rename_rolls_back_every_file(sandbox, monkeypatch):
    before = _snapshot(sandbox)
    real_replace = promotion.os.replace
    calls = {"n": 0}

    def flaky_replace(src, dst):
        calls["n"] += 1
        if calls["n"] == 3:
            raise OSError("disk full")
        return real_replace(src, dst)

    monkeypatch.setattr(promotion.os, "replace", flaky_replace)
    report = promote_revision(HASH, root=sandbox)
    assert not report["ok"] and "rolled back" in report["errors"][0]
    assert _snapshot(sandbox) == before
    assert not list(sandbox.rglob("*.promote-tmp"))
