"""Extract the Phase 0A draft catalog from Z-Anatomy's open Startup.blend."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter, defaultdict
from dataclasses import replace
from pathlib import Path

import bpy


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from catalog_rules import (  # noqa: E402
    canonical_id,
    classify_system,
    infer_region,
    parse_source_name,
    review_flags,
    source_role,
)


SOURCE_ID = "z_anatomy_startup_blend"
SOURCE_URL = "https://github.com/Z-Anatomy/Models-of-human-anatomy"
TARGET_COLLECTIONS = (
    "1: Skeletal system",
    "2: Muscular insertions",
    "4: Muscular system",
)
CATALOG_COLLECTIONS = {"1: Skeletal system", "4: Muscular system"}
SCHEMA_VERSION = 1


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--source-archive-sha256")
    parser.add_argument("--source-blend-sha256")
    parser.add_argument("--curation", type=Path)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def digest_json(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def parent_chain(obj: bpy.types.Object) -> list[str]:
    result = []
    parent = obj.parent
    while parent is not None:
        result.append(parent.name)
        parent = parent.parent
    return result


def geometry_stats(obj: bpy.types.Object) -> dict[str, int]:
    if obj.type != "MESH":
        return {"vertices": 0, "edges": 0, "polygons": 0}
    return {
        "vertices": len(obj.data.vertices),
        "edges": len(obj.data.edges),
        "polygons": len(obj.data.polygons),
    }


def source_ref(entry: dict[str, object]) -> dict[str, object]:
    return {
        "source_id": SOURCE_ID,
        "source_collection": entry["collection"],
        "source_object": entry["source_name"],
        "source_data": entry["data_name"],
        "source_url": SOURCE_URL,
        "parent_chain": entry["parent_chain"],
        "geometry": entry["geometry"],
    }


def load_curation(root: Path, explicit_path: Path | None) -> dict[str, object]:
    path = explicit_path or root / "data/anatomy/catalog_curation.json"
    if not path.exists():
        return {"source_overrides": {}}
    return json.loads(path.read_text(encoding="utf-8"))


def extract_inventory() -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    inventory: list[dict[str, object]] = []
    missing_collections: list[dict[str, object]] = []
    for collection_name in TARGET_COLLECTIONS:
        collection = bpy.data.collections.get(collection_name)
        if collection is None:
            missing_collections.append({"collection": collection_name, "error": "missing"})
            continue
        for obj in sorted(collection.all_objects, key=lambda item: item.name):
            parsed = parse_source_name(obj.name)
            chain = parent_chain(obj)
            role = source_role(collection_name, obj.type, parsed)
            system = None
            region = None
            if collection_name in CATALOG_COLLECTIONS and role == "structure_candidate":
                system = classify_system(collection_name, parsed.base_name)
                region = infer_region(parsed.base_name, chain)
            inventory.append(
                {
                    "collection": collection_name,
                    "source_name": obj.name,
                    "object_type": obj.type,
                    "data_name": obj.data.name if obj.data else None,
                    "base_name": parsed.base_name,
                    "side": parsed.side,
                    "variant": parsed.variant,
                    "attachment_index": parsed.attachment_index,
                    "source_role": role,
                    "system_candidate": system,
                    "region_candidate": region,
                    "parent_chain": chain,
                    "object_collections": sorted(item.name for item in obj.users_collection),
                    "hidden_in_viewport": bool(obj.hide_viewport),
                    "hidden_in_render": bool(obj.hide_render),
                    "geometry": geometry_stats(obj),
                    "materials": sorted(
                        slot.material.name for slot in obj.material_slots if slot.material
                    ),
                }
            )
    inventory.sort(key=lambda item: (item["collection"], item["source_name"]))
    return inventory, missing_collections


def extract_whole_file_object_index() -> list[dict[str, object]]:
    return [
        {
            "source_name": obj.name,
            "object_type": obj.type,
            "data_name": obj.data.name if obj.data else None,
            "collections": sorted(collection.name for collection in obj.users_collection),
        }
        for obj in sorted(bpy.data.objects, key=lambda item: item.name)
    ]


def build_catalog(
    inventory: list[dict[str, object]], curation: dict[str, object]
) -> list[dict[str, object]]:
    candidates = [
        item
        for item in inventory
        if item["collection"] in CATALOG_COLLECTIONS
        and item["source_role"] == "structure_candidate"
    ]
    source_overrides = curation.get("source_overrides", {})
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for entry in candidates:
        override = source_overrides.get(entry["source_name"], {})
        sides = override.get("expand_sides", [override.get("side", entry["side"])])
        for side in sides:
            curated = dict(entry)
            curated["side"] = side
            curated["system_candidate"] = override.get("system", entry["system_candidate"])
            curated["region_candidate"] = override.get("region", entry["region_candidate"])
            curated["curation_note"] = override.get("note")
            curated["mesh_assignment_status"] = (
                "requires_separation" if len(sides) > 1 else "assigned"
            )
            identifier = canonical_id(
                str(curated["base_name"]),
                str(curated["system_candidate"]),
                str(curated["side"]),
            )
            grouped[identifier].append(curated)

    catalog = []
    for identifier in sorted(grouped):
        entries = sorted(grouped[identifier], key=lambda item: str(item["source_name"]))
        primary = entries[0]
        parsed = replace(
            parse_source_name(str(primary["source_name"])), side=str(primary["side"])
        )
        flags = review_flags(
            str(primary["source_name"]), parsed, str(primary["system_candidate"]),
            str(primary["region_candidate"]), len(entries)
        )
        override = source_overrides.get(primary["source_name"], {})
        flags = [flag for flag in flags if flag not in override.get("resolved_flags", [])]
        aliases = sorted(
            {str(item["source_name"]) for item in entries if item["source_name"] != primary["base_name"]}
        )
        catalog.append(
            {
                "id": identifier,
                "name": primary["base_name"],
                "latin_name": None,
                "aliases": aliases,
                "side": primary["side"],
                "system": primary["system_candidate"],
                "region": primary["region_candidate"],
                "parent_id": None,
                "source_taxonomy": [
                    parse_source_name(name).base_name
                    for name in primary["parent_chain"]
                    if name not in {"Skeletal system.g", "Muscular system.g"}
                ],
                "source_refs": [source_ref(item) for item in entries],
                "mesh_assignment_status": primary["mesh_assignment_status"],
                "curation_note": primary["curation_note"],
                "exercise_mapping_status": "not_yet_mapped",
                "confidence": "unreviewed",
                "review_status": "needs_review" if flags else "accepted",
                "review_flags": flags,
            }
        )
    assign_structure_parents(catalog, curation.get("parent_overrides", {}))
    return catalog


def assign_structure_parents(
    catalog: list[dict[str, object]], parent_overrides: dict[str, str]
) -> None:
    by_name: dict[str, list[dict[str, object]]] = defaultdict(list)
    for structure in catalog:
        by_name[str(structure["name"])].append(structure)
    for structure in catalog:
        structure["source_parent_candidate_id"] = None
        structure["parent_relation"] = None
        side = structure["side"]
        for parent_name in structure["source_taxonomy"]:
            matches = by_name.get(parent_name, [])
            same_side = [item for item in matches if item["side"] == side]
            if len(same_side) == 1:
                candidate_id = same_side[0]["id"]
                if candidate_id != structure["id"]:
                    structure["source_parent_candidate_id"] = candidate_id
                break
            if len(matches) == 1:
                candidate_id = matches[0]["id"]
                if candidate_id != structure["id"]:
                    structure["source_parent_candidate_id"] = candidate_id
                break
        approved_parent = parent_overrides.get(str(structure["id"]))
        if approved_parent:
            structure["parent_id"] = approved_parent
            structure["parent_relation"] = "part_of"


def summarize_inventory(inventory: list[dict[str, object]]) -> dict[str, object]:
    collection_counts: dict[str, dict[str, object]] = {}
    for collection_name in TARGET_COLLECTIONS:
        entries = [item for item in inventory if item["collection"] == collection_name]
        collection_counts[collection_name] = {
            "objects": len(entries),
            "object_types": dict(sorted(Counter(item["object_type"] for item in entries).items())),
            "source_roles": dict(sorted(Counter(item["source_role"] for item in entries).items())),
        }
    return {"objects": len(inventory), "collections": collection_counts}


def build_review(catalog: list[dict[str, object]], inventory: list[dict[str, object]]) -> dict[str, object]:
    flag_counts = Counter(flag for structure in catalog for flag in structure["review_flags"])
    review_items = [
        {
            "id": item["id"],
            "name": item["name"],
            "source_objects": [ref["source_object"] for ref in item["source_refs"]],
            "review_flags": item["review_flags"],
        }
        for item in catalog if item["review_flags"]
    ]
    return {
        "schema_version": SCHEMA_VERSION,
        "catalog_status": "curated_pending_external_review",
        "candidate_structures": len(catalog),
        "inventory_objects": len(inventory),
        "systems": dict(sorted(Counter(str(item["system"]) for item in catalog).items())),
        "regions": dict(sorted(Counter(str(item["region"]) for item in catalog).items())),
        "source_roles": dict(sorted(Counter(str(item["source_role"]) for item in inventory).items())),
        "review_flag_counts": dict(sorted(flag_counts.items())),
        "review_items": review_items,
    }


def write_review_markdown(path: Path, review: dict[str, object], catalog_sha: str) -> None:
    rows = [
        "# Phase 0A Catalog Review", "",
        "> This is a curated source-derived draft, not an anatomist-approved catalog.", "",
        f"- Candidate structures: **{review['candidate_structures']}**",
        f"- Source objects inventoried: **{review['inventory_objects']}**",
        f"- Catalog SHA-256: `{catalog_sha}`", "",
        "## Candidate counts by system", "", "| System | Count |", "|---|---:|",
    ]
    rows.extend(f"| {key} | {value} |" for key, value in review["systems"].items())
    rows.extend(["", "## Candidate counts by region", "", "| Region | Count |", "|---|---:|"])
    rows.extend(f"| {key} | {value} |" for key, value in review["regions"].items())
    rows.extend(["", "## Review queue", "", "| Flag | Structures |", "|---|---:|"])
    if review["review_flag_counts"]:
        rows.extend(f"| `{key}` | {value} |" for key, value in review["review_flag_counts"].items())
    else:
        rows.append("| None | 0 |")
    rows.extend([
        "", "Review flags are blockers for catalog approval. `source_taxonomy` preserves",
        "the complete source hierarchy, while `parent_id` is only assigned when a parent",
        "is itself a canonical structure and the relationship is approved in the curation",
        "file; group-only ancestry is not treated as missing.", "",
    ])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(rows), encoding="utf-8")


def main() -> None:
    args = parse_args()
    root = args.output_root.resolve()
    inventory, missing_collections = extract_inventory()
    whole_file_index = extract_whole_file_object_index()
    curation = load_curation(root, args.curation)
    catalog = build_catalog(inventory, curation)
    catalog_sha = digest_json(catalog)
    inventory_document = {
        "schema_version": SCHEMA_VERSION, "source_id": SOURCE_ID, "source_url": SOURCE_URL,
        "source_file": Path(bpy.data.filepath).name,
        "source_archive_sha256": args.source_archive_sha256,
        "source_blend_sha256": args.source_blend_sha256,
        "missing_required_collections": missing_collections,
        "summary": summarize_inventory(inventory), "objects": inventory,
    }
    catalog_document = {
        "schema_version": SCHEMA_VERSION,
        "catalog_status": "curated_pending_external_review",
        "generated_from": SOURCE_ID,
        "curation_version": curation.get("version"),
        "catalog_sha256": catalog_sha, "structures": catalog,
    }
    review = build_review(catalog, inventory)
    write_json(root / "data/anatomy/source/z_anatomy_inventory.json", inventory_document)
    write_json(
        root / "data/anatomy/source/z_anatomy_object_index.json",
        {
            "schema_version": SCHEMA_VERSION,
            "source_id": SOURCE_ID,
            "object_count": len(whole_file_index),
            "objects": whole_file_index,
        },
    )
    write_json(root / "data/anatomy/structures.json", catalog_document)
    write_json(root / "reports/phase0a_catalog_review.json", review)
    write_review_markdown(root / "reports/phase0a_catalog_review.md", review, catalog_sha)
    print(f"Phase 0A extraction complete: {len(inventory)} inventory objects, {len(catalog)} candidate structures")


if __name__ == "__main__":
    main()
