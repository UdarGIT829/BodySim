"""Demotion tests: promote the frozen fixture inside a sandbox copy of the
canonical data (the promotion tests' fixture), then demote it."""

import json

from src.exercises import promotion
from src.exercises.demotion import demotable_exercises, demote_exercise, demotion_record_path
from src.exercises.promotion import promote_revision, promotion_record_path

from tests.exercises.test_promotion import EXERCISE_ID, HASH, _target_catalog_id, sandbox  # noqa: F401

RESTORED = [promotion.REL_EXERCISES, promotion.REL_PROFILES, promotion.REL_MEDIA]


def _bytes(root, rels):
    return {rel: (root / rel).read_bytes() for rel in rels}


def _candidate(root):
    candidates = json.loads((root / promotion.REL_CANDIDATES).read_text())
    return next(c for c in candidates if c["catalog_id"] == _target_catalog_id(root))


def test_demotion_undoes_the_promotion(sandbox):  # noqa: F811
    before = _bytes(sandbox, RESTORED)
    assert promote_revision(HASH, root=sandbox, now=1.0)["ok"]
    assert any(e["exercise_id"] == EXERCISE_ID for e in demotable_exercises(sandbox))

    report = demote_exercise(EXERCISE_ID, "It is a stretch.", root=sandbox, now=2.0)
    assert report["ok"], report
    assert report["source_status"] == "catalog_only"
    # Exercises, profiles and media are byte-identical to before the promotion.
    assert _bytes(sandbox, RESTORED) == before
    candidate = _candidate(sandbox)
    assert candidate["status"] == "catalog_only" and candidate["body_sim_exercise_ids"] == []
    assert candidate["demotions"][-1] == {"exercise_id": EXERCISE_ID, "revision_sha256": HASH,
                                          "reason": "It is a stretch.", "demoted_at_unix": 2.0}
    # The promotion record moves into the demotion record.
    assert not promotion_record_path(HASH, sandbox).exists()
    record = json.loads(demotion_record_path(HASH, sandbox).read_text())
    assert record["reason"] == "It is a stretch." and record["promotion_record"]["exercise_id"] == EXERCISE_ID
    assert EXERCISE_ID not in [e["exercise_id"] for e in demotable_exercises(sandbox)]


def test_a_demoted_revision_cannot_be_promoted_again(sandbox):  # noqa: F811
    assert promote_revision(HASH, root=sandbox, now=1.0)["ok"]
    assert demote_exercise(EXERCISE_ID, "wrong", root=sandbox)["ok"]
    again = promote_revision(HASH, root=sandbox)
    assert not again["ok"] and "demoted" in again["errors"][0]


def test_dry_run_writes_nothing(sandbox):  # noqa: F811
    assert promote_revision(HASH, root=sandbox, now=1.0)["ok"]
    before = _bytes(sandbox, RESTORED + [promotion.REL_CANDIDATES])
    assert demote_exercise(EXERCISE_ID, "check", root=sandbox, dry_run=True)["ok"]
    assert _bytes(sandbox, RESTORED + [promotion.REL_CANDIDATES]) == before
    assert promotion_record_path(HASH, sandbox).exists()


def test_refusals_change_nothing(sandbox):  # noqa: F811
    original = json.loads((sandbox / promotion.REL_EXERCISES).read_text())[0]["id"]
    before = _bytes(sandbox, RESTORED + [promotion.REL_CANDIDATES])
    assert "original exercise" in demote_exercise(original, "no", root=sandbox)["errors"][0]
    assert "not in the canonical catalog" in demote_exercise("exercise.nope.none", "no", root=sandbox)["errors"][0]
    assert promote_revision(HASH, root=sandbox, now=1.0)["ok"]
    assert "reason" in demote_exercise(EXERCISE_ID, "  ", root=sandbox)["errors"][0]
    assert _bytes(sandbox, [promotion.REL_EXERCISES]) != before[promotion.REL_EXERCISES]  # still promoted
