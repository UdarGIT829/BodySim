extends SceneTree

## Screenshots for the project page (web/site/screenshots/). Sets each scene
## up in code and saves the window, so no input is sent to the desktop.
## Needs a display (the renderer runs), not --headless:
##
##   godot --path . --resolution 1600x900 --script res://tools/web/take_screenshots.gd
##   godot ... --script res://tools/web/take_screenshots.gd ++ hero studio   # only some shots

const OUT_DIR := "res://web/site/screenshots"
const PREVIEW := preload("res://scenes/anatomy/whole_body_preview.tscn")
const STUDIO := preload("res://scenes/exercises/kinematic_definition_studio.tscn")
const COUNCIL := preload("res://scenes/exercises/exercise_review_council.tscn")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var only := OS.get_cmdline_user_args()
	var shots := {
		"hero": shot_preview.bind("exercise.barbell_back_squat.high_bar", &"whole", "", false),
		"back": shot_preview.bind("exercise.pull_up.pronated", &"whole_back", "", false),
		"catalog": shot_preview.bind("exercise.biceps_curl.dumbbell_standing", &"whole", "curl", false),
		"photos": shot_preview.bind("exercise.barbell_deadlift.conventional", &"whole", "", true),
		"studio": shot_studio,
		"council": shot_council,
	}
	for shot_name in shots:
		if only.is_empty() or shot_name in only:
			await shots[shot_name].call(shot_name)
	quit(0)


func settle(frames := 30) -> void:
	for i in frames:
		await process_frame


func save(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() > 1600:   # page-sized JPEGs
		image.resize(1600, roundi(float(image.get_height()) * 1600.0 / float(image.get_width())), Image.INTERPOLATE_LANCZOS)
	var path := "%s/%s.jpg" % [OUT_DIR, shot_name]
	image.save_jpg(path, 0.84)
	print("saved %s (%dx%d)" % [path, image.get_width(), image.get_height()])


func shot_preview(shot_name: String, exercise_id: String, preset: StringName, search: String, photos: bool) -> void:
	var preview = PREVIEW.instantiate()
	root.add_child(preview)
	await settle(20)
	var selector = preview.exercise_selector
	if not search.is_empty():
		selector.search_input.text = search
		selector.populate_exercises(search)
	selector.select_exercise(exercise_id)
	if preset == &"whole_back":   # the whole body, seen from behind
		preview.focus(Vector3(0.0, 0.92, 0.0), 2.9, PI)
	else:
		preview.focus_preset(preset)
	if photos:
		selector.show_exercise_images(exercise_id)
	await settle(60)   # meshes, materials and photos
	await save(shot_name)
	preview.queue_free()
	await settle(5)


func shot_studio(shot_name: String) -> void:
	var studio = STUDIO.instantiate()
	root.add_child(studio)
	await settle(10)
	studio.search_input.text = "kettlebell"
	studio.populate_catalog("kettlebell")
	for source in studio.catalog:
		if source.get("source_id") == "Advanced_Kettlebell_Windmill":
			studio.selected_source = source
	studio.show_source()
	studio.discard_changes()
	studio.load_existing_draft()
	await settle(30)
	await save(shot_name)
	studio.queue_free()
	await settle(5)


func shot_council(shot_name: String) -> void:
	var council = COUNCIL.instantiate()
	root.add_child(council)
	await settle(10)
	# A reviewed revision with Claude's findings: the first Single-Arm Push-Up rejection under v2.
	for revision in ReviewRevisionStore.list_revisions():
		if String(revision.get("revision_sha256", "")).begins_with("408c883d"):
			council.selected_entry = {"kind": "revision", "data": revision}
			council.show_revision(revision)
	await settle(60)
	await save(shot_name)
	council.queue_free()
	await settle(5)
