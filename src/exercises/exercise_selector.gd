class_name ExerciseSelector
extends PanelContainer

signal exercise_selected(exercise_id: String)
signal catalog_exercise_selected(catalog_id: String)
signal structure_selected(structure_id: String)

const DEFAULT_CATALOG_PATH := "res://data/exercises/exercises.json"
const DEFAULT_CANDIDATE_CATALOG_PATH := "res://data/exercises/catalog/candidates.json"
const DEFAULT_PROFILES_PATH := "res://data/exercises/engagement_profiles.json"
const DEFAULT_STRUCTURES_PATH := "res://data/anatomy/structures.json"

const FAMILY_ORDER := [
	"squat",
	"hip_hinge",
	"horizontal_push",
	"vertical_push",
	"horizontal_pull",
	"vertical_pull",
	"loaded_carry",
	"elbow_flexion",
	"elbow_extension",
	"knee_extension",
	"knee_flexion",
	"ankle_plantarflexion",
	"trunk_flexion",
	"lunge",
	"hip_bridge",
	"hip_flexion",
	"hip_abduction_adduction",
	"core_anti_extension",
	"core_rotation",
	"trunk_lateral_flexion",
	"shoulder_raise",
	"shoulder_rotation",
	"scapular_elevation",
	"wrist_and_grip",
	"olympic_lift",
	"jump_and_throw",
	"neck",
]
const CATEGORY_ORDER := [
	"strength",
	"stretching",
	"plyometrics",
	"powerlifting",
	"olympic weightlifting",
	"strongman",
	"cardio",
]
const ROLE_ORDER := ["primary", "synergist", "stabilizer"]
const ROLE_LABELS := {
	"primary": "Primary movers",
	"synergist": "Synergists",
	"stabilizer": "Stabilizers",
}

@onready var search_input: LineEdit = %SearchInput
@onready var exercise_tree: Tree = %ExerciseTree
@onready var details_label: Label = %DetailsLabel
@onready var result_label: Label = %ResultLabel
@onready var affected_summary_label: Label = %AffectedSummaryLabel
@onready var affected_tree: Tree = %AffectedTree
@onready var image_modal: Window = $ExerciseImageModal
var records_by_id: Dictionary = {}
var profiles_by_exercise: Dictionary = {}
var structures_by_id: Dictionary = {}
var ordered_exercise_ids: Array[String] = []
var selected_exercise_id := ""
var result_count := 0
var visualizable_result_count := 0
var catalog_only_result_count := 0


func _ready() -> void:
	configure_interface()
	load_engagement_profiles()
	load_structures()
	if load_catalog() and load_candidate_catalog():
		populate_exercises("")


func configure_interface() -> void:
	search_input.text_changed.connect(populate_exercises)
	exercise_tree.set_column_title(0, "Exercise")
	exercise_tree.set_column_title(1, "Status / Variant")
	exercise_tree.set_column_expand(0, true)
	exercise_tree.set_column_expand(1, false)
	exercise_tree.set_column_custom_minimum_width(1, 135)
	exercise_tree.item_selected.connect(on_tree_item_selected)
	exercise_tree.item_mouse_selected.connect(on_exercise_tree_mouse_selected)
	affected_tree.set_column_title(0, "Structure")
	affected_tree.set_column_title(1, "Effect")
	affected_tree.set_column_title(2, "Confidence")
	affected_tree.set_column_expand(0, true)
	for column in range(1, 3):
		affected_tree.set_column_expand(column, false)
	affected_tree.set_column_custom_minimum_width(1, 68)
	affected_tree.set_column_custom_minimum_width(2, 105)
	affected_tree.item_selected.connect(on_affected_tree_item_selected)


func load_engagement_profiles(path: String = DEFAULT_PROFILES_PATH) -> bool:
	profiles_by_exercise.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ExerciseSelector: Unable to open engagement profiles %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("profiles"):
		push_error("ExerciseSelector: Invalid engagement profile data")
		return false
	profiles_by_exercise = parsed["profiles"]
	return true


func load_structures(path: String = DEFAULT_STRUCTURES_PATH) -> bool:
	structures_by_id.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ExerciseSelector: Unable to open structure catalog %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("structures"):
		push_error("ExerciseSelector: Invalid structure catalog data")
		return false
	for value in parsed["structures"]:
		if value is Dictionary and value.has("id"):
			structures_by_id[String(value["id"])] = value
	return true


