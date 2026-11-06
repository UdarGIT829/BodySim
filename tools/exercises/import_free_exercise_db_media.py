"""Import every free-exercise-db image and generate the complete Godot media manifest."""

from __future__ import annotations

import hashlib
import json
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


SOURCE_BASE_URL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"
SOURCE_CATALOG = Path("data/exercises/sources/free_exercise_db.json")
CROSSWALK = Path("data/exercises/sources/crosswalk.json")
OUTPUT_ROOT = Path("assets/exercises/free_exercise_db")
MANIFEST = Path("data/exercises/sources/free_exercise_db_media.json")
CATALOG_ID_PREFIX = "catalog.free_exercise_db."
MAX_WORKERS = 12


def download(relative_source_path: str) -> tuple[str, bytes]:
    destination = OUTPUT_ROOT / relative_source_path
    if destination.is_file():
        payload = destination.read_bytes()
    else:
        request = urllib.request.Request(
            SOURCE_BASE_URL + relative_source_path,
            headers={"User-Agent": "BodySim-Media-Importer"},
        )
        last_error: Exception | None = None
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=45) as response:
                    payload = response.read()
                break
            except Exception as error:  # network retry boundary
                last_error = error
                if attempt == 2:
                    raise
                time.sleep(0.5 * (attempt + 1))
        else:  # pragma: no cover
            raise last_error or RuntimeError(relative_source_path)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(payload)

    if not payload.startswith(b"\xff\xd8\xff"):
        raise ValueError(f"Asset is not a JPEG: {relative_source_path}")
    return relative_source_path, payload


def main() -> None:
    source_list = json.loads(SOURCE_CATALOG.read_text(encoding="utf-8"))
    source_records = {record["id"]: record for record in source_list}
    mappings = {
        entry["source_id"]: entry
        for entry in json.loads(CROSSWALK.read_text(encoding="utf-8"))
    }
    relative_paths = sorted(
        {path for source in source_list for path in source.get("images", [])}
    )
    payloads: dict[str, bytes] = {}
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(download, path): path for path in relative_paths}
        for completed_count, future in enumerate(as_completed(futures), start=1):
            path, payload = future.result()
            payloads[path] = payload
            if completed_count % 100 == 0 or completed_count == len(relative_paths):
                print(f"Imported {completed_count}/{len(relative_paths)} unique images", flush=True)

    manifest_entries = []
    for source in source_list:
        source_id = source["id"]
        imported_images = []
        for relative_source_path in source.get("images", []):
            payload = payloads[relative_source_path]
            destination = OUTPUT_ROOT / relative_source_path
            imported_images.append(
                {
                    "source_path": relative_source_path,
                    "resource_path": "res://" + destination.as_posix(),
                    "sha256": hashlib.sha256(payload).hexdigest(),
                    "bytes": len(payload),
                }
            )

        common = {
            "source": "free_exercise_db",
            "source_id": source_id,
            "source_name": source["name"],
            "repository": "https://github.com/yuhonas/free-exercise-db",
            "license": "Unlicense",
            "images": imported_images,
        }
        manifest_entries.append(
            {"exercise_id": CATALOG_ID_PREFIX + source_id, **common}
        )
        for exercise_id in mappings[source_id].get("body_sim_exercise_ids", []):
            manifest_entries.append({"exercise_id": exercise_id, **common})

    manifest_entries.sort(key=lambda entry: entry["exercise_id"])
    MANIFEST.write_text(json.dumps(manifest_entries, indent=2) + "\n", encoding="utf-8")
    print(
        f"Imported {len(relative_paths)} unique images for {len(source_records)} source "
        f"records; wrote {len(manifest_entries)} selector media mappings"
    )


if __name__ == "__main__":
    main()
