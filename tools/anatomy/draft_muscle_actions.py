#!/usr/bin/env python3
"""Draft one review group of the v2 muscle-action table with Claude.

    python3 tools/anatomy/draft_muscle_actions.py --list
    python3 tools/anatomy/draft_muscle_actions.py shoulder_girdle [--model claude-opus-5-5] [--effort high]
    python3 tools/anatomy/draft_muscle_actions.py shoulder_girdle --report-only
    python3 tools/anatomy/draft_muscle_actions.py shoulder_girdle --approve [base_id ...]

Writes data/anatomy/muscle_actions_v2/<group>.json (every entry status
"draft") and a readable review report reports/muscle_actions_v2/<group>.md.
Refuses to overwrite a group that already has reviewed entries.

Caching: the system prompt, vocabulary and full 234-muscle list are an
identical prefix for every group, so after the first group they are read
from cache; only the short group request changes.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from src.anatomy import muscle_actions_v2 as table  # noqa: E402
from src.exercises.llm import claude_client  # noqa: E402

PROMPT_PATH = PROJECT_ROOT / "data/anatomy/prompts/muscle_actions_v2.md"
REPORT_DIR = PROJECT_ROOT / "reports/muscle_actions_v2"
SETTINGS = Path.home() / ".local/share/godot/app_userdata/BodySim_Visualizer/bodysim_authoring_settings.cfg"


def system_text() -> str:
    """Stable, cacheable prefix: instructions + vocabulary + every muscle."""
    groups = table.group_muscles()
    listing = {g: [{"base_id": m["base_id"], "name": m["name"], "hierarchy": m["hierarchy"]}
                   for m in groups[g]] for g in table.GROUP_ORDER}
    return (PROMPT_PATH.read_text(encoding="utf-8")
            + "\n\n### Vocabulary\n\n```json\n" + json.dumps(table.load_vocabulary(), indent=1, sort_keys=True)
            + "\n```\n\n### All muscles by review group\n\n```json\n" + json.dumps(listing, indent=1) + "\n```\n")


def group_request(group: str) -> str:
    muscles = table.group_muscles()[group]
    lines = [f"- `{m['base_id']}`: {m['name']} ({m['hierarchy']})" for m in muscles]
    return (f"Draft the group `{group}`: {table.GROUP_TITLES[group]}.\n"
            f"It has {len(muscles)} muscles; return exactly one entry for each:\n" + "\n".join(lines))


def write_report(group: str, document: dict) -> Path:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    names = {m["base_id"]: m["name"] for m in table.group_muscles()[group]}
    out = [f"# {table.GROUP_TITLES[group]}", "",
           f"Drafted by {document.get('drafted_with', {}).get('model', '?')}. "
           "Review each muscle; set `status` to `reviewed` in the JSON once it is right.", ""]
    for approval in document.get("approvals", []):
        out += [f"**Approved** ({len(approval['entries'])} entries): {approval['basis']}.", ""]
    problems = table.validate_group(group, document)
    out += ["**Rule checks:** " + ("all passed" if not problems else f"{len(problems)} problem(s)"), ""]
    out += [f"- {p}" for p in problems] + ([""] if problems else [])
    for entry in document["entries"]:
        title = names.get(entry["base_id"], entry["base_id"])
        out.append(f"## {title}  `{entry['base_id']}`")
        out.append(f"*{entry['status']} · confidence {entry['confidence']}*" + ("" if entry["movement_muscle"] else " · **not a movement muscle**"))
        out.append("")
        for a in sorted(entry["actions"], key=lambda a: -a["weight"]):
            out.append(f"- {a['joint']} / {a['movement']}: **{a['weight']:.2f}**")
        for s in sorted(entry["stabilizes"], key=lambda s: -s["weight"]):
            out.append(f"- stabilizes {s['demand']}: {s['weight']:.2f}")
        if not entry["actions"] and not entry["stabilizes"]:
            out.append("- (no actions)")
        out += ["", f"> {entry['rationale']}", ""]
    path = REPORT_DIR / f"{group}.md"
    path.write_text("\n".join(out), encoding="utf-8")
    return path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("group", nargs="?")
    parser.add_argument("--list", action="store_true", help="list review groups and their status")
    parser.add_argument("--model", default=claude_client.DEFAULT_MODEL)
    parser.add_argument("--effort", default="high")
    parser.add_argument("--report-only", action="store_true", help="rebuild the review report from the existing file")
    parser.add_argument("--approve", nargs="*", metavar="BASE_ID",
                        help="mark entries reviewed (all entries if no ids are given), after a passing rule check")
    parser.add_argument("--basis", default="reviewed line by line by the project owner",
                        help="how the approval was made; recorded in the group file")
    args = parser.parse_args()

    groups = table.group_muscles()
    if args.list or not args.group:
        for g in table.GROUP_ORDER:
            path = table.TABLE_DIR / f"{g}.json"
            state = "not drafted"
            if path.exists():
                doc = json.loads(path.read_text())
                reviewed = sum(e["status"] == "reviewed" for e in doc["entries"])
                state = f"{reviewed}/{len(doc['entries'])} reviewed"
            print(f"{g:16} {len(groups[g]):3} muscles  {state}")
        return 0
    if args.group not in groups:
        parser.error(f"unknown group; choose from {', '.join(table.GROUP_ORDER)}")

    path = table.TABLE_DIR / f"{args.group}.json"
    if args.approve is not None:
        if not path.exists():
            parser.error(f"{path.name} has not been drafted yet")
        document = json.loads(path.read_text())
        problems = table.validate_group(args.group, document)
        if problems:
            print("Fix these before approving:\n  " + "\n  ".join(problems), file=sys.stderr)
            return 1
        wanted = set(args.approve) or {e["base_id"] for e in document["entries"]}
        unknown = wanted - {e["base_id"] for e in document["entries"]}
        if unknown:
            parser.error(f"not in {args.group}: {', '.join(sorted(unknown))}")
        for e in document["entries"]:
            if e["base_id"] in wanted:
                e["status"] = "reviewed"
        document.setdefault("approvals", []).append({
            "approved_by": "project_owner",
            "basis": args.basis,
            "entries": sorted(wanted),
            "approved_at_unix": time.time(),
        })
        path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        write_report(args.group, document)
        done = sum(e["status"] == "reviewed" for e in document["entries"])
        print(f"{args.group}: {done}/{len(document['entries'])} reviewed")
        return 0
    if args.report_only:
        print(write_report(args.group, json.loads(path.read_text())))
        return 0
    if path.exists() and any(e["status"] == "reviewed" for e in json.loads(path.read_text())["entries"]):
        print(f"{path.name} has reviewed entries; refusing to overwrite. Move it aside first.", file=sys.stderr)
        return 1

    content = [{"type": "text", "text": group_request(args.group)}]
    print(f"Drafting {args.group} ({len(groups[args.group])} muscles) with {args.model}, effort {args.effort}…", flush=True)
    result = claude_client.call_structured(
        system_text(), table.drafting_schema(table.load_vocabulary()), content,
        model=args.model, effort=args.effort, settings_path=str(SETTINGS), label="muscle-action drafting")
    if not result["ok"]:
        print(f"Failed: {result['error']}", file=sys.stderr)
        return 2

    meta = result["metadata"]
    entries = result["value"]["entries"]
    for e in entries:
        e["status"] = "draft"
    document = {
        "format_version": 2,
        "group": args.group,
        "title": table.GROUP_TITLES[args.group],
        "drafted_with": {k: meta.get(k) for k in ("provider", "model", "effort", "response_id")},
        "drafted_at_unix": time.time(),
        "entries": sorted(entries, key=lambda e: e["base_id"]),
    }
    table.TABLE_DIR.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    report = write_report(args.group, document)
    problems = table.validate_group(args.group, document)
    u = meta["usage"]
    print(f"Wrote {path.relative_to(PROJECT_ROOT)} and {report.relative_to(PROJECT_ROOT)}")
    print(f"Tokens: input {u['input_tokens']}, cache write {u['cache_creation_input_tokens']}, "
          f"cache read {u['cache_read_input_tokens']}, output {u['output_tokens']}")
    print("Rule checks: " + ("all passed" if not problems else "\n  " + "\n  ".join(problems)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
