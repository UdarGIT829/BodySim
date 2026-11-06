"""Export the complete cataloged Z-Anatomy body for local alignment preview."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import bpy


def blender_args() -> list[str]:
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(blender_args())


def main() -> None:
    args = parse_args()
    catalog = json.loads(args.catalog.read_text(encoding="utf-8"))
    structures = catalog["structures"]
    source_to_structure = {}
    for structure in structures:
        if len(structure["source_refs"]) != 1:
            raise RuntimeError(f"Preview export expects one source object for {structure['id']}")
        source_name = structure["source_refs"][0]["source_object"]
        if source_name in source_to_structure:
            raise RuntimeError(f"Source object assigned twice: {source_name}")
        source_to_structure[source_name] = structure

    missing = sorted(name for name in source_to_structure if bpy.data.objects.get(name) is None)
    if missing:
        raise RuntimeError(f"Canonical blend lacks {len(missing)} catalog objects: {missing[:10]}")

    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.new("BodySim_Canonical_Preview", None)
    bpy.context.scene.collection.objects.link(root)
    root["bodysim_catalog_sha256"] = catalog["catalog_sha256"]
    root["bodysim_catalog_status"] = catalog["catalog_status"]
    root.select_set(True)

    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked_modifier_meshes = 0

    for source_name, structure in source_to_structure.items():
        obj = bpy.data.objects[source_name]
        if obj.type != "MESH":
            raise RuntimeError(f"Catalog object is not a mesh: {source_name} ({obj.type})")
        # glTF ignores edge-only base meshes even when their Skin/Subdivision stack
        # produces the intended anatomical surface. Bake those 14 catalog members
        # explicitly so every catalog structure remains renderable in Godot.
        if len(obj.data.polygons) == 0:
            evaluated = obj.evaluated_get(depsgraph)
            baked_mesh = bpy.data.meshes.new_from_object(
                evaluated,
                preserve_all_data_layers=False,
                depsgraph=depsgraph,
            )
            if len(baked_mesh.polygons) == 0:
                raise RuntimeError(f"Modifiers produced no surface for catalog object: {source_name}")
            obj.data = baked_mesh
            obj.modifiers.clear()
            baked_modifier_meshes += 1
        world = obj.matrix_world.copy()
        obj.parent = root
        obj.matrix_world = world
        obj.hide_set(False)
        obj.hide_viewport = False
        obj.hide_render = False
        obj.name = structure["id"]
        obj["bodysim_id"] = structure["id"]
        obj["bodysim_name"] = structure["name"]
        obj["bodysim_system"] = structure["system"]
        obj["bodysim_side"] = structure["side"] or "none"
        obj.select_set(True)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(args.output.resolve()),
        export_format="GLB",
        use_selection=True,
        export_extras=True,
        export_materials="NONE",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_attributes=False,
        export_skins=False,
        export_morph=False,
    )
    print(
        f"Exported canonical preview: {len(structures)} structures / "
        f"{sum(item['source_refs'][0]['geometry']['polygons'] for item in structures)} source polygons / "
        f"{baked_modifier_meshes} modifier-generated surfaces baked"
    )


if __name__ == "__main__":
    main()
