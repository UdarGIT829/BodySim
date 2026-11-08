"""Apply a council reviewer's proposed edits to a rejected revision.

When the reviewer's findings can be fixed by a few field changes (a label,
an action's emphasis, a missing demand), it proposes them as structured
edits (see the review schema's proposed_edits). Applying them is free and
deterministic, unlike re-authoring the whole definition with Claude:

1. The edits are checked and applied to a copy of the rejected revision's
   definition. Any edit that can't apply (an unknown joint/movement pair,
   removing something that isn't there) rejects the whole set.
2. The candidate gate re-traces the edited definition.
3. The result is saved as the exercise's new draft, recording which revision
   and edits it came from. The council then freezes and reviews it like any
   other draft, so nothing is promoted without a vote on the edited version.

Frozen revisions and reviews are never modified.
"""

from __future__ import annotations

import copy
import json
import time
from pathlib import Path
from typing import Any, Dict, List, Tuple

from src.exercises.promotion import PROJECT_ROOT, REL_REVIEWS, REL_REVISIONS

REL_DRAFTS = "data/exercises/authoring/drafts"
MODEL_MEMBER = "model_reviewer"


class EditError(Exception):
    pass


def usable_actions() -> Dict[str, List[str]]:
    from tools.anatomy.sync_vocabulary import usable_actions as actions  # noqa: PLC0415
    return actions()


def _find_action(actions: List[Dict[str, Any]], joint: str, movement: str) -> int:
    for i, a in enumerate(actions):
        if a.get("joint") == joint and a.get("movement") == movement:
            return i
    return -1


def apply_edits(definition: Dict[str, Any], edits: List[Dict[str, Any]],
                vocabulary: Dict[str, List[str]] | None = None) -> Tuple[Dict[str, Any], List[str]]:
    """Returns (edited definition, human-readable descriptions). Raises EditError."""
    if not edits:
        raise EditError("no edits to apply")
    vocabulary = vocabulary if vocabulary is not None else usable_actions()
    d = copy.deepcopy(definition)
    profile = d.setdefault("kinematic_profile", {})
    actions = profile.setdefault("primary_joint_actions", [])
    demands = profile.setdefault("stabilization_demands", [])
    described = []
    for edit in edits:
        op = edit.get("op")
        joint, movement = edit.get("joint"), edit.get("movement")
        if joint is not None and movement not in vocabulary.get(joint, []):
            raise EditError(f"{op}: {joint}/{movement} is not a joint action the tracer knows")
        if op == "set_kinetic_chain_type":
            profile["kinetic_chain_type"] = edit["value"]
            described.append(f"kinetic chain -> {edit['value']}")
        elif op == "set_laterality":
            d["laterality"] = edit["value"]
            described.append(f"laterality -> {edit['value']}")
        elif op == "set_movement_families":
            if not edit["value"]:
                raise EditError("set_movement_families: needs at least one family")
            d["movement_families"] = list(dict.fromkeys(edit["value"]))
            described.append(f"movement families -> {', '.join(d['movement_families'])}")
        elif op == "set_one_sided_limbs":
            profile["one_sided_limbs"] = list(dict.fromkeys(edit["value"]))
            described.append(f"one-sided limbs -> {profile['one_sided_limbs'] or 'none'}")
        elif op == "add_joint_action":
            i = _find_action(actions, joint, movement)
            action = {"joint": joint, "movement": movement, "emphasis": edit["emphasis"], "sides": edit["sides"]}
            if i >= 0:
                actions[i] = action
            else:
                actions.append(action)
            described.append(f"add {joint}/{movement} ({edit['emphasis']}, {edit['sides']})")
        elif op in ("remove_joint_action", "set_action_emphasis", "set_action_sides"):
            i = _find_action(actions, joint, movement)
            if i < 0:
                raise EditError(f"{op}: {joint}/{movement} is not in the definition")
            if op == "remove_joint_action":
                actions.pop(i)
                described.append(f"remove {joint}/{movement}")
            elif op == "set_action_emphasis":
                actions[i]["emphasis"] = edit["emphasis"]
                actions[i].setdefault("sides", "working")
                described.append(f"{joint}/{movement} emphasis -> {edit['emphasis']}")
            else:
                actions[i]["sides"] = edit["sides"]
                actions[i].setdefault("emphasis", "primary")
                described.append(f"{joint}/{movement} sides -> {edit['sides']}")
        elif op == "add_stabilization_demand":
            if edit["demand"] not in demands:
                demands.append(edit["demand"])
            described.append(f"add demand {edit['demand']}")
        elif op == "remove_stabilization_demand":
            if edit["demand"] not in demands:
                raise EditError(f"remove_stabilization_demand: {edit['demand']} is not in the definition")
            demands.remove(edit["demand"])
            described.append(f"remove demand {edit['demand']}")
        else:
            raise EditError(f"unknown edit operation {op!r}")
    if not actions:
        raise EditError("the edits would leave no joint actions")
    return d, described


