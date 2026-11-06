"""Audit the seven canonical regional GLBs against the catalog partition."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path


REGION_ORDER = [
    "head_neck",
    "torso",
    "pelvis",
    "upper_limb_left",
    "upper_limb_right",
    "lower_limb_left",
    "lower_limb_right",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--asset-dir", type=Path, required=True)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    return parser.parse_args()


def asset_region(structure: dict[str, object]) -> str:
    region = structure["region"]
    return f"{region}_{structure['side']}" if region in {"upper_limb", "lower_limb"} else region


def read_glb(path: Path) -> tuple[bytes, dict[str, object]]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or length != len(data):
        raise ValueError(f"Invalid GLB header: {path}")
    json_length, json_type = struct.unpack_from("<II", data, 12)
    if json_type != 0x4E4F534A:
        raise ValueError(f"GLB first chunk is not JSON: {path}")
    return data, json.loads(data[20 : 20 + json_length].decode("utf-8"))


def markdown(report: dict[str, object]) -> str:
    rows = [
        "# Phase 0B Regional Asset Export",
        "",
        f"- Regional GLBs: **{report['assets_passed']}/{report['assets_expected']}**",
        f"- Canonical structures: **{report['structures_found']}/{report['structures_expected']}**",
        f"- Duplicate or misplaced IDs: **{report['identity_failures']}**",
        f"- Total generated size: **{report['total_bytes']:,} bytes**",
        "",
        "| Asset | Structures | Bytes | SHA-256 |",
        "|---|---:|---:|---|",
    ]
    for region in REGION_ORDER:
        item = report["assets"][region]
        rows.append(f"| `{region}.glb` | {item['structure_nodes']} | {item['bytes']:,} | `{item['sha256']}` |")
    rows.extend([
        "",
        "Every canonical ID occurs in exactly one regional asset and every structure node",
        "has renderable geometry plus its BodySim identity metadata.",
        "",
    ])
    return "\n".join(rows)


def main() -> None:
    args = parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    expected_by_region: dict[str, set[str]] = {region: set() for region in REGION_ORDER}
    for structure in catalog["structures"]:
        expected_by_region[asset_region(structure)].add(structure["id"])

    assets = {}
    all_ids: list[str] = []
    failures: list[str] = []
    for region in REGION_ORDER:
        path = args.asset_dir / f"{region}.glb"
        data, document = read_glb(path)
        nodes = [node for node in document.get("nodes", []) if node.get("extras", {}).get("bodysim_id")]
        ids = [node["extras"]["bodysim_id"] for node in nodes]
        missing_mesh = [node["extras"]["bodysim_id"] for node in nodes if "mesh" not in node]
        expected = expected_by_region[region]
        if set(ids) != expected or len(ids) != len(expected):
            failures.append(f"{region}: expected {len(expected)} unique IDs, found {len(ids)}")
        if missing_mesh:
            failures.append(f"{region}: {len(missing_mesh)} structure nodes have no mesh")
        all_ids.extend(ids)
        assets[region] = {
            "path": path.as_posix(),
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "structure_nodes": len(nodes),
            "unique_meshes": len(document.get("meshes", [])),
        }

    duplicate_ids = sorted(item for item, count in Counter(all_ids).items() if count != 1)
    expected_ids = {item["id"] for item in catalog["structures"]}
    if set(all_ids) != expected_ids:
        failures.append("Combined regional IDs differ from the canonical catalog")
    failures.extend(f"Duplicate regional identity: {item}" for item in duplicate_ids)
    if failures:
        raise ValueError("; ".join(failures))

    report = {
        "schema_version": 1,
        "catalog_sha256": catalog["catalog_sha256"],
        "assets_expected": len(REGION_ORDER),
        "assets_passed": len(assets),
        "structures_expected": len(catalog["structures"]),
        "structures_found": len(all_ids),
        "identity_failures": 0,
        "total_bytes": sum(item["bytes"] for item in assets.values()),
        "assets": assets,
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.output_md.parent.mkdir(parents=True, exist_ok=True)
    args.output_md.write_text(markdown(report), encoding="utf-8")
    print(f"Regional GLB audit passed: {len(all_ids)} structures across {len(assets)} assets")


if __name__ == "__main__":
    main()
