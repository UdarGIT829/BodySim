extends SceneTree

const SELECTOR_SCENE := preload("res://scenes/exercises/exercise_selector.tscn")

var failures: Array[String] = []
var emitted_exercise_id := ""
var emitted_catalog_id := ""
var emitted_structure_id := ""


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var selector = SELECTOR_SCENE.instantiate()
	selector.exercise_selected.connect(func(exercise_id: String) -> void: emitted_exercise_id = exercise_id)
	selector.catalog_exercise_selected.connect(func(catalog_id: String) -> void: emitted_catalog_id = catalog_id)
	selector.structure_selected.connect(func(structure_id: String) -> void: emitted_structure_id = structure_id)
	root.add_child(selector)
	await process_frame

	require(selector.records_by_id.size() == 874, "Selector must represent all 873 source records plus the split squat variant")
	require(selector.image_modal.media_by_exercise.size() == 894, "Image modal must map all source records and promoted variants")
	require(selector.result_count == 874, "Empty search must show the complete merged catalog")
	require(selector.visualizable_result_count == 21, "Selector must retain all 21 visualizable variants")
	require(selector.catalog_only_result_count == 853, "Selector must label all 853 unpromoted source records catalog only")
	selector.populate_exercises("rdl")
	require(selector.result_count >= 1, "Search must include exercise aliases")
	selector.populate_exercises("vertical pull")
	require(selector.result_count == 2, "Search must include movement-family names")
	selector.populate_exercises("")

	var exercise_id := "exercise.ab_wheel_rollout.kneeling"
	require(selector.select_exercise(exercise_id), "Selector must accept a supported canonical ID")
	require(selector.selected_exercise_id == exercise_id, "Selector must preserve canonical exercise identity")
	require(emitted_exercise_id == exercise_id, "Selector must emit the selected canonical ID")
	require(selector.get_selected_display_name().contains("Kneeling Ab Wheel Rollout"), "Selector must expose the selected display name")
	require(count_selectable_tree_items(selector.affected_tree.get_root()) == 8, "Ab wheel profile must list its eight affected muscles")
	require(selector.affected_summary_label.text.contains("8 affected skeletal muscles"), "Affected summary must report nonzero mappings")
	var first_muscle_item: TreeItem = selector.affected_tree.get_root().get_first_child().get_first_child()
	require(first_muscle_item.get_text(1) == "85%", "Affected tree must display the engagement coefficient")
	require(selector.affected_tree.columns == 3, "Affected tree must use the compact three-column layout")
	require(first_muscle_item.get_tooltip_text(0).contains("Kinematic tracer v1"), "Affected structure tooltip must preserve derivation provenance")
	first_muscle_item.select(0)
	selector.affected_tree.item_selected.emit()
	require(emitted_structure_id.begins_with("muscle."), "Affected muscle selection must emit its canonical structure ID")
	selector.populate_exercises("ab wheel")
	await process_frame
	var exercise_row: TreeItem = selector.exercise_tree.get_root().get_first_child().get_first_child().get_first_child()
	var exercise_row_rect: Rect2 = selector.exercise_tree.get_item_area_rect(exercise_row, 0)
	selector.on_exercise_tree_mouse_selected(exercise_row_rect.get_center(), MOUSE_BUTTON_RIGHT)
	require(selector.image_modal.visible, "Right-clicking an exercise row must open the image modal")
	require(selector.image_modal.current_exercise_id == exercise_id, "Image modal must preserve canonical exercise identity")
	require(selector.image_modal.first_image.texture != null, "Image modal must load the first local image")
	require(selector.image_modal.second_image.texture != null, "Image modal must load the second local image")
	selector.image_modal.hide()
	var catalog_id := "catalog.free_exercise_db.3_4_Sit-Up"
	require(selector.select_exercise(catalog_id), "Catalog-only source record must be selectable")
	require(emitted_catalog_id == catalog_id, "Catalog-only selection must emit its distinct catalog signal")
	require(selector.affected_summary_label.text.begins_with("Catalog only"), "Catalog-only selection must not claim an engagement profile")
	require(selector.show_exercise_images(catalog_id), "Catalog-only records must retain their local source images")
	selector.image_modal.hide()
	require(not selector.select_exercise("exercise.not_supported"), "Selector must reject unsupported IDs")

	if failures.is_empty():
		print("Exercise selector passed: 21 visualizable variants + 853 catalog-only records")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func count_selectable_tree_items(item: TreeItem) -> int:
	if item == null:
		return 0
	var metadata = item.get_metadata(0)
	var count := 1 if metadata != null and not str(metadata).is_empty() else 0
	var child := item.get_first_child()
	while child != null:
		count += count_selectable_tree_items(child)
		child = child.get_next()
	return count
