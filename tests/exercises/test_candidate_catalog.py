"""Phase 2A completeness tests for the source candidate and media catalogs."""

import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).parents[2]
SOURCE_PATH = ROOT / "data/exercises/sources/free_exercise_db.json"
CANDIDATE_PATH = ROOT / "data/exercises/catalog/candidates.json"
MEDIA_PATH = ROOT / "data/exercises/sources/free_exercise_db_media.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def test_candidate_catalog_represents_every_source_record_once():
    sources = load(SOURCE_PATH)
    candidates = load(CANDIDATE_PATH)

    assert len(sources) == 873
    assert len(candidates) == 873
    assert len({item["catalog_id"] for item in candidates}) == 873
    assert {item["source_id"] for item in candidates} == {
        item["id"] for item in sources
    }
    # Promotion moves sources from catalog_only to promoted; nothing else exists.
    statuses = Counter(item["status"] for item in candidates)
    assert set(statuses) == {"catalog_only", "promoted"}
    assert statuses["catalog_only"] + statuses["promoted"] == 873 and statuses["promoted"] >= 20
    # Every promoted source names its BodySim exercises (one source can map to several variants).
    linked = sum(len(item["body_sim_exercise_ids"]) for item in candidates)
    assert linked >= statuses["promoted"]
    assert all(item["body_sim_exercise_ids"] for item in candidates if item["status"] == "promoted")


def test_catalog_only_records_cannot_claim_body_sim_profiles():
    candidates = load(CANDIDATE_PATH)
    for candidate in candidates:
        if candidate["status"] == "catalog_only":
            assert candidate["body_sim_exercise_ids"] == []
        assert candidate["source_muscle_tags"]["used_as_evidence"] is False


def test_media_manifest_covers_every_source_image_and_selector_identity():
    candidates = load(CANDIDATE_PATH)
    manifest = load(MEDIA_PATH)
    by_exercise = {entry["exercise_id"]: entry for entry in manifest}

    canonical = load(ROOT / "data/exercises/exercises.json")
    assert len(manifest) == 873 + len(canonical)  # source identities + canonical identities
    assert len(by_exercise) == len(manifest)
    assert all(candidate["catalog_id"] in by_exercise for candidate in candidates)

    resources = {
        image["resource_path"]
        for entry in manifest
        for image in entry["images"]
    }
    assert len(resources) == 1746
    for resource_path in resources:
        assert resource_path.startswith("res://assets/exercises/free_exercise_db/")
        assert (ROOT / resource_path.removeprefix("res://")).is_file()


def test_every_media_record_preserves_source_and_license_metadata():
    for entry in load(MEDIA_PATH):
        assert entry["source"] == "free_exercise_db"
        assert entry["source_id"]
        assert entry["source_name"]
        assert entry["license"] == "Unlicense"
        assert len(entry["images"]) == 2
        for image in entry["images"]:
            assert len(image["sha256"]) == 64
            assert image["bytes"] > 0
