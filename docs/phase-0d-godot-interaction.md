# Phase 0D: Godot Whole-Body Interaction

Phase 0D turns the complete static asset into an inspectable anatomy application.
The runtime must preserve the canonical BodySim identity of all 960 structures while
visibility and presentation change.

## Editor-authored scene composition

Visible interface layout is stored in standalone Godot scenes rather than constructed
by runtime scripts:

- `scenes/anatomy/anatomy_browser_panel.tscn` owns anatomy search, details, and actions.
- `scenes/anatomy/anatomy_toolbar.tscn` owns layer toggles and camera presets.
- `scenes/exercises/exercise_selector.tscn` owns exercise search, grouping, and details.
- `scenes/anatomy/whole_body_preview.tscn` composes those controls with the authored
  camera rig, environment, lights, and canonical-body root.

Scripts connect behavior, load data, and populate dynamic tree rows. They must not
recreate visible controls with `Control.new()`; layout changes belong in the scene
editor.

## Implemented: manifest-backed search and selection

`src/anatomy/structure_registry.gd` loads `mesh_manifest.json`, indexes every record
by canonical ID, and binds those records to the exact `MeshInstance3D` imported from
the seven regional GLBs. Binding fails visibly for missing, duplicate, or unexplained
scene identities.

The whole-body preview now provides:

- Search across canonical name, ID, Latin name when available, and source object.
- A collapsible system and region tree containing all 960 structures, with explicit
  groups for muscles, bones, connective tissue/tendons, cartilage, teeth, and
  skeletal features.
- Deterministic search results across all 960 structures.
- Selection by stable canonical ID.
- Automatic camera focus on the selected mesh.
- Selected-structure highlighting.
- Hide and restore.
- Isolate and restore the whole body.
- Fade and unfade all other structures.
- Canonical name, ID, side, region, system, source, and license status display.
- Composition with the existing muscle, bone, cartilage, and connective-tissue
  visibility toggles.
- Independent surface-layer and deep-layer muscle controls backed by 466 explicit
  manifest classifications (160 superficial and 306 deep).
- A standalone signal-driven toolbar for anatomy layers and camera presets. Text
  labels and tooltips provide the current presentation while each button remains
  ready to receive a dedicated icon asset.
- Left-button orbit, right-button camera-space panning, and wheel zoom. Panning
  sensitivity scales with camera distance and cannot trigger structure selection.

## Implemented: direct mesh picking

`src/anatomy/mesh_picker.gd` performs direct click-on-model selection without
physics bodies or collision shapes:

1. The camera projects the pointer into a world-space ray.
2. Local mesh bounding boxes cheaply reject structures the ray cannot touch.
3. Candidate meshes receive a lazily generated Godot `TriangleMesh` BVH, cached by
   shared mesh resource identity.
4. Exact triangle hits are transformed back to world space and sorted nearest-first.
5. Repeated clicks at the same screen position cycle through overlapping and deeper
   structures.

Meshes authored at unusually small local coordinates are normalized before BVH
construction and their hit positions are converted back afterward. This avoids
precision misses found in the scaled manubrium and body of the sternum while leaving
ordinary meshes on Godot's direct fast path.

Hidden structures, disabled anatomy systems, and structures outside the current
isolation state are excluded because the picker checks effective scene visibility.
Pointer movement beyond five pixels is treated as orbiting rather than selection.

The current reference center-body ray produces 8 bounding-box candidates and 6 exact
surface hits. Its first cold query builds 7 shared BVHs; the cached query is required
by the automated test to complete in less than 16 milliseconds.

The Godot runtime test verifies that all 960 records bind to all 960 mesh nodes, and
exercises search, selection, hide, restore, isolation, fading, and clearing state.

## Phase 0D performance result

The windowed Godot 4.7.1 Vulkan benchmark passes every recorded budget with all 960
meshes loaded: 347.83 ms load-to-ready, 61,871,186 bytes incremental static memory,
60.00 average FPS, and a 16.726 ms 95th-percentile frame. The complete report is
[`../reports/phase0_performance.md`](../reports/phase0_performance.md).

Phase 0D is complete. Further iconography and visual polish are product iteration,
not coverage or interaction blockers.

Search selection already guarantees that even tiny, deep, or overlapping anatomy is
reachable. Direct picking supplements that exhaustive path rather than replacing
it.
