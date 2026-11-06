extends SceneTree

## Regenerate authoring drafts through the real Kinematic Definition Studio,
## headless: open each source like a click in the catalog (which loads the
## saved draft and the latest council feedback into the context box), ask
## Claude for a new proposal, validate it with the candidate gate, and save.
##
##   godot --headless --path . --script res://tools/exercises/regenerate_drafts.gd ++ EZ-Bar_Curl Single-Arm_Push-Up
##
## Uses the Studio's saved model choice and the Anthropic key from user
## settings; every source is one billed authoring request.

const STUDIO_SCENE := preload("res://scenes/exercises/kinematic_definition_studio.tscn")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var source_ids := OS.get_cmdline_user_args()
	if source_ids.is_empty():
		push_error("Pass source IDs after ++, e.g. ++ EZ-Bar_Curl")
		quit(2)
		return
	var studio = STUDIO_SCENE.instantiate()
	root.add_child(studio)
	await process_frame
	var failures := 0
	for source_id in source_ids:
		var source: Dictionary = {}
		for record in studio.catalog:
			if record.get("source_id") == source_id:
				source = record
		if source.is_empty():
			print("SKIP %s: not a catalog-only source" % source_id)
			failures += 1
			continue
		# Same steps as selecting the row in the catalog tree.
		studio.selected_source = source
		studio.baseline_response = {}
		studio.context_input.text = ""
		studio.show_source()
		studio.discard_changes()
		studio.load_existing_draft()
		print("GENERATING %s with %s (context %d chars)" % [source_id, studio.model_id, studio.context_input.text.length()])
		var outcome := {"done": false, "error": ""}
		var on_ok := func(_response: Dictionary, _metadata: Dictionary) -> void: outcome["done"] = true
		var on_fail := func(message: String) -> void:
			outcome["done"] = true
			outcome["error"] = message
		studio.provider.generation_succeeded.connect(on_ok)
		studio.provider.generation_failed.connect(on_fail)
		studio.generate_proposal()
		while not outcome["done"]:
			await process_frame
		studio.provider.generation_succeeded.disconnect(on_ok)
		studio.provider.generation_failed.disconnect(on_fail)
		if not String(outcome["error"]).is_empty():
			print("FAILED %s: %s" % [source_id, outcome["error"]])
			failures += 1
			continue
		studio.save_draft()   # re-validates through the candidate gate, then saves
		var summary: Dictionary = studio.last_trace_report.get("summary", {})
		var definition: Dictionary = studio.current_response.get("proposed_definition", {}) if studio.current_response.get("proposed_definition") is Dictionary else {}
		var usage: Dictionary = studio.provider_metadata.get("usage", {})
		print("SAVED %s | gate ok=%s | %s | roles %s | demands %s | tokens in %s, cache read %s, cache write %s, out %s" % [
			source_id, studio.last_trace_report.get("ok", false), studio.current_response.get("classification", "?"),
			summary.get("role_counts", {}), definition.get("kinematic_profile", {}).get("stabilization_demands", []),
			usage.get("input_tokens", 0), usage.get("cache_read_input_tokens", 0),
			usage.get("cache_creation_input_tokens", 0), usage.get("output_tokens", 0)])
	studio.queue_free()
	quit(1 if failures else 0)
