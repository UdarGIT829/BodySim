#!/usr/bin/env python3
"""Re-trace canonical profiles and unpromoted drafts after a tracer change.

    python3 tools/exercises/retrace.py --dry-run   # report only
    python3 tools/exercises/retrace.py

Deterministic and free (no Claude requests).

- Canonical engagement profiles: muscles and counts are re-derived with the
  current tracer. Every other key (a promotion's metadata) is kept, and any
  muscle whose role or coefficient changes is reported.
- Drafts whose source isn't promoted: the candidate trace report is re-run.
  A draft the council rejected (its frozen revision has changes_requested)
  becomes review_rejected with the reviewer's summary, so the Studio
  re-authors it with that feedback instead of the council re-reviewing an
  unchanged definition under a new trace. A draft that now fails the gate
  goes back to authoring_draft.

Frozen revisions, reviews and votes are never modified.
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

from src.exercises.candidate_gate import evaluate_candidate  # noqa: E402
from tools.exercises.kinematic_tracer import TRACER_VERSION, load_inputs, trace_exercise_kinematics  # noqa: E402

DATA = PROJECT_ROOT / "data/exercises"
AUTHORING = DATA / "authoring"


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def retrace_profiles(dry_run: bool) -> list:
    ids, actions, exercises = load_inputs()
    path = DATA / "engagement_profiles.json"
    data = read(path)
    changes = []
    for exercise in exercises:
        old = data["profiles"].get(exercise["id"], {})
        entries = trace_exercise_kinematics(exercise, ids, actions)
        before = {m["muscle_id"]: (m["role"], m["coefficient"]) for m in old.get("muscles", [])}
        after = {m["muscle_id"]: (m["role"], m["coefficient"]) for m in entries}
        changed = sorted(k for k in after if before.get(k) != after[k])
        if changed:
            changes.append((exercise["id"], changed))
        mapped = sum(1 for e in entries if e["coefficient"] > 0)
        data["profiles"][exercise["id"]] = {**old, "exercise_id": exercise["id"], "total_muscles": len(entries),
                                            "mapped_muscles": mapped, "zero_muscles": len(entries) - mapped, "muscles": entries}
    if not dry_run:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return changes


def latest_revision_review(source_id: str, authoring_response: dict):
    """The newest frozen revision of this exact authoring response, with its review."""
    best = None
    for path in (AUTHORING / "revisions").glob("*.json"):
        revision = read(path)
        if revision.get("source_id") != source_id or revision.get("authoring_response") != authoring_response:
            continue
        review_path = AUTHORING / "reviews" / path.name
        review = read(review_path) if review_path.exists() else {}
        if best is None or review.get("updated_at_unix", 0) > best[1].get("updated_at_unix", 0):
            best = (revision, review)
    return best


def retrace_drafts(dry_run: bool) -> list:
    catalog = {c["source_id"]: c for c in read(DATA / "catalog/candidates.json")}
    report = []
    for path in sorted((AUTHORING / "drafts").glob("*.json")):
        draft = read(path)
        source_id = draft.get("source_id", "")
        definition = (draft.get("authoring_response") or {}).get("proposed_definition")
        if catalog.get(source_id, {}).get("status") == "promoted" or not isinstance(definition, dict):
            continue
        old_status = draft.get("status")
        trace = evaluate_candidate(definition)
        draft["candidate_trace_report"] = trace
        found = latest_revision_review(source_id, draft.get("authoring_response"))
        votes = found[1].get("votes", {}) if found else {}
        model_vote = votes.get("model_reviewer") or {}
        if old_status == "definition_candidate" and found and found[1].get("status") == "changes_requested":
            rejecting = model_vote if model_vote.get("decision") == "reject" else votes.get("human_owner", {})
            draft["status"] = "review_rejected"
            draft["rejection"] = {
                "member": "model_reviewer" if rejecting is model_vote else "human_owner",
                "summary": rejecting.get("summary", "Rejected by the council."),
                "recorded_at_unix": time.time(),
                "stage": "frozen_revision",
                "revision_sha256": found[0].get("revision_sha256", ""),
            }
        elif old_status == "definition_candidate" and not trace["ok"]:
            draft["status"] = "authoring_draft"
            draft["validation_errors"] = [f"trace: {e}" for e in trace["errors"]]
        report.append((path.stem, old_status, draft["status"], trace["summary"]["role_counts"]))
        if not dry_run:
            path.write_text(json.dumps(draft, indent=2), encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    print(f"Re-tracing with {TRACER_VERSION}{' (dry run)' if args.dry_run else ''}")
    changes = retrace_profiles(args.dry_run)
    print(f"Canonical profiles: {len(changes)} exercise(s) with changed muscles")
    for exercise_id, muscles in changes:
        print(f"  {exercise_id}: {len(muscles)} muscle(s), e.g. {', '.join(muscles[:4])}")
    for name, old, new, roles in retrace_drafts(args.dry_run):
        print(f"  draft {name}: {old} -> {new}  {roles}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
