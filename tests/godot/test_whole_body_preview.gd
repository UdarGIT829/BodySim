extends SceneTree

const PREVIEW_SCENE := "res://scenes/anatomy/whole_body_preview.tscn"
const MESH_PICKER := preload("res://src/anatomy/mesh_picker.gd")
var failures: Array[String] = []


class FakeRegistry extends RefCounted:
	var ordered_ids: Array[String] = []
	var nodes_by_id: Dictionary = {}

	func get_structure_node(structure_id: String) -> MeshInstance3D:
		return nodes_by_id.get(structure_id) as MeshInstance3D


func _initialize() -> void:
	call_deferred("run_test")


func run_test() -> void:
	var packed := load(PREVIEW_SCENE) as PackedScene
	require(packed != null, "Whole-body preview scene must load")
	var preview = packed.instantiate()
	root.add_child(preview)
	for frame in range(3):
		await process_frame
	var canonical = preview.get_node_or_null("CanonicalBody")
	require(canonical != null, "Canonical body must instantiate")
	require(preview.count_meshes(canonical) == 960, "Canonical layer must render all 960 catalog structures")
	var expected_regions := {
		"HeadNeck": 288,
		"Torso": 186,
		"Pelvis": 16,
		"UpperLimbLeft": 97,
		"UpperLimbRight": 97,
		"LowerLimbLeft": 138,
		"LowerLimbRight": 138,
	}
	for region_name in expected_regions:
		var region = canonical.get_node_or_null(region_name)
		require(region != null, "Regional asset must instantiate: %s" % region_name)
		if region != null:
			require(preview.count_meshes(region) == expected_regions[region_name], "%s structure count must match the catalog partition" % region_name)

	require(preview.registry != null, "Structure registry must load")
	require(preview.registry.records_by_id.size() == 960, "Registry must contain all 960 manifest records")
	require(preview.registry.nodes_by_id.size() == 960, "Registry must bind all 960 scene nodes")
	require(preview.registry.is_complete(), "Registry must have one scene node per manifest record")
	require(preview.search_result_count == 960, "Empty search tree must contain all 960 structures")
	var anatomy_tree_root: TreeItem = preview.search_results.get_root()
	require(count_tree_children(anatomy_tree_root) == 6, "Search tree must expose all six anatomy-system groups")
	var muscle_group: TreeItem = anatomy_tree_root.get_first_child()
	require(muscle_group.get_text(0).begins_with("Skeletal muscles"), "Muscles must have an explicit tree group")
	require(not muscle_group.collapsed, "Anatomy-system groups must be expanded initially")
	require(muscle_group.get_first_child().collapsed, "Regional groups must be collapsible and initially compact")
	preview.populate_search("biceps brachii left")
	require(preview.search_result_count == 2, "Filtered tree must contain both matching left biceps heads")
	muscle_group = preview.search_results.get_root().get_first_child()
	require(not muscle_group.get_first_child().collapsed, "Filtered result regions must expand automatically")
	preview.populate_search("")
	require(preview.mesh_picker != null, "Physicsless mesh picker must initialize")
	require(count_collision_objects(canonical) == 0, "Picking must not create physics collision objects")
	test_physicsless_hit_ordering()
	test_sternum_mesh_intersections(preview)
	var biceps_results: Array[Dictionary] = preview.registry.search("biceps brachii left")
	require(biceps_results.size() == 2, "Search must find both left biceps brachii heads")
	var selected_id := "muscle.long_head_of_biceps_brachii.left"
	require(preview.select_structure(selected_id), "Any canonical structure must be selectable by ID")
	require(preview.selected_id == selected_id, "Selection must preserve the canonical ID")
	var selected_node: MeshInstance3D = preview.registry.get_structure_node(selected_id)
	require(selected_node != null, "Selected structure must resolve to its mesh node")
	preview.hide_selected()
	require(not selected_node.visible, "Hide must conceal the selected structure")
	preview.hide_selected()
	require(selected_node.visible, "Show must restore the selected structure")
	preview.toggle_isolate_selected()
	require(count_visible_meshes(canonical) == 1, "Isolate must show only the selected structure")
	preview.toggle_isolate_selected()
	require(count_visible_meshes(canonical) == 960, "Leaving isolate must restore the complete body")
	preview.toggle_fade_others()
	var other_node: MeshInstance3D = preview.registry.get_structure_node("bone.atlas_c1")
	require(other_node.material_override.albedo_color.a < selected_node.material_override.albedo_color.a, "Fade must preserve selected emphasis")
	preview.clear_selection()
	require(preview.selected_id.is_empty(), "Clear must remove the active selection")
	preview.focus(Vector3(0.0, 0.92, 0.0), 2.9)
	var screen_center := Vector2(root.size) * 0.5
	require(preview.pick_at_screen_position(screen_center), "A center-screen click must hit the whole body")
	require(not preview.selected_id.is_empty(), "A direct mesh hit must select a canonical ID")
	print("Whole-body pick: %.3f ms, %d candidates, %d hits, %d cached BVHs" % [
		preview.mesh_picker.last_query_usec / 1000.0,
		preview.mesh_picker.last_candidate_count,
		preview.mesh_picker.last_surface_hit_count,
		preview.mesh_picker.cached_triangle_mesh_count(),
	])
	var first_picked_id: String = preview.selected_id
	if preview.last_pick_hits.size() > 1:
		require(preview.pick_at_screen_position(screen_center), "A repeated click must cycle overlapping hits")
		require(preview.selected_id != first_picked_id, "Hit cycling must advance to the next structure")
	preview.reset_pick_cycle()
	require(preview.pick_at_screen_position(screen_center), "A cached center-screen query must still hit")
	print("Cached whole-body pick: %.3f ms" % [preview.mesh_picker.last_query_usec / 1000.0])
	require(preview.mesh_picker.last_query_usec < 16000, "Cached whole-body picking must complete within 16 ms")
	preview.clear_selection()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_center
	preview._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_center + Vector2(12.0, 0.0)
	motion.relative = Vector2(12.0, 0.0)
	preview._unhandled_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	preview._unhandled_input(release)
	require(preview.selected_id.is_empty(), "An orbit drag must not trigger mesh selection")
	var pan_start: Vector3 = preview.target
	var pan_press := InputEventMouseButton.new()
	pan_press.button_index = MOUSE_BUTTON_RIGHT
	pan_press.pressed = true
	pan_press.position = screen_center
	preview._unhandled_input(pan_press)
	var pan_motion := InputEventMouseMotion.new()
	pan_motion.position = screen_center + Vector2(18.0, 9.0)
	pan_motion.relative = Vector2(18.0, 9.0)
	preview._unhandled_input(pan_motion)
	var pan_release := InputEventMouseButton.new()
	pan_release.button_index = MOUSE_BUTTON_RIGHT
	pan_release.pressed = false
	pan_release.position = pan_motion.position
	preview._unhandled_input(pan_release)
	require(not preview.target.is_equal_approx(pan_start), "Right-button dragging must pan the camera target")
	require(not preview.panning, "Releasing the right button must end panning")
	require(preview.selected_id.is_empty(), "Right-button panning must not select anatomy")

	require(preview.toolbar != null, "Standalone anatomy toolbar must instantiate")
	require(preview.exercise_selector != null, "Exercise selector must instantiate")
	require(preview.exercise_selector.records_by_id.size() == 874, "Exercise selector must represent the complete source and canonical catalog")
	require(preview.exercise_selector.result_count == 874, "Empty exercise search must show the complete merged catalog")
	require(preview.exercise_selector.visualizable_result_count == 21, "Exercise selector must distinguish visualizable variants")
	require(preview.exercise_selector.catalog_only_result_count == 853, "Exercise selector must distinguish catalog-only records")
	preview.exercise_selector.populate_exercises("")
	require(preview.toolbar.cartilage_button != null, "Toolbar toggle buttons must initialize")
	set_toolbar_toggle(preview.toolbar.cartilage_button, false)
	require(count_visible_system(canonical, ["cartilage"]) == 0, "Cartilage meshes must hide")
	require(preview.search_system_items["cartilage"].collapsed, "Hidden system groups must collapse in the search tree")
	set_toolbar_toggle(preview.toolbar.cartilage_button, true)
	require(not preview.search_system_items["cartilage"].collapsed, "Restored system groups must expand in the search tree")
	set_toolbar_toggle(preview.toolbar.connective_button, false)
	require(count_visible_system(canonical, ["musculoskeletal_connective_tissue"]) == 0, "Connective-tissue meshes must hide")
	set_toolbar_toggle(preview.toolbar.connective_button, true)
	set_toolbar_toggle(preview.toolbar.bone_button, false)
	require(count_visible_system(canonical, ["bone", "dental_structure", "skeletal_feature"]) == 0, "Bone toggle must hide bones, teeth, and features")
	require(preview.search_system_items["bone"].collapsed, "Bone group must collapse when its toolbar toggle is off")
	require(preview.search_system_items["dental_structure"].collapsed, "Teeth group must collapse with the bone toolbar toggle")
	require(preview.search_system_items["skeletal_feature"].collapsed, "Skeletal-feature group must collapse with the bone toolbar toggle")
	set_toolbar_toggle(preview.toolbar.bone_button, true)
	require(not preview.search_system_items["bone"].collapsed, "Bone group must expand when restored")
	set_toolbar_toggle(preview.toolbar.muscle_button, false)
	require(count_visible_system(canonical, ["skeletal_muscle"]) == 0, "Muscle meshes must hide")
	set_toolbar_toggle(preview.toolbar.muscle_button, true)
	require(count_visible_depth(canonical, "superficial") == 160, "All superficial muscles must carry runtime depth identity")
	require(count_visible_depth(canonical, "deep") == 306, "All deep muscles must carry runtime depth identity")
	set_toolbar_toggle(preview.toolbar.superficial_button, false)
	require(count_visible_depth(canonical, "superficial") == 0, "Surface-layer toolbar toggle must hide superficial muscles")
	require(count_visible_depth(canonical, "deep") == 306, "Surface-layer toggle must preserve deep muscles")
	set_toolbar_toggle(preview.toolbar.superficial_button, true)
	set_toolbar_toggle(preview.toolbar.deep_button, false)
	require(count_visible_depth(canonical, "deep") == 0, "Deep-layer toolbar toggle must hide deep muscles")
	require(count_visible_depth(canonical, "superficial") == 160, "Deep-layer toggle must preserve superficial muscles")
	set_toolbar_toggle(preview.toolbar.deep_button, true)
	set_toolbar_toggle(preview.toolbar.body_button, false)
	require(not canonical.visible, "Body toolbar toggle must hide the assembled body")
	set_toolbar_toggle(preview.toolbar.body_button, true)
	preview.toolbar.focus_requested.emit(&"head")
	require(preview.target.is_equal_approx(Vector3(0.0, 1.53, 0.0)), "Toolbar focus signal must frame the requested region")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_M
	key_event.pressed = true
	preview._unhandled_input(key_event)
	require(preview.muscle_visible, "Keyboard input must no longer toggle anatomy systems")
	var exercise_id := "exercise.ab_wheel_rollout.kneeling"
	require(preview.exercise_selector.select_exercise(exercise_id), "A supported exercise must be selectable by canonical ID")
	require(preview.exercise_selector.selected_exercise_id == exercise_id, "Exercise selection must preserve canonical identity")
	require(preview.workout_mode_enabled, "Selecting an exercise must enable its heatmap")
	require(preview.workout_vc.current_summary["exercises"].size() == 1, "Exercise heatmap must score only the selected exercise")
	require(preview.workout_vc.current_summary["exercises"][0]["exercise_id"] == exercise_id, "Exercise heatmap must use the selected engagement profile")
	var affected_item: TreeItem = preview.exercise_selector.affected_tree.get_root().get_first_child().get_first_child()
	var affected_muscle_id := String(affected_item.get_metadata(0))
	affected_item.select(0)
	preview.exercise_selector.affected_tree.item_selected.emit()
	require(preview.selected_id == affected_muscle_id, "Selecting an affected-structure row must select the canonical muscle on the body")
	require(preview.exercise_selector.select_exercise("catalog.free_exercise_db.3_4_Sit-Up"), "Catalog-only source exercise must be selectable")
	require(not preview.workout_mode_enabled, "Catalog-only exercise must disable rather than fabricate a heatmap")

	if failures.is_empty():
		print("Whole-body preview passed: 960 canonical meshes")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func set_toolbar_toggle(button: Button, enabled: bool) -> void:
	button.set_pressed_no_signal(enabled)
	button.toggled.emit(enabled)