func load_catalog(path: String = DEFAULT_CATALOG_PATH) -> bool:
	records_by_id.clear()
	ordered_exercise_ids.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ExerciseSelector: Unable to open exercise catalog %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("ExerciseSelector: Exercise catalog must be an array")
		return false
	for value in parsed:
		if not value is Dictionary:
			continue
		var exercise_id := String(value.get("id", ""))
		if exercise_id.is_empty():
			continue
		var record: Dictionary = value.duplicate(true)
		record["catalog_status"] = "visualizable"
		records_by_id[exercise_id] = record
		ordered_exercise_ids.append(exercise_id)
	return not ordered_exercise_ids.is_empty()


func load_candidate_catalog(path: String = DEFAULT_CANDIDATE_CATALOG_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ExerciseSelector: Unable to open candidate catalog %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("ExerciseSelector: Candidate catalog must be an array")
		return false
	for value in parsed:
		if not value is Dictionary or value.get("status") != "catalog_only":
			continue
		var catalog_id := String(value.get("catalog_id", ""))
		if catalog_id.is_empty():
			continue
		var record: Dictionary = value.duplicate(true)
		record["id"] = catalog_id
		record["variant"] = "Catalog only"
		record["aliases"] = []
		record["movement_families"] = []
		record["laterality"] = "unreviewed"
		record["input_mode"] = "unreviewed"
		record["catalog_status"] = "catalog_only"
		records_by_id[catalog_id] = record
		ordered_exercise_ids.append(catalog_id)
	return true


func populate_exercises(query: String) -> void:
	if exercise_tree == null:
		return
	exercise_tree.clear()
	result_count = 0
	visualizable_result_count = 0
	catalog_only_result_count = 0
	var normalized_query := query.strip_edges().to_lower()
	var visualizable_groups: Dictionary = {}
	var catalog_only_groups: Dictionary = {}
	for exercise_id in ordered_exercise_ids:
		var record: Dictionary = records_by_id[exercise_id]
		if not exercise_matches(record, normalized_query):
			continue
		if record.get("catalog_status") == "catalog_only":
			var category := String(record.get("category", "other"))
			if not catalog_only_groups.has(category):
				catalog_only_groups[category] = []
			catalog_only_groups[category].append(record)
			catalog_only_result_count += 1
		else:
			var families: Array = record.get("movement_families", [])
			var family := String(families[0]) if not families.is_empty() else "other"
			if not visualizable_groups.has(family):
				visualizable_groups[family] = []
			visualizable_groups[family].append(record)
			visualizable_result_count += 1
		result_count += 1

	var root_item := exercise_tree.create_item()
	add_exercise_status_group(root_item, "Visualizable", visualizable_groups, FAMILY_ORDER, normalized_query, visualizable_result_count, false)
	add_exercise_status_group(root_item, "Catalog only", catalog_only_groups, CATEGORY_ORDER, normalized_query, catalog_only_result_count, true)
	result_label.text = "%d result%s · %d visualizable · %d catalog only" % [
		result_count,
		"" if result_count == 1 else "s",
		visualizable_result_count,
		catalog_only_result_count,
	]


func add_exercise_status_group(
	root_item: TreeItem,
	label: String,
	groups: Dictionary,
	preferred_order: Array,
	query: String,
	count: int,
	catalog_only: bool
) -> void:
	if count == 0:
		return
	var status_item := exercise_tree.create_item(root_item)
	status_item.set_text(0, "%s (%d)" % [label, count])
	status_item.set_selectable(0, false)
	status_item.set_selectable(1, false)
	status_item.collapsed = catalog_only and query.is_empty()
	for group in ordered_group_keys(groups, preferred_order):
		var records: Array = groups[group]
		var group_item := exercise_tree.create_item(status_item)
		group_item.set_text(0, "%s (%d)" % [family_label(group), records.size()])
		group_item.set_selectable(0, false)
		group_item.set_selectable(1, false)
		group_item.collapsed = query.is_empty()
		for record in records:
			var item := exercise_tree.create_item(group_item)
			item.set_text(0, String(record.get("name", record.get("id", ""))))
			item.set_text(1, String(record.get("variant", "")))
			item.set_tooltip_text(0, String(record.get("id", "")))
			item.set_metadata(0, record.get("id", ""))
			item.set_custom_color(1, Color("e3aa57") if catalog_only else Color("70d6a0"))


func exercise_matches(record: Dictionary, query: String) -> bool:
	if query.is_empty():
		return true
	var terms: Array[String] = [
		String(record.get("name", "")),
		String(record.get("variant", "")),
		String(record.get("id", "")),
	]
	for alias in record.get("aliases", []):
		terms.append(String(alias))
	for family in record.get("movement_families", []):
		terms.append(String(family).replace("_", " "))
	for field in ["category", "equipment", "level", "force", "mechanic"]:
		var field_value = record.get(field)
		if field_value != null:
			terms.append(str(field_value))
	for instruction in record.get("instructions", []):
		terms.append(String(instruction))
	var source_tags: Dictionary = record.get("source_muscle_tags", {})
	for tag in source_tags.get("primary", []):
		terms.append(String(tag))
	for tag in source_tags.get("secondary", []):
		terms.append(String(tag))
	return " ".join(terms).to_lower().contains(query)


func ordered_family_keys(groups: Dictionary) -> Array[String]:
	return ordered_group_keys(groups, FAMILY_ORDER)


func ordered_group_keys(groups: Dictionary, preferred_order: Array) -> Array[String]:
	var keys: Array[String] = []
	for family in preferred_order:
		if groups.has(family):
			keys.append(family)
	var remaining := groups.keys()
	remaining.sort()
	for family in remaining:
		if family not in keys:
			keys.append(String(family))
	return keys


func family_label(family: String) -> String:
	return family.replace("_", " ").capitalize()


func on_tree_item_selected() -> void:
	var item := exercise_tree.get_selected()
	if item == null:
		return
	var metadata = item.get_metadata(0)
	if metadata != null:
		select_exercise(str(metadata))


func on_exercise_tree_mouse_selected(position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	var item := exercise_tree.get_item_at_position(position)
	if item == null:
		return
	var metadata = item.get_metadata(0)
	if metadata == null:
		return
	var exercise_id := str(metadata)
	if exercise_id.is_empty():
		return
	item.select(0)
	select_exercise(exercise_id)
	show_exercise_images(exercise_id)


func show_exercise_images(exercise_id: String) -> bool:
	if not records_by_id.has(exercise_id):
		return false
	var record: Dictionary = records_by_id[exercise_id]
	var display_name := "%s · %s" % [
		record.get("name", exercise_id),
		record.get("variant", "Default"),
	]
	return image_modal.show_exercise(exercise_id, display_name)


func select_exercise(exercise_id: String, emit_selection := true) -> bool:
	if not records_by_id.has(exercise_id):
		return false
	selected_exercise_id = exercise_id
	update_details()
	populate_affected_structures(exercise_id)
	if emit_selection:
		if records_by_id[exercise_id].get("catalog_status") == "catalog_only":
			catalog_exercise_selected.emit(exercise_id)
		else:
			exercise_selected.emit(exercise_id)
	return true


func populate_affected_structures(exercise_id: String) -> void:
	affected_tree.clear()
	var root_item := affected_tree.create_item()
	if records_by_id.get(exercise_id, {}).get("catalog_status") == "catalog_only":
		affected_summary_label.text = "Catalog only · kinematic definition and review required before a heatmap is available."
		return
	var profile: Dictionary = profiles_by_exercise.get(exercise_id, {})
	var affected_by_role: Dictionary = {}
	for value in profile.get("muscles", []):
		if not value is Dictionary or float(value.get("coefficient", 0.0)) <= 0.0:
			continue
		var role := String(value.get("role", "other"))
		if not affected_by_role.has(role):
			affected_by_role[role] = []
		affected_by_role[role].append(value)

	var total_affected := 0
	for role in ordered_role_keys(affected_by_role):
		var muscles: Array = affected_by_role[role]
		muscles.sort_custom(compare_affected_muscles)
		var role_item := affected_tree.create_item(root_item)
		role_item.set_text(0, "%s (%d)" % [ROLE_LABELS.get(role, role.capitalize()), muscles.size()])
		for column in range(3):
			role_item.set_selectable(column, false)
		for muscle in muscles:
			add_affected_muscle_item(role_item, muscle)
			total_affected += 1
	affected_summary_label.text = "%d affected skeletal muscle%s · %d explicit zeroes" % [
		total_affected,
		"" if total_affected == 1 else "s",
		int(profile.get("zero_muscles", 466 - total_affected)),
	]
	if total_affected == 0:
		affected_summary_label.text = "No nonzero muscle mappings are available for this exercise."


func ordered_role_keys(groups: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for role in ROLE_ORDER:
		if groups.has(role):
			keys.append(role)
	var remaining := groups.keys()
	remaining.sort()
	for role in remaining:
		if role not in keys:
			keys.append(String(role))
	return keys


func compare_affected_muscles(a: Dictionary, b: Dictionary) -> bool:
	var a_coefficient := float(a.get("coefficient", 0.0))
	var b_coefficient := float(b.get("coefficient", 0.0))
	if not is_equal_approx(a_coefficient, b_coefficient):
		return a_coefficient > b_coefficient
	return affected_structure_name(String(a.get("muscle_id", ""))) < affected_structure_name(String(b.get("muscle_id", "")))


func add_affected_muscle_item(parent: TreeItem, muscle: Dictionary) -> void:
	var muscle_id := String(muscle.get("muscle_id", ""))
	var structure: Dictionary = structures_by_id.get(muscle_id, {})
	var item := affected_tree.create_item(parent)
	item.set_text(0, affected_structure_name(muscle_id))
	item.set_text(1, "%.0f%%" % (float(muscle.get("coefficient", 0.0)) * 100.0))
	item.set_text(2, String(muscle.get("confidence", "unknown")).capitalize())
	item.set_metadata(0, muscle_id)
	var evidence_refs: Array[String] = []
	for evidence_ref in muscle.get("evidence_refs", []):
		evidence_refs.append(String(evidence_ref))
	item.set_tooltip_text(0, "%s\nCanonical ID: %s\nDerivation: %s\nEvidence: %s" % [
		structure.get("name", muscle_id),
		muscle_id,
		derivation_label(String(muscle.get("derivation_method", "unknown"))),
		", ".join(evidence_refs) if not evidence_refs.is_empty() else "None recorded",
	])
	item.set_tooltip_text(1, "Engagement coefficient: %.3f" % float(muscle.get("coefficient", 0.0)))
	item.set_tooltip_text(2, "Confidence: %s\nEvidence status: %s" % [
		muscle.get("confidence", "unknown"),
		muscle.get("evidence_status", "unknown"),
	])


func affected_structure_name(muscle_id: String) -> String:
	var structure: Dictionary = structures_by_id.get(muscle_id, {})
	var name := String(structure.get("name", muscle_id))
	var side := String(structure.get("side", ""))
	return "%s (%s)" % [name, side.capitalize()] if not side.is_empty() else name


func derivation_label(method: String) -> String:
	if method == "kinematic_tracer_v3":
		return "Kinematic tracer v3"
	if method == "kinematic_tracer_v2":
		return "Kinematic tracer v2"
	if method == "kinematic_tracer_v1":
		return "Kinematic tracer v1"
	if method == "opensim_calibrated":
		return "OpenSim calibrated"
	if method == "manual_override":
		return "Manual review"
	return method.replace("_", " ").capitalize()


func on_affected_tree_item_selected() -> void:
	var item := affected_tree.get_selected()
	if item == null:
		return
	var structure_id := String(item.get_metadata(0))
	if not structure_id.is_empty():
		structure_selected.emit(structure_id)


func update_details() -> void:
	if details_label == null or selected_exercise_id.is_empty():
		return
	var record: Dictionary = records_by_id[selected_exercise_id]
	if record.get("catalog_status") == "catalog_only":
		var source_tags: Dictionary = record.get("source_muscle_tags", {})
		details_label.text = "%s\nCATALOG ONLY · %s · %s · %s\nSource tags (not evidence): %s" % [
			record.get("name", selected_exercise_id),
			source_value_label(record.get("category"), "Category unknown"),
			source_value_label(record.get("equipment"), "Equipment unknown"),
			source_value_label(record.get("level"), "Level unknown"),
			", ".join(source_tags.get("primary", [])),
		]
		return
	var families: Array[String] = []
	for family in record.get("movement_families", []):
		families.append(family_label(String(family)))
	var aliases: Array[String] = []
	for alias in record.get("aliases", []):
		aliases.append(String(alias))
	details_label.text = "%s · %s\n%s · %s · %s\nAliases: %s" % [
		record.get("name", selected_exercise_id),
		record.get("variant", "Default"),
		", ".join(families),
		String(record.get("laterality", "unknown")).capitalize(),
		String(record.get("input_mode", "unknown")).capitalize(),
		", ".join(aliases) if not aliases.is_empty() else "None",
	]


func get_selected_display_name() -> String:
	if not records_by_id.has(selected_exercise_id):
		return ""
	var record: Dictionary = records_by_id[selected_exercise_id]
	return "%s · %s" % [record.get("name", selected_exercise_id), record.get("variant", "Default")]


func source_value_label(value, fallback: String) -> String:
	return fallback if value == null or str(value).is_empty() else str(value).capitalize()
