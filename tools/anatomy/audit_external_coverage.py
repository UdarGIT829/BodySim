"""Compare the BodySim catalog with an independent muscle terminology list."""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path


NON_ALNUM_RE = re.compile(r"[^a-z0-9]+")
IGNORED_WORDS_RE = re.compile(r"\b(muscle|muscles|muscular)\b")
TOKEN_EQUIVALENTS = {
    "cervicis": "colli",
    "cervical": "colli",
    "lumbricals": "lumbrical",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--dispositions", type=Path)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def normalize(value: str) -> str:
    ascii_value = (
        unicodedata.normalize("NFKD", value)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
    )
    without_generic = IGNORED_WORDS_RE.sub(" ", ascii_value)
    tokens = NON_ALNUM_RE.sub(" ", without_generic).split()
    return " ".join(TOKEN_EQUIVALENTS.get(token, token) for token in tokens)


def automatic_matches(term: dict[str, object], structures: list[dict[str, object]]) -> list[str]:
    aliases = [normalize(str(alias)) for alias in term["english_aliases"]]
    matches = []
    for structure in structures:
        if structure["system"] != "skeletal_muscle":
            continue
        names = [structure["name"], *structure.get("aliases", [])]
        normalized_names = [normalize(str(name)) for name in names]
        if any(names_match(alias, name) for alias in aliases for name in normalized_names):
            matches.append(str(structure["id"]))
    return sorted(set(matches))


def names_match(reference_name: str, catalog_name: str) -> bool:
    if reference_name == catalog_name:
        return True
    reference_tokens = set(reference_name.split())
    catalog_tokens = set(catalog_name.split())
    if len(reference_tokens) == 1:
        token = next(iter(reference_tokens))
        return len(token) >= 5 and token in catalog_tokens
    return reference_tokens.issubset(catalog_tokens)


def audit(
    catalog: dict[str, object], reference: dict[str, object], dispositions: dict[str, object]
) -> dict[str, object]:
    structures = catalog["structures"]
    known_ids = {item["id"] for item in structures}
    results = []
    for term in reference["terms"]:
        matches = automatic_matches(term, structures)
        disposition = dispositions.get(term["code"])
        if disposition:
            evidence_ids = disposition.get("evidence_ids", [])
            missing_evidence = sorted(set(evidence_ids) - known_ids)
            if missing_evidence:
                raise ValueError(
                    f"Disposition {term['code']} references missing IDs: {missing_evidence}"
                )
            status = disposition["status"]
            evidence = evidence_ids
            note = disposition.get("note")
        elif matches:
            status = "represented"
            evidence = matches
            note = None
        elif term["optional_or_variable"]:
            status = "optional_not_represented"
            evidence = []
            note = None
        else:
            status = "unresolved"
            evidence = []
            note = None
        results.append({**term, "status": status, "evidence_ids": evidence, "note": note})
    status_counts = Counter(item["status"] for item in results)
    blocking_statuses = {"unresolved", "confirmed_source_gap"}
    return {
        "schema_version": 1,
        "catalog_sha256": catalog["catalog_sha256"],
        "reference_source": reference["source"],
        "terms_audited": len(results),
        "status_counts": dict(sorted(status_counts.items())),
        "release_blocking_gaps": sum(
            1 for item in results if item["status"] in blocking_statuses
        ),
        "results": results,
    }


def write_markdown(path: Path, report: dict[str, object]) -> None:
    rows = [
        "# Phase 0A External Muscle Coverage Audit", "",
        f"- Official terms audited: **{report['terms_audited']}**",
        f"- Release-blocking gaps: **{report['release_blocking_gaps']}**",
        "", "## Status summary", "", "| Status | Count |", "|---|---:|",
    ]
    rows.extend(f"| `{key}` | {value} |" for key, value in report["status_counts"].items())
    unresolved = [item for item in report["results"] if item["status"] == "unresolved"]
    rows.extend(["", "## Unresolved required terms", ""])
    if unresolved:
        rows.extend(["| Code | Official English term |", "|---|---|"])
        rows.extend(f"| `{item['code']}` | {item['english']} |" for item in unresolved)
    else:
        rows.append("None.")
    confirmed = [
        item for item in report["results"] if item["status"] == "confirmed_source_gap"
    ]
    rows.extend(["", "## Confirmed source gaps", ""])
    if confirmed:
        rows.extend(["| Code | Official English term | Finding |", "|---|---|---|"])
        rows.extend(
            f"| `{item['code']}` | {item['english']} | {item['note']} |"
            for item in confirmed
        )
    else:
        rows.append("None.")
    excluded = [
        item
        for item in report["results"]
        if item["status"] == "excluded_phase0_reference_only"
    ]
    rows.extend(["", "## Explicit Phase 0 scope exclusions", ""])
    if excluded:
        rows.extend(["| Code | Official English term | Finding |", "|---|---|---|"])
        rows.extend(
            f"| `{item['code']}` | {item['english']} | {item['note']} |"
            for item in excluded
        )
    else:
        rows.append("None.")
    rows.extend([
        "", "An unresolved term is not automatically a missing mesh. It must be classified",
        "as a naming mismatch, represented by finer-grained components, outside the",
        "canonical scope, an accepted anatomical variant, a confirmed coverage gap, or an",
        "explicit non-blocking product-scope exclusion. Exclusions are not represented anatomy.", "",
    ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(rows), encoding="utf-8")


def main() -> None:
    args = parse_args()
    catalog = load_json(args.catalog)
    reference = load_json(args.reference)
    dispositions = (
        load_json(args.dispositions).get("dispositions", {})
        if args.dispositions and args.dispositions.exists() else {}
    )
    report = audit(catalog, reference, dispositions)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(report, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    write_markdown(args.output_md, report)
    print(
        f"Audited {report['terms_audited']} terms; "
        f"{report['release_blocking_gaps']} release-blocking gaps"
    )


if __name__ == "__main__":
    main()
