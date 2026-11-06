"""Validate canonical adult skeleton coverage against explicit requirements."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--requirements", type=Path, required=True)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    return parser.parse_args()


def load(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def run_audit(catalog: dict[str, object], requirements: dict[str, object]) -> dict[str, object]:
    identifiers = {item["id"] for item in catalog["structures"]}
    results = []
    for requirement in requirements["requirements"]:
        missing_ids = sorted(set(requirement.get("required_ids", [])) - identifiers)
        pattern = requirement.get("id_regex")
        matches = sorted(item for item in identifiers if pattern and re.search(pattern, item))
        count_matches = requirement.get("exact_count") in (None, len(matches))
        status = "pass" if not missing_ids and count_matches else "fail"
        results.append(
            {
                "id": requirement["id"],
                "status": status,
                "missing_ids": missing_ids,
                "expected_count": requirement.get("exact_count"),
                "matched_count": len(matches) if pattern else len(requirement.get("required_ids", [])) - len(missing_ids),
                "matched_ids": matches,
            }
        )
    failures = [item for item in results if item["status"] == "fail"]
    return {
        "schema_version": 1,
        "catalog_sha256": catalog["catalog_sha256"],
        "requirements_audited": len(results),
        "requirements_passed": len(results) - len(failures),
        "release_blocking_failures": len(failures),
        "results": results,
        "sources": requirements["sources"],
    }


def write_markdown(path: Path, report: dict[str, object]) -> None:
    rows = [
        "# Phase 0A External Skeleton Coverage Audit", "",
        f"- Requirements passed: **{report['requirements_passed']} / {report['requirements_audited']}**",
        f"- Release-blocking failures: **{report['release_blocking_failures']}**", "",
        "| Requirement | Status | Matched | Expected |", "|---|---|---:|---:|",
    ]
    for item in report["results"]:
        expected = item["expected_count"] if item["expected_count"] is not None else "all IDs"
        rows.append(f"| `{item['id']}` | {item['status']} | {item['matched_count']} | {expected} |")
    rows.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(rows), encoding="utf-8")


def main() -> None:
    args = parse_args()
    report = run_audit(load(args.catalog), load(args.requirements))
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(args.output_md, report)
    print(f"Skeleton coverage: {report['requirements_passed']}/{report['requirements_audited']} requirements passed")


if __name__ == "__main__":
    main()
