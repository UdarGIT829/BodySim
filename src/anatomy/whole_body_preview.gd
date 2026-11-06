extends Node3D

const MANIFEST_PATH := "res://data/anatomy/mesh_manifest.json"
const StructureRegistry := preload("res://src/anatomy/structure_registry.gd")
const MeshPicker := preload("res://src/anatomy/mesh_picker.gd")
const WorkoutViewControllerScript := preload("res://src/exercises/workout_view_controller.gd")

const REGIONAL_MODELS := [
	["HeadNeck", "res://build/anatomy/regions/head_neck.glb"],
	["Torso", "res://build/anatomy/regions/torso.glb"],
	["Pelvis", "res://build/anatomy/regions/pelvis.glb"],
	["UpperLimbLeft", "res://build/anatomy/regions/upper_limb_left.glb"],
	["UpperLimbRight", "res://build/anatomy/regions/upper_limb_right.glb"],
	["LowerLimbLeft", "res://build/anatomy/regions/lower_limb_left.glb"],
	["LowerLimbRight", "res://build/anatomy/regions/lower_limb_right.glb"],
]

var canonical_root: Node3D
var camera_rig: Node3D
var camera: Camera3D
var status_label: Label
var controls_label: Label
var toolbar: PanelContainer
var search_input: LineEdit
var search_results: Tree
var search_result_count := 0
var search_system_items: Dictionary = {}
var details_label: Label
var hide_button: Button
var isolate_button: Button
var fade_button: Button
var workout_toggle_button: Button
var exercise_selector: PanelContainer
var registry: RefCounted
var mesh_picker: RefCounted
var workout_vc: RefCounted
var workout_mode_enabled := false
var selected_id := ""
var isolated_id := ""
var hidden_ids: Dictionary = {}
var fade_others := false
var material_cache: Dictionary = {}
var pointer_drag_distance := 0.0
var last_pick_position := Vector2(-10000.0, -10000.0)
var last_pick_hits: Array[Dictionary] = []
var last_pick_index := -1

const CLICK_DRAG_THRESHOLD := 5.0
const PICK_CYCLE_RADIUS := 5.0
const SYSTEM_ORDER := [
	"skeletal_muscle",
	"bone",
	"musculoskeletal_connective_tissue",
	"cartilage",
	"dental_structure",
	"skeletal_feature",
]
const REGION_ORDER := ["head_neck", "torso", "pelvis", "upper_limb", "lower_limb"]
const SYSTEM_LABELS := {
	"skeletal_muscle": "Skeletal muscles",
	"bone": "Bones",
	"musculoskeletal_connective_tissue": "Connective tissue / tendons",
	"cartilage": "Cartilage",
	"dental_structure": "Teeth",
	"skeletal_feature": "Skeletal features",
}
const REGION_LABELS := {
	"head_neck": "Head and neck",
	"torso": "Torso",
	"pelvis": "Pelvis",
	"upper_limb": "Upper limbs",
	"lower_limb": "Lower limbs",
}
var yaw := 0.0
var pitch := -0.05
var distance := 2.9
var target := Vector3(0.0, 0.92, 0.0)
var dragging := false
var panning := false
var canonical_visible := true
var muscle_visible := true
var bone_visible := true
var cartilage_visible := true
var connective_visible := true
var superficial_visible := true
var deep_visible := true


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("111821"))
	bind_authored_scene()
	connect_interface()
	workout_vc = WorkoutViewControllerScript.new()
	workout_vc.load_and_score_workout()
	for model in REGIONAL_MODELS:
		load_model(model[1], model[0], canonical_root)
	apply_canonical_style(canonical_root)
	registry = StructureRegistry.new()
	if not registry.load_manifest(MANIFEST_PATH):
		push_error("Whole-body structure manifest failed to load")
	else:
		var binding_errors: Array[String] = registry.bind_scene(canonical_root)
		for error in binding_errors:
			push_error(error)
		if binding_errors.is_empty():
			mesh_picker = MeshPicker.new(registry)
	populate_search("")
	update_details()
	update_status()
	apply_camera()


