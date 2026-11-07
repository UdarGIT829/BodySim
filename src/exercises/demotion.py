"""Demote a council-promoted exercise back to catalog-only.

The inverse of promotion (src/exercises/promotion.py), with the same
all-or-nothing rules:

1. Only exercises promoted by the council can be demoted: their engagement
   profile carries a ``promotion`` block and a promotion record exists. The
   hand-built original exercises can't be.
2. The exercise definition, its engagement profile and its media entry are
   removed; its source record loses the exercise ID, goes back to
   ``catalog_only`` when no other exercise uses it, and gets a dated
   ``demotions`` note. The staged catalog is validated before any write.
3. The canonical files are replaced atomically, with rollback.
4. The promotion record moves into a demotion record (with the reason), so
   the audit trail stays and the council no longer shows it as promoted.
   ``promote_revision`` refuses a demoted revision, so auto mode can't put it
   straight back; it has to be re-authored as a new revision.

Drafts, revisions, reviews and votes are never modified.
"""

from __future__ import annotations

import copy
import json
import time
from pathlib import Path
from typing import Any, Dict, Optional

from src.exercises.promotion import (
    EXERCISE_KEY_ORDER, PROJECT_ROOT, REL_CANDIDATES, REL_DEMOTIONS, REL_EXERCISES, REL_FOR, REL_PROFILES,
    PromotionError, _atomic_write_all, _compact, _ordered, _read_json, _sha256, _validate_staged,
    _write_json_atomic, promotion_record_path,
)

DEMOTER_VERSION = "demotion_v1"


def demotion_record_path(revision_hash: str, root: Path = PROJECT_ROOT) -> Path:
    return Path(root) / REL_DEMOTIONS / f"{revision_hash}.json"


def demotable_exercises(root: Path = PROJECT_ROOT) -> list:
    """Council-promoted exercises, newest first: [{exercise_id, name,
    source_catalog_id, category, revision_sha256, promoted_at_unix}]."""
    root = Path(root)
    profiles = _read_json(root / REL_PROFILES).get("profiles", {})
    exercises = {e.get("id"): e for e in _read_json(root / REL_EXERCISES)}
    candidates = {c.get("catalog_id"): c for c in _read_json(root / REL_CANDIDATES)}
    out = []
    for exercise_id, profile in profiles.items():
        promotion = profile.get("promotion")
        if not promotion or exercise_id not in exercises:
            continue
        source = candidates.get(promotion.get("source_catalog_id", ""), {})
        out.append({
            "exercise_id": exercise_id,
            "name": exercises[exercise_id].get("name", exercise_id),
            "source_catalog_id": promotion.get("source_catalog_id", ""),
            "category": source.get("category", ""),
            "revision_sha256": promotion.get("revision_sha256", ""),
            "promoted_at_unix": promotion.get("promoted_at_unix", 0),
        })
    return sorted(out, key=lambda e: -float(e["promoted_at_unix"] or 0))


def demote_exercise(exercise_id: str, reason: str, *, root: Path = PROJECT_ROOT,
                    now: Optional[float] = None, dry_run: bool = False) -> Dict[str, Any]:
    """Demote one council-promoted exercise. Returns a report; on failure
    ``ok`` is False with ``errors`` and nothing has been written."""
    try:
        return _demote(exercise_id, reason, root=Path(root), now=now, dry_run=dry_run)
    except PromotionError as exc:
        return {"ok": False, "demoter": DEMOTER_VERSION, "exercise_id": exercise_id, "errors": [str(exc)]}


def _demote(exercise_id: str, reason: str, *, root: Path, now, dry_run) -> Dict[str, Any]:
    reason = (reason or "").strip()
    if not reason:
        raise PromotionError("give a reason for the demotion; it is kept in the audit trail")

    paths = {name: root / rel for name, rel in REL_FOR.items()}
    current = {name: _read_json(path) for name, path in paths.items()}
    before_sha = {name: _sha256(path) for name, path in paths.items()}
    staged = copy.deepcopy(current)

    profile = staged["profiles"].get("profiles", {}).get(exercise_id)
    if profile is None or not any(e.get("id") == exercise_id for e in staged["exercises"]):
        raise PromotionError(f"{exercise_id} is not in the canonical catalog")
    promotion = profile.get("promotion")
    if not promotion:
        raise PromotionError(f"{exercise_id} was not promoted by the council (it is an original exercise); it can't be demoted here")
    revision_hash = promotion.get("revision_sha256", "")
    record_path = promotion_record_path(revision_hash, root)
    if not record_path.exists():
        raise PromotionError(f"no promotion record for revision {revision_hash[:12]}")
    demoted_at = time.time() if now is None else now

    staged["exercises"] = [e for e in staged["exercises"] if e.get("id") != exercise_id]
    del staged["profiles"]["profiles"][exercise_id]
    staged["media"] = [m for m in staged["media"] if m.get("exercise_id") != exercise_id]

    catalog_id = promotion.get("source_catalog_id", "")
    candidate = next((c for c in staged["candidates"] if c.get("catalog_id") == catalog_id), None)
    if candidate is None:
        raise PromotionError(f"source record {catalog_id} is not in the candidate catalog")
    candidate["body_sim_exercise_ids"] = [i for i in candidate.get("body_sim_exercise_ids", []) if i != exercise_id]
    if not candidate["body_sim_exercise_ids"]:
        candidate["status"] = "catalog_only"
    candidate.setdefault("demotions", []).append({
        "exercise_id": exercise_id, "revision_sha256": revision_hash,
        "reason": reason, "demoted_at_unix": demoted_at,
    })

    _validate_staged(staged, root)

    report = {
        "ok": True,
        "demoter": DEMOTER_VERSION,
        "exercise_id": exercise_id,
        "revision_sha256": revision_hash,
        "source_catalog_id": catalog_id,
        "source_status": candidate["status"],
        "reason": reason,
        "demoted_at_unix": demoted_at,
        "files_before_sha256": {REL_FOR[n]: s for n, s in before_sha.items()},
        "dry_run": dry_run,
    }
    if dry_run:
        return report

    exercises_raw = paths["exercises"].read_text(encoding="utf-8")
    exercises_text = "[\n" + ",\n".join("  " + _compact(_ordered(e, EXERCISE_KEY_ORDER), 2) for e in staged["exercises"]) \
        + "\n]" + exercises_raw[len(exercises_raw.rstrip()):]
    texts = {
        paths["exercises"]: exercises_text,
        paths["profiles"]: json.dumps(staged["profiles"], indent=2, ensure_ascii=False),
        paths["candidates"]: json.dumps(staged["candidates"], indent=2) + "\n",
        paths["media"]: json.dumps(staged["media"], indent=2, ensure_ascii=False) + "\n",
    }
    for path, text in texts.items():
        name = next(n for n, q in paths.items() if q == path)
        if json.loads(text) != staged[name]:
            raise PromotionError(f"internal error: serialized {path.name} does not match staged data")
    _atomic_write_all(texts, root)

    report["files_after_sha256"] = {REL_FOR[n]: _sha256(paths[n]) for n in paths}
    record = {k: v for k, v in report.items() if k != "dry_run"}
    record["promotion_record"] = _read_json(record_path)
    out_path = demotion_record_path(revision_hash, root)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    _write_json_atomic(out_path, record)
    record_path.unlink()
    report["record_path"] = str(out_path.relative_to(root))
    return report
