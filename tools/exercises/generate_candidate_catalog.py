"""Generate the complete Phase 2A source-candidate catalog."""

from __future__ import annotations

import json
from pathlib import Path


SOURCE_CATALOG = Path("data/exercises/sources/free_exercise_db.json")
CROSSWALK = Path("data/exercises/sources/crosswalk.json")
OUTPUT = Path("data/exercises/catalog/candidates.json")
CATALOG_ID_PREFIX = "catalog.free_exercise_db."


def main() -> None:
    source_records = json.loads(SOURCE_CATALOG.read_text(encoding="utf-8"))
    crosswalk = {
        entry["source_id"]: entry
        for entry in json.loads(CROSSWALK.read_text(encoding="utf-8"))
    }
    candidates = []
    for source in source_records:
        source_id = source["id"]
        mapping = crosswalk[source_id]
        body_sim_ids = mapping.get("body_sim_exercise_ids", [])
        candidates.append(
            {
                "catalog_id": CATALOG_ID_PREFIX + source_id,
                "source": "free_exercise_db",
                "source_id": source_id,
                "source_snapshot_sha256": mapping["snapshot_sha256"],
                "name": source["name"],
                "status": "promoted" if body_sim_ids else "catalog_only",
                "body_sim_exercise_ids": body_sim_ids,
                "category": source.get("category"),
                "equipment": source.get("equipment"),
                "level": source.get("level"),
                "force": source.get("force"),
                "mechanic": source.get("mechanic"),
                "instructions": source.get("instructions", []),
                "source_muscle_tags": {
                    "primary": source.get("primaryMuscles", []),
                    "secondary": source.get("secondaryMuscles", []),
                    "used_as_evidence": False,
                },
                "source_images": source.get("images", []),
            }
        )

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(candidates, indent=2) + "\n", encoding="utf-8")
    promoted = sum(item["status"] == "promoted" for item in candidates)
    print(
        f"Generated {len(candidates)} source candidates: "
        f"{len(candidates) - promoted} catalog only, {promoted} promoted source records"
    )


if __name__ == "__main__":
    main()