func count_visible_system(node: Node, systems: Array) -> int:
	var count := 0
	if node is MeshInstance3D and node.visible:
		if String(node.get_meta("bodysim_system", "other")) in systems:
			count = 1
	for child in node.get_children():
		count += count_visible_system(child, systems)
	return count


func count_visible_depth(node: Node, depth: String) -> int:
	var count := 0
	if node is MeshInstance3D and node.visible:
		if String(node.get_meta("bodysim_display_depth", "structural")) == depth:
			count = 1
	for child in node.get_children():
		count += count_visible_depth(child, depth)
	return count


func count_visible_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and node.visible else 0
	for child in node.get_children():
		count += count_visible_meshes(child)
	return count


func count_tree_children(item: TreeItem) -> int:
	var count := 0
	var child := item.get_first_child()
	while child != null:
		count += 1
		child = child.get_next()
	return count


func count_collision_objects(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		count += count_collision_objects(child)
	return count


func test_physicsless_hit_ordering() -> void:
	var fixture_root := Node3D.new()
	root.add_child(fixture_root)
	var registry := FakeRegistry.new()
	for item in [["near", -1.5], ["far", -3.0]]:
		var mesh_node := MeshInstance3D.new()
		mesh_node.mesh = BoxMesh.new()
		mesh_node.position = Vector3(0.0, 0.0, item[1])
		fixture_root.add_child(mesh_node)
		registry.ordered_ids.append(item[0])
		registry.nodes_by_id[item[0]] = mesh_node
	var picker = MESH_PICKER.new(registry)
	require(picker.cached_triangle_mesh_count() == 0, "Triangle BVHs must be built lazily")
	var hits: Array[Dictionary] = picker.pick_ray(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	require(hits.size() == 2, "Exact ray picking must hit both overlapping fixtures")
	if hits.size() == 2:
		require(hits[0]["id"] == "near", "Exact ray hits must be ordered nearest-first")
		require(hits[1]["id"] == "far", "Farther overlapping hits must remain available for cycling")
	require(picker.cached_triangle_mesh_count() == 2, "Only candidate mesh BVHs must be cached")
	registry.nodes_by_id["near"].visible = false
	hits = picker.pick_ray(Vector3.ZERO, Vector3(0.0, 0.0, -1.0))
	require(hits.size() == 1 and hits[0]["id"] == "far", "Hidden structures must be excluded from picking")
	fixture_root.free()


func test_sternum_mesh_intersections(preview: Node) -> void:
	var previous_selected: String = preview.selected_id
	var previous_isolated: String = preview.isolated_id
	for structure_id in [
		"bone.manubrium_of_sternum",
		"bone.body_of_sternum",
		"skeletal_feature.xiphoid_process",
	]:
		preview.selected_id = structure_id
		preview.isolated_id = structure_id
		preview.update_all_structure_presentation()
		var mesh_node: MeshInstance3D = preview.registry.get_structure_node(structure_id)
		var faces: PackedVector3Array = mesh_node.mesh.get_faces()
		var found_hit := false
		for index in range(0, faces.size(), 3):
			var a: Vector3 = faces[index]
			var b: Vector3 = faces[index + 1]
			var c: Vector3 = faces[index + 2]
			var local_normal := (b - a).cross(c - a).normalized()
			if local_normal.is_zero_approx():
				continue
			var local_center := (a + b + c) / 3.0
			var world_center: Vector3 = mesh_node.global_transform * local_center
			var world_normal: Vector3 = (mesh_node.global_transform.basis.inverse().transposed() * local_normal).normalized()
			var hits: Array[Dictionary] = preview.mesh_picker.pick_ray(
				world_center + world_normal * 0.05,
				-world_normal
			)
			if hits.any(func(hit: Dictionary) -> bool: return hit["id"] == structure_id):
				found_hit = true
				break
		require(found_hit, "Sternum component must have directly intersectable triangles: %s" % structure_id)
	preview.selected_id = previous_selected
	preview.isolated_id = previous_isolated
	preview.update_all_structure_presentation()