func bind_authored_scene() -> void:
	canonical_root = $CanonicalBody
	camera_rig = $CameraRig
	camera = $CameraRig/AlignmentCamera
	var browser: PanelContainer = $Interface/AnatomyBrowser
	status_label = browser.get_node("Margin/Column/StatusLabel")
	controls_label = browser.get_node("Margin/Column/ControlsLabel")
	search_input = browser.get_node("Margin/Column/SearchInput")
	search_results = browser.get_node("Margin/Column/SearchResults")
	details_label = browser.get_node("Margin/Column/DetailsLabel")
	hide_button = browser.get_node("Margin/Column/Actions/HideButton")
	isolate_button = browser.get_node("Margin/Column/Actions/IsolateButton")
	fade_button = browser.get_node("Margin/Column/Actions/FadeButton")
	workout_toggle_button = browser.get_node("Margin/Column/Actions/WorkoutToggleButton")
	toolbar = $Interface/AnatomyToolbar
	exercise_selector = $Interface/ExerciseSelector


func connect_interface() -> void:
	search_input.text_changed.connect(populate_search)
	search_results.set_column_title(0, "Anatomy")
	search_results.set_column_title(1, "Side")
	search_results.set_column_expand(0, true)
	search_results.set_column_expand(1, false)
	search_results.set_column_custom_minimum_width(1, 70)
	search_results.item_selected.connect(on_search_result_selected)
	hide_button.pressed.connect(hide_selected)
	isolate_button.pressed.connect(toggle_isolate_selected)
	fade_button.pressed.connect(toggle_fade_others)
	workout_toggle_button.pressed.connect(toggle_workout_mode)
	var clear_button: Button = $Interface/AnatomyBrowser/Margin/Column/Actions/ClearButton
	clear_button.pressed.connect(clear_selection)
	toolbar.body_visibility_changed.connect(set_canonical_visibility)
	toolbar.muscle_visibility_changed.connect(set_muscle_visibility)
	toolbar.bone_visibility_changed.connect(set_bone_visibility)
	toolbar.cartilage_visibility_changed.connect(set_cartilage_visibility)
	toolbar.connective_visibility_changed.connect(set_connective_visibility)
	toolbar.superficial_visibility_changed.connect(set_superficial_visibility)
	toolbar.deep_visibility_changed.connect(set_deep_visibility)
	toolbar.focus_requested.connect(focus_preset)
	exercise_selector.exercise_selected.connect(on_exercise_selected)
	exercise_selector.catalog_exercise_selected.connect(on_catalog_exercise_selected)
	exercise_selector.structure_selected.connect(on_exercise_structure_selected)


func toggle_workout_mode() -> void:
	workout_mode_enabled = not workout_mode_enabled
	if workout_toggle_button != null:
		workout_toggle_button.text = "Heatmap: ON" if workout_mode_enabled else "Heatmap: OFF"
	update_all_structure_presentation()
	update_status()


func on_exercise_selected(exercise_id: String) -> void:
	if workout_vc == null or not workout_vc.score_single_exercise(exercise_id):
		return
	workout_mode_enabled = true
	if workout_toggle_button != null:
		workout_toggle_button.text = "Heatmap: ON"
	update_all_structure_presentation()
	update_status()


func on_catalog_exercise_selected(_catalog_id: String) -> void:
	workout_mode_enabled = false
	if workout_toggle_button != null:
		workout_toggle_button.text = "Heatmap: OFF"
	update_all_structure_presentation()
	update_status()


func on_exercise_structure_selected(structure_id: String) -> void:
	select_structure(structure_id)


func show_candidate_profile(profile: Dictionary) -> bool:
	if workout_vc == null or not workout_vc.set_candidate_profile(profile):
		return false
	workout_mode_enabled = true
	if workout_toggle_button != null:
		workout_toggle_button.text = "Heatmap: ON"
	update_all_structure_presentation()
	update_status()
	return true


func set_embedded_review_mode(enabled: bool) -> void:
	$Interface.visible = not enabled

func load_model(path: String, node_name: String, parent: Node3D) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Missing generated preview asset: %s" % path)
		return null
	var instance := packed.instantiate() as Node3D
	instance.name = node_name
	parent.add_child(instance)
	return instance


func canonical_material(system: String, state := "normal", structure_id := "") -> StandardMaterial3D:
	if workout_mode_enabled and system == "skeletal_muscle" and state == "normal" and not structure_id.is_empty() and workout_vc != null:
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.albedo_color = workout_vc.get_muscle_color(structure_id)
		return material
	var cache_key := "%s:%s" % [system, state]
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.58, 0.72, 0.82, 0.16)
	if system == "skeletal_muscle":
		material.albedo_color = Color(0.78, 0.25, 0.23, 0.34)
	elif system == "bone" or system == "dental_structure":
		material.albedo_color = Color(0.84, 0.86, 0.80, 0.24)
	elif system == "cartilage":
		material.albedo_color = Color(0.64, 0.82, 0.88, 0.28)
	elif system == "musculoskeletal_connective_tissue":
		material.albedo_color = Color(0.54, 0.76, 0.72, 0.20)
	if state == "selected":
		material.albedo_color = Color(1.0, 0.72, 0.08, 0.96)
	elif state == "faded":
		material.albedo_color.a = 0.035
	material_cache[cache_key] = material
	return material


