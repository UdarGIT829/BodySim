"""Export the canonical catalog as seven deterministic regional GLBs."""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import bpy


REGION_ORDER = [
    "head_neck",
    "torso",
    "pelvis",
    "upper_limb_left",
    "upper_limb_right",
    "lower_limb_left",
    "lower_limb_right",
]


def blender_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    return parser.parse_args(blender_args())


def asset_region(structure: dict[str, object]) -> str:
    region = str(structure["region"])
    if region in {"upper_limb", "lower_limb"}:
        side = structure.get("side")
        if side not in {"left", "right"}:
            raise RuntimeError(f"Limb structure has no exportable side: {structure['id']}")
        return f"{region}_{side}"
    if region not in {"head_neck", "torso", "pelvis"}:
        raise RuntimeError(f"Unknown canonical region for {structure['id']}: {region}")
    return region


def main() -> None:
    args = parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    structures = catalog["structures"]
    groups: dict[str, list[tuple[bpy.types.Object, dict[str, object]]]] = defaultdict(list)
    source_names: set[str] = set()

    for structure in structures:
        if len(structure["source_refs"]) != 1:
            raise RuntimeError(f"Regional export expects one source object for {structure['id']}")
        source_name = structure["source_refs"][0]["source_object"]
        if source_name in source_names:
            raise RuntimeError(f"Source object assigned twice: {source_name}")
        source_names.add(source_name)
        obj = bpy.data.objects.get(source_name)
        if obj is None:
            raise RuntimeError(f"Canonical source object is missing: {source_name}")
        if obj.type != "MESH":
            raise RuntimeError(f"Catalog object is not a mesh: {source_name} ({obj.type})")
        groups[asset_region(structure)].append((obj, structure))

    if set(groups) != set(REGION_ORDER):
        raise RuntimeError(f"Regional partition mismatch: {sorted(groups)}")

    bpy.ops.object.select_all(action="DESELECT")
    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked_modifier_meshes = 0
    for region in REGION_ORDER:
        for obj, structure in groups[region]:
            if len(obj.data.polygons) == 0:
                evaluated = obj.evaluated_get(depsgraph)
                baked_mesh = bpy.data.meshes.new_from_object(
                    evaluated,
                    preserve_all_data_layers=False,
                    depsgraph=depsgraph,
                )
                if len(baked_mesh.polygons) == 0:
                    raise RuntimeError(f"Modifiers produced no surface for {obj.name}")
                obj.data = baked_mesh
                obj.modifiers.clear()
                baked_modifier_meshes += 1
            world = obj.matrix_world.copy()
            # Selection export includes hierarchy descendants even when those descendants
            # are not selected. Detach every canonical object from the source hierarchy so
            # a regional selection is a hard asset boundary rather than a recursive hint.
            obj.parent = None
            obj.matrix_world = world
            obj.hide_set(False)
            obj.hide_viewport = False
            obj.hide_render = False
            obj.name = structure["id"]
            obj["bodysim_id"] = structure["id"]
            obj["bodysim_name"] = structure["name"]
            obj["bodysim_asset_region"] = region
            obj["bodysim_catalog_sha256"] = catalog["catalog_sha256"]
            obj["bodysim_system"] = structure["system"]
            obj["bodysim_region"] = structure["region"]
            obj["bodysim_side"] = structure["side"] or "none"

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for region in REGION_ORDER:
        # Source selection state is unreliable for initially hidden atlas objects.
        # Make the export boundary explicit through renderability instead.
        for scene_obj in bpy.context.scene.objects:
            scene_obj.hide_render = True
        for obj, _structure in groups[region]:
            obj.hide_render = False
        bpy.ops.export_scene.gltf(
            filepath=str((args.output_dir / f"{region}.glb").resolve()),
            export_format="GLB",
            use_selection=False,
            use_renderable=True,
            export_extras=True,
            export_materials="NONE",
            export_cameras=False,
            export_lights=False,
            export_animations=False,
            export_attributes=False,
            export_skins=False,
            export_morph=False,
        )
        print(f"Exported {region}: {len(groups[region])} structures")

    print(
        f"Exported {len(structures)} canonical structures across {len(REGION_ORDER)} regions; "
        f"baked {baked_modifier_meshes} modifier-generated surfaces"
    )


if __name__ == "__main__":
    main()
