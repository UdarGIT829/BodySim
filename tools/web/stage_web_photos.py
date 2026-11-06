#!/usr/bin/env python3
"""Copy free-exercise-db demonstration photos next to a BodySim web export.

The web build excludes the photos from index.pck (Godot imports them as
uncompressed textures, ~580 MB). Instead exercise_image_modal.gd fetches each
JPG on demand from <export dir>/photos/<source_path>. Run this after every
web export:

    python3 tools/web/stage_web_photos.py build/web

Every copied file is verified against the SHA-256 in the media manifest.
"""
import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "data/exercises/sources/free_exercise_db_media.json"
SOURCE_DIR = ROOT / "assets/exercises/free_exercise_db"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("export_dir", type=Path, help="web export folder containing index.html")
    args = parser.parse_args()
    if not (args.export_dir / "index.html").exists():
        print(f"{args.export_dir} has no index.html; export the Web preset first", file=sys.stderr)
        return 1

    dest_root = args.export_dir / "photos"
    records = json.loads(MANIFEST.read_text())
    copied = skipped = 0
    total_bytes = 0
    for record in records:
        for image in record.get("images", []):
            rel = image["source_path"]
            src = SOURCE_DIR / rel
            data = src.read_bytes()
            if hashlib.sha256(data).hexdigest() != image["sha256"]:
                print(f"checksum mismatch: {src}", file=sys.stderr)
                return 1
            dest = dest_root / rel
            if dest.exists() and dest.stat().st_size == len(data):
                skipped += 1
            else:
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(src, dest)
                copied += 1
            total_bytes += len(data)

    # free-exercise-db is released under the Unlicense; keep provenance alongside the files.
    (dest_root / "SOURCE.txt").write_text(
        "Demonstration photos from free-exercise-db (https://github.com/yuhonas/free-exercise-db), "
        "released under the Unlicense.\n"
    )
    print(f"photos staged in {dest_root}: {copied} copied, {skipped} already present, "
          f"{total_bytes / 1e6:.1f} MB total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