func apply_canonical_style(node: Node) -> void:
	if node is MeshInstance3D:
		var extras: Dictionary = node.get_meta("extras", {})
		var system := String(extras.get("bodysim_system", "other"))
		var structure_id := String(extras.get("bodysim_id", ""))
		node.set_meta("bodysim_system", system)
		node.set_meta("bodysim_id", structure_id)
		node.material_override = canonical_material(system)
	for child in node.get_children():
		apply_canonical_style(child)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				pointer_drag_distance = 0.0
			else:
				dragging = false
				if pointer_drag_distance <= CLICK_DRAG_THRESHOLD:
					pick_at_screen_position(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			panning = event.pressed
			if event.pressed:
				reset_pick_cycle()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = max(0.12, distance * 0.88)
			reset_pick_cycle()
			apply_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = min(5.0, distance / 0.88)
			reset_pick_cycle()
			apply_camera()
	elif event is InputEventMouseMotion and dragging:
		pointer_drag_distance += event.relative.length()
		yaw -= event.relative.x * 0.008
		pitch = clamp(pitch - event.relative.y * 0.008, -1.45, 1.45)
		reset_pick_cycle()
		apply_camera()
	elif event is InputEventMouseMotion and panning:
		pan_camera(event.relative)


func set_canonical_visibility(enabled: bool) -> void:
	canonical_visible = enabled
	if canonical_root != null:
		canonical_root.visible = canonical_visible
	reset_pick_cycle()
	for system in search_system_items:
		set_search_system_collapsed(
			system,
			not enabled or not system_is_visible(system)
		)
	update_status()


func set_muscle_visibility(enabled: bool) -> void:
	muscle_visible = enabled
	set_search_system_collapsed("skeletal_muscle", not enabled)
	update_canonical_system_visibility()


func set_bone_visibility(enabled: bool) -> void:
	bone_visible = enabled
	set_search_system_collapsed("bone", not enabled)
	set_search_system_collapsed("dental_structure", not enabled)
	set_search_system_collapsed("skeletal_feature", not enabled)
	update_canonical_system_visibility()


func set_cartilage_visibility(enabled: bool) -> void:
	cartilage_visible = enabled
	set_search_system_collapsed("cartilage", not enabled)
	update_canonical_system_visibility()


func set_connective_visibility(enabled: bool) -> void:
	connective_visible = enabled
	set_search_system_collapsed("musculoskeletal_connective_tissue", not enabled)
	update_canonical_system_visibility()


func set_superficial_visibility(enabled: bool) -> void:
	superficial_visible = enabled
	update_canonical_system_visibility()


func set_deep_visibility(enabled: bool) -> void:
	deep_visible = enabled
	update_canonical_system_visibility()


func set_search_system_collapsed(system: String, collapsed: bool) -> void:
	var item: TreeItem = search_system_items.get(system)
	if item != null:
		item.collapsed = collapsed


func focus_preset(preset: StringName) -> void:
	match preset:
		&"whole":
			focus(Vector3(0.0, 0.92, 0.0), 2.9)
		&"head":
			focus(Vector3(0.0, 1.53, 0.0), 0.38)
		&"back":
			focus(Vector3(0.0, 1.28, -0.06), 0.68, PI)
		&"pelvis":
			focus(Vector3(0.0, 0.82, 0.0), 0.42)
		&"hand":
			focus(Vector3(0.25, 0.87, 0.02), 0.26)
		&"knee":
			focus(Vector3(0.09, 0.50, 0.0), 0.30)


func pan_camera(relative_motion: Vector2) -> void:
	if camera == null:
		return
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var world_per_pixel := 2.0 * distance * tan(deg_to_rad(camera.fov * 0.5)) / viewport_height
	var camera_basis := camera.global_transform.basis.orthonormalized()
	target -= camera_basis.x * relative_motion.x * world_per_pixel
	target += camera_basis.y * relative_motion.y * world_per_pixel
	reset_pick_cycle()
	apply_camera()


func update_canonical_system_visibility() -> void:
	if canonical_root == null:
		return
	reset_pick_cycle()
	update_all_structure_presentation()


func set_system_visibility(node: Node) -> void:
	if node is MeshInstance3D:
		var system := String(node.get_meta("bodysim_system", "other"))
		var structure_id := String(node.get_meta("bodysim_id", ""))
		node.visible = system_is_visible(system)
		if system == "skeletal_muscle":
			var display_depth := String(node.get_meta("bodysim_display_depth", "deep"))
			if display_depth == "superficial" and not superficial_visible:
				node.visible = false
			elif display_depth == "deep" and not deep_visible:
				node.visible = false
		if hidden_ids.has(structure_id):
			node.visible = false
		if not isolated_id.is_empty() and structure_id != isolated_id:
			node.visible = false
		var state := "normal"
		if structure_id == selected_id:
			state = "selected"
		elif fade_others and not selected_id.is_empty():
			state = "faded"
		node.material_override = canonical_material(system, state, structure_id)
	for child in node.get_children():
		set_system_visibility(child)


func system_is_visible(system: String) -> bool:
	if system == "skeletal_muscle":
		return muscle_visible
	if system == "bone" or system == "dental_structure" or system == "skeletal_feature":
		return bone_visible
	if system == "cartilage":
		return cartilage_visible
	if system == "musculoskeletal_connective_tissue":
		return connective_visible
	return true


func update_all_structure_presentation() -> void:
	if canonical_root != null:
		set_system_visibility(canonical_root)
	update_details()


func populate_search(query: String) -> void:
	if search_results == null:
		return
	search_results.clear()
	search_result_count = 0
	search_system_items.clear()
	if registry == null:
		return
	var records: Array[Dictionary] = registry.search(query, registry.records_by_id.size())
	var grouped: Dictionary = {}
	for record in records:
		var system := String(record.get("system", "other"))
		var region := String(record.get("region", "other"))
		if not grouped.has(system):
			grouped[system] = {}
		var system_group: Dictionary = grouped[system]
		if not system_group.has(region):
			system_group[region] = []
		var region_records: Array = system_group[region]
		region_records.append(record)
	var root_item := search_results.create_item()
	var searching := not query.strip_edges().is_empty()
	for system in ordered_group_keys(grouped, SYSTEM_ORDER):
		var system_records: Dictionary = grouped[system]
		var system_count := 0
		for region_records in system_records.values():
			system_count += region_records.size()
		var system_item := search_results.create_item(root_item)
		search_system_items[system] = system_item
		system_item.set_text(0, "%s (%d)" % [SYSTEM_LABELS.get(system, system.capitalize()), system_count])
		system_item.set_selectable(0, false)
		system_item.set_selectable(1, false)
		system_item.collapsed = not system_is_visible(system)
		for region in ordered_group_keys(system_records, REGION_ORDER):
			var region_records: Array = system_records[region]
			var region_item := search_results.create_item(system_item)
			region_item.set_text(0, "%s (%d)" % [REGION_LABELS.get(region, region.capitalize()), region_records.size()])
			region_item.set_selectable(0, false)
			region_item.set_selectable(1, false)
			region_item.collapsed = not searching
			for record in region_records:
				var structure_item := search_results.create_item(region_item)
				structure_item.set_text(0, String(record.get("name", record["id"])))
				structure_item.set_text(1, String(record.get("side", "")).capitalize())
				structure_item.set_metadata(0, record["id"])
				search_result_count += 1


func ordered_group_keys(groups: Dictionary, preferred_order: Array) -> Array:
	var keys: Array = []
	for key in preferred_order:
		if groups.has(key):
			keys.append(key)
	var remaining := groups.keys()
	remaining.sort()
	for key in remaining:
		if key not in keys:
			keys.append(key)
	return keys


func on_search_result_selected() -> void:
	var selected := search_results.get_selected()
	if selected == null:
		return
	var structure_id := String(selected.get_metadata(0))
	if not structure_id.is_empty():
		select_structure(structure_id)


func select_structure(structure_id: String, should_focus := true) -> bool:
	if registry == null or not registry.records_by_id.has(structure_id):
		return false
	selected_id = structure_id
	update_all_structure_presentation()
	if should_focus:
		focus_selected()
	return true


func pick_at_screen_position(screen_position: Vector2) -> bool:
	if mesh_picker == null or camera == null:
		return false
	var continuing_cycle := (
		screen_position.distance_to(last_pick_position) <= PICK_CYCLE_RADIUS
		and not last_pick_hits.is_empty()
	)
	if not continuing_cycle:
		var ray_origin := camera.project_ray_origin(screen_position)
		var ray_direction := camera.project_ray_normal(screen_position)
		last_pick_hits = mesh_picker.pick_ray(ray_origin, ray_direction)
		last_pick_index = -1
		last_pick_position = screen_position
	if last_pick_hits.is_empty():
		clear_selection()
		return false
	last_pick_index = (last_pick_index + 1) % last_pick_hits.size()
	return select_structure(String(last_pick_hits[last_pick_index]["id"]), false)


func reset_pick_cycle() -> void:
	last_pick_position = Vector2(-10000.0, -10000.0)
	last_pick_hits.clear()
	last_pick_index = -1


func hide_selected() -> void:
	if selected_id.is_empty():
		return
	if hidden_ids.has(selected_id):
		hidden_ids.erase(selected_id)
	else:
		hidden_ids[selected_id] = true
	reset_pick_cycle()
	update_all_structure_presentation()


func toggle_isolate_selected() -> void:
	if selected_id.is_empty():
		return
	isolated_id = "" if isolated_id == selected_id else selected_id
	reset_pick_cycle()
	update_all_structure_presentation()


func toggle_fade_others() -> void:
	if selected_id.is_empty():
		return
	fade_others = not fade_others
	update_all_structure_presentation()


func clear_selection() -> void:
	selected_id = ""
	isolated_id = ""
	fade_others = false
	reset_pick_cycle()
	update_all_structure_presentation()
	if search_results != null:
		search_results.deselect_all()


func focus_selected() -> void:
	if registry == null:
		return
	var mesh_node: MeshInstance3D = registry.get_structure_node(selected_id)
	if mesh_node == null or mesh_node.mesh == null:
		return
	var bounds: AABB = mesh_node.get_aabb()
	var world_center: Vector3 = mesh_node.global_transform * bounds.get_center()
	var extent: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	focus(world_center, clamp(extent * 3.5, 0.12, 1.4), yaw, pitch)


func update_details() -> void:
	if details_label == null:
		return
	if selected_id.is_empty() or registry == null:
		details_label.text = "Select a structure to inspect its canonical identity and coverage."
	else:
		var record: Dictionary = registry.get_record(selected_id)
		details_label.text = "%s\n%s · %s · %s · %s layer\nSource: %s · %s\nCoverage: mesh present · %s" % [
			record.get("name", selected_id),
			record.get("side", "unknown"),
			record.get("region", "unknown"),
			record.get("system", "unknown"),
			record.get("display_depth", "structural"),
			record.get("source", "unknown"),
			record.get("license_status", "unknown license"),
			selected_id,
		]
		if workout_mode_enabled and workout_vc != null and selected_id.begins_with("muscle."):
			details_label.text += "\n\n" + workout_vc.get_muscle_contribution_details(selected_id)

	if hide_button != null:
		hide_button.disabled = selected_id.is_empty()
		hide_button.text = "Show" if hidden_ids.has(selected_id) else "Hide"
	if isolate_button != null:
		isolate_button.disabled = selected_id.is_empty()
		isolate_button.text = "Show all" if isolated_id == selected_id else "Isolate"
	if fade_button != null:
		fade_button.disabled = selected_id.is_empty()
		fade_button.text = "Unfade" if fade_others else "Fade others"


func focus(new_target: Vector3, new_distance: float, new_yaw := 0.0, new_pitch := -0.04) -> void:
	reset_pick_cycle()
	target = new_target
	distance = new_distance
	yaw = new_yaw
	pitch = new_pitch
	apply_camera()


func apply_camera() -> void:
	if camera_rig == null or camera == null:
		return
	camera_rig.position = target
	camera_rig.rotation = Vector3(pitch, yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, distance)


func update_status() -> void:
	if status_label == null:
		return
	if workout_mode_enabled and workout_vc != null and not workout_vc.current_summary.is_empty():
		var s: Dictionary = workout_vc.current_summary
		var display_name := ""
		if exercise_selector != null:
			display_name = exercise_selector.get_selected_display_name()
		var context := display_name if not display_name.is_empty() else String(s.get("session_id", ""))
		status_label.text = "Muscle Exposure Heatmap: ON\nActive muscles: %d / 466 · Max Exposure: %.2f · %s" % [
			s.get("active_muscles", 0),
			s.get("max_raw_exposure", 0.0),
			context,
		]
	else:
		var canonical_meshes := count_meshes(canonical_root) if canonical_root != null else 0
		status_label.text = "Canonical musculoskeletal catalog: %d / 960 meshes [%s]\nAll catalog systems are represented by M + B + K + T" % [canonical_meshes, "on" if canonical_visible else "off"]


func count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += count_meshes(child)
	return count
