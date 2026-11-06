"""Phase 2E: promote a unanimously accepted, frozen revision into the
canonical exercise catalog.

Promotion is a deterministic, all-or-nothing transaction:

1. The review record must reference this exact frozen revision hash, and the
   council (human owner + OpenAI reviewer) must both have voted ``accept``.
2. The candidate gate is re-run against today's anatomy and catalog. The
   regenerated 466-muscle profile must be identical to the one the council
   reviewed; otherwise the revision must be re-frozen and re-reviewed.
3. The exercise definition, its versioned engagement profile, the media
   manifest entry and the source crosswalk are staged in memory and
   validated together.
4. Only then are the canonical files replaced (temp file + atomic rename,
   with rollback). A failure at any step leaves canonical data unchanged.
5. A promotion record is written under ``data/exercises/authoring/promotions``.

Prior drafts, revisions, reviews and votes are never modified.

The frozen revision's own content hash is verified on the Godot side
(``ReviewRevisionStore.verify_revision_hash``), which uses the exact
serializer that produced it.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
import time
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

PROJECT_ROOT = Path(__file__).resolve().parents[2]

PROMOTER_VERSION = "promotion_v1"
REQUIRED_VOTERS = ("human_owner", "openai_reviewer")
TOTAL_MUSCLES = 466

REL_EXERCISES = "data/exercises/exercises.json"
REL_PROFILES = "data/exercises/engagement_profiles.json"
REL_CANDIDATES = "data/exercises/catalog/candidates.json"
REL_MEDIA = "data/exercises/sources/free_exercise_db_media.json"
REL_STRUCTURES = "data/anatomy/structures.json"
REL_REVISIONS = "data/exercises/authoring/revisions"
REL_REVIEWS = "data/exercises/authoring/reviews"
REL_PROMOTIONS = "data/exercises/authoring/promotions"


class PromotionError(Exception):
    """Raised when a revision cannot be promoted; canonical data is untouched."""


# ── Public API ──────────────────────────────────────────────────────────────

def promote_revision(
    revision_hash: str,
    *,
    root: Path = PROJECT_ROOT,
    gate: Optional[Callable[[Dict[str, Any]], Dict[str, Any]]] = None,
    now: Optional[float] = None,
    dry_run: bool = False,
) -> Dict[str, Any]:
    """Promote one accepted revision. Returns a report dict.

    ``ok`` is False (with ``errors``) when the revision is not promotable; in
    that case nothing has been written.
    """
    try:
        return _promote(revision_hash, root=Path(root), gate=gate, now=now, dry_run=dry_run)
    except PromotionError as exc:
        return {"ok": False, "promoter": PROMOTER_VERSION, "revision_sha256": revision_hash, "errors": [str(exc)]}


def promotion_record_path(revision_hash: str, root: Path = PROJECT_ROOT) -> Path:
    return Path(root) / REL_PROMOTIONS / f"{revision_hash}.json"


# ── Transaction ─────────────────────────────────────────────────────────────

def _promote(revision_hash: str, *, root: Path, gate, now, dry_run) -> Dict[str, Any]:
    if not revision_hash or any(c not in "0123456789abcdef" for c in revision_hash):
        raise PromotionError("revision hash must be a lowercase hex SHA-256")

    record_path = promotion_record_path(revision_hash, root)
    if record_path.exists():
        existing = _read_json(record_path)
        return {"ok": True, "already_promoted": True, "promoter": PROMOTER_VERSION,
                "revision_sha256": revision_hash, "exercise_id": existing.get("exercise_id"),
                "record_path": str(record_path.relative_to(root))}

    revision = _require_json(root / REL_REVISIONS / f"{revision_hash}.json", "frozen revision")
    review = _require_json(root / REL_REVIEWS / f"{revision_hash}.json", "council review record")

    # 1. Exact revision + unanimous council.
    if revision.get("revision_sha256") != revision_hash:
        raise PromotionError("revision file does not carry the hash it is stored under")
    if review.get("revision_sha256") != revision_hash:
        raise PromotionError("council votes reference a different revision")
    votes = review.get("votes", {})
    for member in REQUIRED_VOTERS:
        vote = votes.get(member)
        if not isinstance(vote, dict):
            raise PromotionError(f"missing council vote from {member}")
        if vote.get("decision") != "accept":
            raise PromotionError(f"{member} did not accept this revision ({vote.get('decision', 'no decision')})")
    rejections = [m for m, v in votes.items() if isinstance(v, dict) and v.get("decision") == "reject"]
    if rejections:
        raise PromotionError(f"revision has rejecting votes: {', '.join(rejections)}")

    authoring = revision.get("authoring_response", {})
    if authoring.get("classification") != "supported":
        raise PromotionError(f"authoring classification is '{authoring.get('classification')}', not 'supported'")
    definition = copy.deepcopy(authoring.get("proposed_definition") or {})
    exercise_id = definition.get("id", "")
    if not exercise_id.startswith("exercise."):
        raise PromotionError("proposed definition has no valid exercise.* id")

    frozen_trace = revision.get("candidate_trace_report", {})
    frozen_profile = frozen_trace.get("profile", {})
    if not frozen_trace.get("ok") or not frozen_profile:
        raise PromotionError("frozen revision has no passing trace report")

    # 2. Re-run every deterministic validator against current canonical data.
    if gate is None:
        from src.exercises.candidate_gate import evaluate_candidate as gate  # noqa: PLC0415
    fresh = gate(definition)
    if not fresh.get("ok"):
        raise PromotionError("candidate gate failed on re-validation: " + "; ".join(fresh.get("errors", [])))
    fresh_profile = fresh.get("profile", {})
    if _normalize_profile(fresh_profile) != _normalize_profile(frozen_profile):
        raise PromotionError(
            "re-validation produced a different muscle profile than the council reviewed "
            "(canonical anatomy or tracer changed); re-freeze and re-review this definition"
        )

    # 3. Stage every canonical change in memory.
    paths = {name: root / rel for name, rel in (
        ("exercises", REL_EXERCISES), ("profiles", REL_PROFILES),
        ("candidates", REL_CANDIDATES), ("media", REL_MEDIA))}
    current = {name: _read_json(path) for name, path in paths.items()}
    before_sha = {name: _sha256(path) for name, path in paths.items()}
    staged = copy.deepcopy(current)
    promoted_at = time.time() if now is None else now

    if any(e.get("id") == exercise_id for e in staged["exercises"]):
        raise PromotionError(f"{exercise_id} already exists in the canonical catalog")
    staged["exercises"].append(definition)

    profile = copy.deepcopy(fresh_profile)
    profile.update({
        "profile_version": 1,
        "promotion": {
            "promoter": PROMOTER_VERSION,
            "revision_sha256": revision_hash,
            "revision_id": revision.get("revision_id", ""),
            "source_catalog_id": revision.get("catalog_id", ""),
            "tracer": fresh.get("provenance", {}).get("tracer", ""),
            "promoted_at_unix": promoted_at,
        },
    })
    staged["profiles"].setdefault("profiles", {})[exercise_id] = profile

    catalog_id = revision.get("catalog_id", "")
    candidate = next((c for c in staged["candidates"] if c.get("catalog_id") == catalog_id), None)
    if candidate is None:
        raise PromotionError(f"source record {catalog_id} is not in the candidate catalog")
    if candidate.get("source_snapshot_sha256") != revision.get("source_snapshot_sha256"):
        raise PromotionError("source record changed since this revision was frozen")
    candidate["status"] = "promoted"
    ids = candidate.setdefault("body_sim_exercise_ids", [])
    if exercise_id not in ids:
        ids.append(exercise_id)
    candidate.setdefault("promotions", []).append({
        "exercise_id": exercise_id,
        "revision_sha256": revision_hash,
        "authoring_provider": _redacted_provider(revision.get("authoring_provider_metadata", {})),
        "review_models": {m: _redacted_provider(v.get("provider_metadata", {})) for m, v in votes.items()
                          if isinstance(v, dict) and v.get("provider_metadata")},
        "promoted_at_unix": promoted_at,
    })

    source_media = next((m for m in staged["media"] if m.get("exercise_id") == catalog_id), None)
    if source_media is None:
        raise PromotionError(f"no demonstration media recorded for {catalog_id}")
    if not any(m.get("exercise_id") == exercise_id for m in staged["media"]):
        variant_media = copy.deepcopy(source_media)
        variant_media["exercise_id"] = exercise_id
        staged["media"].append(variant_media)

    # 4. Validate the staged catalog as a whole before touching disk.
    _validate_staged(staged, root)

    report = {
        "ok": True,
        "promoter": PROMOTER_VERSION,
        "revision_sha256": revision_hash,
        "revision_id": revision.get("revision_id", ""),
        "exercise_id": exercise_id,
        "source_catalog_id": catalog_id,
        "mapped_muscles": profile.get("mapped_muscles"),
        "promoted_at_unix": promoted_at,
        "files_before_sha256": {REL_FOR[n]: s for n, s in before_sha.items()},
        "dry_run": dry_run,
    }
    if dry_run:
        return report

    # 5. Commit atomically, keeping each file's existing formatting so diffs
    #    show only the promoted exercise.
    texts = {
        paths["exercises"]: _append_exercise_text(paths["exercises"].read_text(encoding="utf-8"), definition),
        paths["profiles"]: json.dumps(staged["profiles"], indent=2, ensure_ascii=False),
        paths["candidates"]: json.dumps(staged["candidates"], indent=2) + "\n",
        paths["media"]: json.dumps(staged["media"], indent=2, ensure_ascii=False) + "\n",
    }
    for path, text in texts.items():          # the text must be exactly the staged data
        name = next(n for n, q in paths.items() if q == path)
        if json.loads(text) != staged[name]:
            raise PromotionError(f"internal error: serialized {path.name} does not match staged data")
    _atomic_write_all(texts, root)
    report["files_after_sha256"] = {REL_FOR[n]: _sha256(paths[n]) for n in paths}
    record_path.parent.mkdir(parents=True, exist_ok=True)
    _write_json_atomic(record_path, {k: v for k, v in report.items() if k != "dry_run"})
    report["record_path"] = str(record_path.relative_to(root))
    return report


REL_FOR = {"exercises": REL_EXERCISES, "profiles": REL_PROFILES,
           "candidates": REL_CANDIDATES, "media": REL_MEDIA}


# ── Validation ──────────────────────────────────────────────────────────────

def _validate_staged(staged: Dict[str, Any], root: Path) -> None:
    structures = _read_json(root / REL_STRUCTURES)["structures"]
    muscle_ids = {s["id"] for s in structures if s.get("id", "").startswith("muscle.")}
    if len(muscle_ids) != TOTAL_MUSCLES:
        raise PromotionError(f"anatomy catalog has {len(muscle_ids)} muscles, expected {TOTAL_MUSCLES}")

    exercise_ids = [e.get("id") for e in staged["exercises"]]
    if len(exercise_ids) != len(set(exercise_ids)):
        raise PromotionError("staged exercise catalog has duplicate ids")
    profiles = staged["profiles"].get("profiles", {})
    for exercise_id in exercise_ids:
        profile = profiles.get(exercise_id)
        if profile is None:
            raise PromotionError(f"{exercise_id} has no engagement profile")
        entries = profile.get("muscles", [])
        ids = [m.get("muscle_id") for m in entries]
        if len(ids) != TOTAL_MUSCLES or set(ids) != muscle_ids:
            raise PromotionError(f"{exercise_id} profile does not cover exactly the {TOTAL_MUSCLES} canonical muscles")
    media_ids = {m.get("exercise_id") for m in staged["media"]}
    missing_media = [e for e in exercise_ids if e not in media_ids]
    if missing_media:
        raise PromotionError(f"exercises without media entries: {', '.join(missing_media)}")
    promoted_targets = {i for c in staged["candidates"] if c.get("status") == "promoted"
                        for i in c.get("body_sim_exercise_ids", [])}
    dangling = sorted(promoted_targets - set(exercise_ids))
    if dangling:
        raise PromotionError(f"candidates point at missing exercises: {', '.join(dangling)}")


def _normalize_profile(profile: Dict[str, Any]) -> List[Any]:
    """Comparable form of a profile's muscle entries (number formatting and
    key order differ between the Godot and Python JSON round trips)."""
    out = []
    for entry in sorted(profile.get("muscles", []), key=lambda m: m.get("muscle_id", "")):
        out.append((
            entry.get("muscle_id"), entry.get("role"),
            round(float(entry.get("coefficient", 0.0)), 6),
            entry.get("confidence"), entry.get("evidence_status"),
            tuple(entry.get("evidence_refs", [])),
        ))
    return out


def _redacted_provider(metadata: Dict[str, Any]) -> Dict[str, Any]:
    allowed = ("provider", "model", "prompt_version", "schema_version", "response_id", "created_at_unix")
    return {k: metadata[k] for k in allowed if k in metadata}


# ── File helpers ────────────────────────────────────────────────────────────

def _atomic_write_all(outputs: Dict[Path, str], root: Path) -> None:
    """Write every file to a temp sibling, then rename into place. If any
    rename fails, restore the originals already replaced."""
    temps: Dict[Path, Path] = {}
    try:
        for path, text in outputs.items():
            tmp = path.with_suffix(path.suffix + ".promote-tmp")
            tmp.write_text(text, encoding="utf-8")
            json.loads(tmp.read_text(encoding="utf-8"))  # must round-trip
            temps[path] = tmp
    except Exception as exc:
        for tmp in temps.values():
            tmp.unlink(missing_ok=True)
        raise PromotionError(f"could not stage files: {exc}") from exc

    originals = {path: path.read_bytes() for path in outputs}
    replaced: List[Path] = []
    try:
        for path, tmp in temps.items():
            os.replace(tmp, path)
            replaced.append(path)
    except Exception as exc:
        for path in replaced:
            path.write_bytes(originals[path])
        for tmp in temps.values():
            tmp.unlink(missing_ok=True)
        raise PromotionError(f"promotion rolled back: {exc}") from exc


EXERCISE_KEY_ORDER = ("id", "name", "variant", "aliases", "movement_families",
                      "laterality", "input_mode", "kinematic_profile")
PROFILE_KEY_ORDER = ("kinetic_chain_type", "primary_joint_actions", "load_vector",
                     "stabilization_demands")


def _ordered(d: Dict[str, Any], order) -> Dict[str, Any]:
    return {**{k: d[k] for k in order if k in d}, **{k: v for k, v in d.items() if k not in order}}


def _compact(value: Any, indent: int) -> str:
    """exercises.json house style: objects multi-line, while lists of scalars
    and objects of scalars stay on one line."""
    pad, inner = " " * indent, " " * (indent + 2)
    scalar = lambda v: not isinstance(v, (dict, list))  # noqa: E731
    if isinstance(value, dict):
        if indent > 0 and all(scalar(v) for v in value.values()):
            return "{" + ", ".join(f"{json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}" for k, v in value.items()) + "}"
        if "kinetic_chain_type" in value:
            value = _ordered(value, PROFILE_KEY_ORDER)
        items = [f"{inner}{json.dumps(k)}: {_compact(v, indent + 2)}" for k, v in value.items()]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(value, list):
        if all(scalar(v) for v in value):
            return "[" + ", ".join(json.dumps(v, ensure_ascii=False) for v in value) + "]"
        items = [inner + _compact(v, indent + 2) for v in value]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    return json.dumps(value, ensure_ascii=False)


def _append_exercise_text(raw: str, definition: Dict[str, Any]) -> str:
    """Append one exercise to exercises.json without reformatting the rest."""
    body = raw.rstrip()
    if not body.endswith("]"):
        raise PromotionError("exercises.json is not a JSON array")
    body = body[:-1].rstrip()
    entry = _compact(_ordered(definition, EXERCISE_KEY_ORDER), 2)
    separator = ",\n" if body.endswith("}") else "\n"
    trailing = raw[len(raw.rstrip()):] or ""
    return f"{body}{separator}  {entry}\n]{trailing}"


def _write_json_atomic(path: Path, value: Any) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(_dump(value), encoding="utf-8")
    os.replace(tmp, path)


def _dump(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def _read_json(path: Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _require_json(path: Path, label: str) -> Dict[str, Any]:
    if not path.exists():
        raise PromotionError(f"{label} not found: {path.name}")
    value = _read_json(path)
    if not isinstance(value, dict):
        raise PromotionError(f"{label} is not a JSON object")
    return value


def _sha256(path: Path) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
