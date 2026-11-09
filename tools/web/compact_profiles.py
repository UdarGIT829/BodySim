#!/usr/bin/env python3
"""Write the compact engagement-profile file the web build ships.

    python3 tools/web/compact_profiles.py [--output PATH]

data/exercises/engagement_profiles.json lists all 466 muscles for every
exercise, and most entries are identical "reviewed zero" boilerplate. Pretty-
printed, it grows by about 170 KB per promoted exercise, which would soon
push the web build's index.pck past GitHub's 100 MB file limit.

The compact file (format bodysim.engagement_profiles.compact.v1) lists the
muscle IDs once and, per profile, a zero template plus only the entries that
differ from it, without indentation. ProfileStore (src/exercises/profile_store.gd)
expands it back. This script refuses to write unless expanding its output
reproduces the full file exactly. The full file stays the source of truth;
the compact one is a build artifact (git-ignored).
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FULL = ROOT / "data/exercises/engagement_profiles.json"
COMPACT = ROOT / "data/exercises/engagement_profiles.compact.json"
FORMAT = "bodysim.engagement_profiles.compact.v1"


def _key(entry: dict) -> str:
    return json.dumps({k: v for k, v in entry.items() if k != "muscle_id"}, sort_keys=True)


def compact(full: dict) -> dict:
    profiles = full["profiles"]
    first = next(iter(profiles.values()))
    muscle_ids = [m["muscle_id"] for m in first["muscles"]]
    out = {"format": FORMAT, "muscle_ids": muscle_ids, "profiles": {}}
    for exercise_id, profile in profiles.items():
        if [m["muscle_id"] for m in profile["muscles"]] != muscle_ids:
            raise SystemExit(f"{exercise_id}: muscles are not in the shared canonical order")
        zeros = [m for m in profile["muscles"] if m.get("coefficient") == 0]
        template = {}
        if zeros:
            common = Counter(_key(m) for m in zeros).most_common(1)[0][0]
            template = json.loads(common)
        rest = {k: v for k, v in profile.items() if k != "muscles"}
        rest["zero_template"] = template
        rest["entries"] = {str(i): m for i, m in enumerate(profile["muscles"])
                           if not (template and m.get("coefficient") == 0 and _key(m) == json.dumps(template, sort_keys=True))}
        for entry in rest["entries"].values():
            entry.pop("muscle_id", None)   # implied by its index
        out["profiles"][exercise_id] = rest
    return out


def expand(data: dict) -> dict:
    """The inverse; mirrors ProfileStore.expand_compact in GDScript."""
    ids = data["muscle_ids"]
    profiles = {}
    for exercise_id, rest in data["profiles"].items():
        profile = {k: v for k, v in rest.items() if k not in ("zero_template", "entries")}
        muscles = []
        for i, muscle_id in enumerate(ids):
            source = rest["entries"].get(str(i), rest["zero_template"])
            muscles.append({"muscle_id": muscle_id, **source})
        profile["muscles"] = muscles
        profiles[exercise_id] = profile
    return {"profiles": profiles}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--output", type=Path, default=COMPACT)
    args = parser.parse_args()
    full = json.loads(FULL.read_text(encoding="utf-8"))
    data = compact(json.loads(json.dumps(full)))
    if expand(data) != {"profiles": full["profiles"]}:
        print("compact_profiles: expanding the compact file does not reproduce the full one; not written", file=sys.stderr)
        return 1
    text = json.dumps(data, separators=(",", ":"), ensure_ascii=False)
    args.output.write_text(text, encoding="utf-8")
    print(f"compact profiles: {len(data['profiles'])} exercises, {FULL.stat().st_size / 1048576:.1f} MB -> {len(text.encode()) / 1048576:.1f} MB ({args.output.name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
