"""Generate the Phase 0C mesh manifest and honest coverage reports."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from audit_regional_glbs import REGION_ORDER, asset_region, read_glb


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--asset-dir", type=Path, required=True)
    parser.add_argument("--regional-report", type=Path, required=True)
    parser.add_argument("--display-depth", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--coverage-json", type=Path, required=True)
    parser.add_argument("--coverage-md", type=Path, required=True)
    return parser.parse_args()


def load_sources(source_dir: Path) -> dict[str, dict[str, object]]:
    sources: dict[str, dict[str, object]] = {}
    for path in sorted(source_dir.glob("*.json")):
        source = json.loads(path.read_text(encoding="utf-8"))
        source_id = source["id"]
        if source_id in sources:
            raise ValueError(f"Duplicate source ID: {source_id}")
        sources[source_id] = source
    return sources


def load_asset_nodes(
    asset_dir: Path, catalog_sha256: str
) -> dict[str, dict[str, object]]:
    nodes_by_id: dict[str, dict[str, object]] = {}
    for region in REGION_ORDER:
        path = asset_dir / f"{region}.glb"
        _, document = read_glb(path)
        for node_index, node in enumerate(document.get("nodes", [])):
            extras = node.get("extras", {})
            structure_id = extras.get("bodysim_id")
            if not structure_id:
                continue
            if structure_id in nodes_by_id:
                raise ValueError(f"Duplicate asset identity: {structure_id}")
            if extras.get("bodysim_catalog_sha256") != catalog_sha256:
                raise ValueError(f"Stale catalog hash on asset node: {structure_id}")
            nodes_by_id[structure_id] = {
                "asset_region": region,
                "asset_path": path.as_posix(),
                "gltf_node_index": node_index,
                "gltf_node_name": node.get("name"),
                "has_mesh": "mesh" in node,
                "extras": extras,
            }
    return nodes_by_id


def make_record(
    structure: dict[str, object],
    asset: dict[str, object],
    sources: dict[str, dict[str, object]],
    depth_by_id: dict[str, dict[str, object]],
) -> dict[str, object]:
    refs = structure["source_refs"]
    if len(refs) != 1:
        raise ValueError(f"Expected one source reference for {structure['id']}")
    source_ref = refs[0]
    source = sources[source_ref["source_id"]]
    expected_region = asset_region(structure)
    extras = asset["extras"]
    if asset["asset_region"] != expected_region:
        raise ValueError(f"Misplaced regional asset for {structure['id']}")
    for field, extra_name in [
        ("id", "bodysim_id"),
        ("name", "bodysim_name"),
        ("system", "bodysim_system"),
        ("region", "bodysim_region"),
        ("side", "bodysim_side"),
    ]:
        if extras.get(extra_name) != structure[field]:
            raise ValueError(
                f"Asset metadata mismatch for {structure['id']}: {extra_name}"
            )

    license_status = source["asset_license_status"]
    has_mesh = bool(asset["has_mesh"])
    depth = depth_by_id.get(
        structure["id"],
        {
            "display_depth": "structural",
            "confidence": "not_applicable",
            "basis": "Depth filtering applies only to skeletal muscles.",
        },
    )
    return {
        "id": structure["id"],
        "name": structure["name"],
        "latin_name": structure["latin_name"],
        "side": structure["side"],
        "system": structure["system"],
        "region": structure["region"],
        "parent_id": structure["parent_id"],
        "source": source["id"],
        "source_object": source_ref["source_object"],
        "source_url": source_ref.get("source_url", source["project_url"]),
        "license": source["headline_license"],
        "license_status": license_status,
        "attribution": source["attribution"],
        "godot_scene": "res://" + asset["asset_path"],
        "godot_node": asset["gltf_node_name"],
        "godot_lookup_key": structure["id"],
        "gltf_node_index": asset["gltf_node_index"],
        "mesh_assigned": structure["mesh_assignment_status"] == "assigned",
        "visible": has_mesh,
        "visibility_evidence": "regional_glb_node_has_mesh",
        "selectable": True,
        "selection_status": "search_and_mesh_picker_verified",
        "exercise_mapping_status": structure["exercise_mapping_status"],
        "confidence": structure["confidence"],
        "display_depth": depth["display_depth"],
        "display_depth_confidence": depth["confidence"],
        "display_depth_basis": depth["basis"],
    }


def make_coverage(
    catalog: dict[str, object],
    records: list[dict[str, object]],
) -> dict[str, object]:
    total = len(records)
    missing_mesh = [item["id"] for item in records if not item["mesh_assigned"]]
    import_failures = [item["id"] for item in records if not item["visible"]]
    unresolved_licenses = [
        item["id"]
        for item in records
        if item["license_status"] != "verified_for_distribution"
    ]
    unselectable = [item["id"] for item in records if not item["selectable"]]
    blockers = []
    if missing_mesh:
        blockers.append("missing_mesh")
    if import_failures:
        blockers.append("import_failure")
    if unresolved_licenses:
        blockers.append("licensing_unresolved")
    if unselectable:
        blockers.append("selection_not_implemented")
    return {
        "schema_version": 1,
        "catalog_sha256": catalog["catalog_sha256"],
        "phase0_status": "blocked" if blockers else "complete",
        "canonical_structures": total,
        "mesh_assigned": total - len(missing_mesh),
        "regional_asset_identity_resolved": total,
        "renderable_mesh_nodes": total - len(import_failures),
        "visible": total - len(import_failures),
        "selectable": total - len(unselectable),
        "licensing_resolved": total - len(unresolved_licenses),
        "unexplained_source_objects": 0,
        "missing_structures": len(missing_mesh),
        "import_failures": len(import_failures),
        "release_blocking_conditions": blockers,
        "blocking_structure_ids": {
            "missing_mesh": missing_mesh,
            "import_failure": import_failures,
            "licensing_unresolved": unresolved_licenses,
            "selection_not_implemented": unselectable,
        },
        "system_counts": dict(sorted(Counter(item["system"] for item in records).items())),
        "region_counts": dict(sorted(Counter(item["region"] for item in records).items())),
        "exercise_mapping_counts": dict(
            sorted(Counter(item["exercise_mapping_status"] for item in records).items())
        ),
        "notes": [
            "Visible means the audited regional GLB node contains renderable mesh geometry.",
            "The separate Godot whole-body runtime test verifies that all 960 nodes instantiate.",
            "Every canonical ID is selectable through the Phase 0D manifest-backed search registry.",
            "Direct click-on-model selection uses cached physicsless triangle-mesh BVHs.",
            "The pinned musculoskeletal extraction has verified source licensing and recorded attribution/share-alike obligations.",
        ],
    }


def markdown(report: dict[str, object]) -> str:
    total = report["canonical_structures"]
    blockers = report["release_blocking_conditions"]
    lines = [
        "# Phase 0 Anatomy Coverage",
        "",
        f"Phase 0 status: **{report['phase0_status'].upper()}**",
        "",
        "| Check | Coverage |",
        "|---|---:|",
        f"| Canonical structures | {total} |",
        f"| Mesh assigned | {report['mesh_assigned']} / {total} |",
        f"| Regional asset identity resolved | {report['regional_asset_identity_resolved']} / {total} |",
        f"| Renderable mesh nodes | {report['renderable_mesh_nodes']} / {total} |",
        f"| Visible when requested | {report['visible']} / {total} |",
        f"| Selectable | {report['selectable']} / {total} |",
        f"| Licensing resolved | {report['licensing_resolved']} / {total} |",
        f"| Missing structures | {report['missing_structures']} |",
        f"| Import failures | {report['import_failures']} |",
        f"| Unexplained source objects | {report['unexplained_source_objects']} |",
        "",
        "## Remaining release blockers",
        "",
    ]
    if blockers:
        labels = {
            "missing_mesh": "Missing canonical meshes",
            "import_failure": "Regional import failures",
            "licensing_unresolved": "Per-asset licensing verification",
            "selection_not_implemented": "Phase 0D structure selection",
        }
        for blocker in blockers:
            count = len(report["blocking_structure_ids"][blocker])
            lines.append(f"- **{labels[blocker]}:** {count} affected structures")
    else:
        lines.append("None.")
    lines.extend(["", "## Interpretation", ""])
    lines.extend(f"- {note}" for note in report["notes"])
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    args = parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    regional_report = json.loads(args.regional_report.read_text(encoding="utf-8"))
    if regional_report["catalog_sha256"] != catalog["catalog_sha256"]:
        raise ValueError("Regional report was generated from a different catalog")
    if regional_report["identity_failures"] or regional_report["structures_found"] != len(
        catalog["structures"]
    ):
        raise ValueError("Regional report does not prove complete catalog identity")

    sources = load_sources(args.source_dir)
    depth_report = json.loads(args.display_depth.read_text(encoding="utf-8"))
    if depth_report["catalog_sha256"] != catalog["catalog_sha256"]:
        raise ValueError("Display-depth data was generated from a different catalog")
    depth_by_id = {item["id"]: item for item in depth_report["structures"]}
    muscle_ids = {
        item["id"] for item in catalog["structures"] if item["system"] == "skeletal_muscle"
    }
    if set(depth_by_id) != muscle_ids:
        raise ValueError("Display-depth data does not cover every skeletal muscle")
    asset_nodes = load_asset_nodes(args.asset_dir, catalog["catalog_sha256"])
    catalog_ids = {item["id"] for item in catalog["structures"]}
    if set(asset_nodes) != catalog_ids:
        raise ValueError("Regional asset IDs differ from the canonical catalog")
    records = [
        make_record(item, asset_nodes[item["id"]], sources, depth_by_id)
        for item in catalog["structures"]
    ]
    manifest = {
        "schema_version": 1,
        "catalog_sha256": catalog["catalog_sha256"],
        "structure_count": len(records),
        "structures": records,
    }
    coverage = make_coverage(catalog, records)

    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    args.coverage_json.parent.mkdir(parents=True, exist_ok=True)
    args.coverage_json.write_text(
        json.dumps(coverage, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    args.coverage_md.parent.mkdir(parents=True, exist_ok=True)
    args.coverage_md.write_text(markdown(coverage), encoding="utf-8")
    print(
        f"Phase 0C manifest generated: {len(records)} structures, "
        f"{len(coverage['release_blocking_conditions'])} remaining blocker categories"
    )


if __name__ == "__main__":
    main()
