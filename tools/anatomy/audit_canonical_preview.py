"""Audit the complete canonical GLB used by the Godot whole-body preview."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--canonical-glb", type=Path, required=True)
    parser.add_argument("--exclusions", type=Path, required=True)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    return parser.parse_args()


def read_glb(path: Path) -> tuple[bytes, dict[str, object]]:
    data = path.read_bytes()
    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total_length != len(data):
        raise ValueError(f"Invalid glTF 2.0 binary: {path}")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != 0x4E4F534A:
        raise ValueError(f"GLB first chunk is not JSON: {path}")
    return data, json.loads(data[20 : 20 + json_length].decode("utf-8"))


def markdown(report: dict[str, object]) -> str:
    return "\n".join(
        [
            "# Phase 0A Canonical Whole-Body Preview",
            "",
            f"- Canonical structures rendered: **{report['canonical_mesh_nodes']}/{report['catalog_structures']}**",
            f"- GLB size: **{report['canonical_glb_bytes']:,} bytes**",
            f"- GLB SHA-256: `{report['canonical_glb_sha256']}`",
            f"- Asset role: **{report['asset_role']}**",
            f"- Explicit non-blocking terminology exclusions: **{report['scope_exclusions']}**",
            "",
            "Every structure in the approved baseline catalog has its own renderable Godot",
            "mesh node. The whole-body preview exposes independent muscle, bone/feature,",
            "cartilage, and connective-tissue layers.",
            "",
            "The 42 external terminology terms recorded in",
            "`data/anatomy/phase0_scope_exclusions.json` are outside the canonical product",
            "scope. They are not counted as represented and no fallback geometry is shipped.",
            "",
        ]
    )


def main() -> None:
    args = parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    exclusions = json.loads(args.exclusions.read_text(encoding="utf-8"))
    glb_data, glb = read_glb(args.canonical_glb)
    nodes = [node for node in glb.get("nodes", []) if node.get("extras", {}).get("bodysim_id")]
    mesh_nodes = sum("mesh" in node for node in nodes)
    expected = len(catalog["structures"])
    if len(nodes) != expected or mesh_nodes != expected:
        raise ValueError(f"Canonical preview coverage failed: nodes={len(nodes)}, meshes={mesh_nodes}, expected={expected}")
    if exclusions["excluded_term_count"] != len(exclusions["excluded_terms"]):
        raise ValueError("Scope exclusion count does not match its term ledger")

    report = {
        "schema_version": 1,
        "catalog_structures": expected,
        "catalog_system_counts": dict(sorted(Counter(item["system"] for item in catalog["structures"]).items())),
        "canonical_structure_nodes": len(nodes),
        "canonical_mesh_nodes": mesh_nodes,
        "canonical_unique_meshes": len(glb.get("meshes", [])),
        "canonical_glb_path": args.canonical_glb.as_posix(),
        "canonical_glb_bytes": len(glb_data),
        "canonical_glb_sha256": hashlib.sha256(glb_data).hexdigest(),
        "scope_exclusions": exclusions["excluded_term_count"],
        "scope_exclusion_status": exclusions["status"],
        "asset_role": "monolithic_catalog_extraction_check",
        "runtime_pipeline": "phase0b_regional_glbs",
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    args.output_md.write_text(markdown(report), encoding="utf-8")
    print(f"Canonical preview contract passed: {mesh_nodes}/{expected} meshes")


if __name__ == "__main__":
    main()