def apply_to_revision(revision_hash: str, *, root: Path = PROJECT_ROOT, gate=None, now: float | None = None,
                      dry_run: bool = False) -> Dict[str, Any]:
    """Apply the model reviewer's proposed edits for a rejected revision and
    save the result as the exercise's new draft. Returns a report."""
    try:
        return _apply(revision_hash, Path(root), gate, now, dry_run)
    except EditError as exc:
        return {"ok": False, "revision_sha256": revision_hash, "errors": [str(exc)]}


def _apply(revision_hash, root, gate, now, dry_run):
    rev_path = root / REL_REVISIONS / f"{revision_hash}.json"
    review_path = root / REL_REVIEWS / f"{revision_hash}.json"
    if not rev_path.exists() or not review_path.exists():
        raise EditError("no frozen revision and review with that hash")
    revision = json.loads(rev_path.read_text(encoding="utf-8"))
    review = json.loads(review_path.read_text(encoding="utf-8"))
    if review.get("status") != "changes_requested":
        raise EditError("only a rejected revision's edits can be applied")
    vote = review.get("votes", {}).get(MODEL_MEMBER, {})
    edits = vote.get("proposed_edits") or []
    others = [m for m, v in review.get("votes", {}).items()
              if m != MODEL_MEMBER and isinstance(v, dict) and v.get("decision") == "reject"]
    if others:
        raise EditError(f"also rejected by {', '.join(others)}; their findings need re-authoring")
    response = copy.deepcopy(revision.get("authoring_response", {}))
    edited, described = apply_edits(response.get("proposed_definition") or {}, edits)
    response["proposed_definition"] = edited
    response.setdefault("assumptions", []).append(
        f"Edited by the council from revision {revision_hash[:12]}, as the reviewer proposed: {'; '.join(described)}.")

    if gate is None:
        from src.exercises.candidate_gate import evaluate_candidate as gate  # noqa: PLC0415
    trace = gate(edited)
    saved_at = time.time() if now is None else now
    metadata = copy.deepcopy(revision.get("authoring_provider_metadata", {}))
    metadata["edited_by_council"] = {
        "from_revision_sha256": revision_hash,
        "edits": edits,
        "described": described,
        "reviewer_model": vote.get("provider_metadata", {}).get("model", ""),
        "resolve_all_blocking_findings": bool(vote.get("edits_resolve_all_blocking_findings", False)),
    }
    draft = {
        "format_version": 1,
        "catalog_id": revision.get("catalog_id", ""),
        "source_id": revision.get("source_id", ""),
        "source_snapshot_sha256": revision.get("source_snapshot_sha256", ""),
        "status": "definition_candidate" if trace.get("ok") else "authoring_draft",
        "additional_context": revision.get("additional_context", ""),
        "authoring_response": response,
        "provider_metadata": metadata,
        "validation_errors": [] if trace.get("ok") else [f"trace: {e}" for e in trace.get("errors", [])],
        "candidate_trace_report": trace,
        "saved_at_unix": saved_at,
    }
    report = {"ok": bool(trace.get("ok")), "revision_sha256": revision_hash, "source_id": draft["source_id"],
              "described": described, "status": draft["status"], "errors": draft["validation_errors"],
              "role_counts": trace.get("summary", {}).get("role_counts", {}), "dry_run": dry_run}
    if not dry_run:
        path = root / REL_DRAFTS / f"{draft['source_id']}.json"
        path.write_text(json.dumps(draft, indent=2), encoding="utf-8")
        report["draft_path"] = str(path.relative_to(root))
    return report
