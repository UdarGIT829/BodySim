extends SceneTree

const STUDIO_SCENE := preload("res://scenes/exercises/kinematic_definition_studio.tscn")
const PROVIDER_SCENE := preload("res://scenes/exercises/claude_provider.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var studio = STUDIO_SCENE.instantiate()
	root.add_child(studio)
	await process_frame
	require(studio.model_id is String and studio.model_id.begins_with("claude-"), "Studio must select a Claude model")
	require(studio.model_option.item_count == ClaudeSettings.MODEL_PRESETS.size(), "Studio must offer the Claude model presets plus a custom model option")
	require(studio.active_model_label.text.contains(studio.model_id), "Studio must show the exact active model ID")
	require(studio.provider is ClaudeProvider, "Studio must use the Claude provider")
	require(studio.get_node_or_null("Margin/Column/Workspace/CatalogPanel") != null, "Catalog panel must be editor-authored")
	require(studio.get_node_or_null("Margin/Column/Workspace/DefinitionAndEvidence/DefinitionPanel") != null, "Visual definition panel must be editor-authored")
	require(studio.get_node_or_null("Margin/Column/Workspace/DefinitionAndEvidence/EvidencePanel/Tabs/Advanced JSON/JsonEditor") is TextEdit, "Advanced JSON editor must be editor-authored")
	var catalog_only := 0
	for source in JSON.parse_string(FileAccess.get_file_as_string("res://data/exercises/catalog/candidates.json")):
		if source.get("status") == "catalog_only": catalog_only += 1
	require(studio.catalog.size() == catalog_only and catalog_only > 800, "Studio must load every catalog-only record")
	require(studio.get_node_or_null("%AutoButton") is Button and studio.get_node_or_null("%AutoRunModal") is AutoRunModal, "Studio must offer auto mode")
	require(studio.schema.get("$id") == "bodysim.kinematic_authoring_response.v3", "Studio must load the versioned authoring schema")
	# Tracer v3 fields survive the form: per-action emphasis/sides and one_sided_limbs.
	var v3_definition := {"id": "exercise.form_check.standard", "name": "Form check", "variant": "standard", "aliases": ["form check"],
		"movement_families": ["hip_hinge"], "laterality": "unilateral", "input_mode": "repetitions",
		"kinematic_profile": {"kinetic_chain_type": "closed_chain", "one_sided_limbs": ["arm"], "stabilization_demands": ["grip"],
			"primary_joint_actions": [{"joint": "hip_joint", "movement": "extension", "emphasis": "primary", "sides": "both"},
				{"joint": "ankle_joint", "movement": "plantarflexion", "emphasis": "assist", "sides": "working"}]}}
	studio.populate_form(v3_definition)
	var rebuilt: Dictionary = studio.build_definition_from_form()
	require(rebuilt["kinematic_profile"].get("one_sided_limbs") == ["arm"], "one_sided_limbs survives the form")
	require(rebuilt["kinematic_profile"]["primary_joint_actions"] == v3_definition["kinematic_profile"]["primary_joint_actions"], "emphasis and sides survive the form")
	require(studio.actions_tree.get_root().get_child(1).get_text(1).contains("assist"), "the action list shows assist")
	studio.assist_check.button_pressed = true
	studio.select_metadata(studio.joint_option, "knee_joint")
	studio.populate_movement_options()
	studio.select_metadata(studio.movement_option, "flexion")
	studio.add_joint_action()
	require(studio.joint_actions[-1].get("emphasis") == "assist" and studio.joint_actions[-1].get("sides") == "working", "Add uses the Assist and Both sides boxes")
	studio.one_sided_option.select(0)
	require(not studio.build_definition_from_form()["kinematic_profile"].has("one_sided_limbs"), "'Infer from actions' leaves the field out")
	studio.discard_changes()

	var provider = PROVIDER_SCENE.instantiate()
	root.add_child(provider)
	await process_frame
	var request: Dictionary = provider.build_request("author", "claude-opus-5-5", {"context": "source", "image_data_url": "data:image/jpeg;base64,AA=="})
	require(request.get("task") == "author" and request.get("model") == "claude-opus-5-5", "Authoring request must name the task and model")
	require(request.get("context") == "source" and String(request.get("image_data_url")).begins_with("data:image/jpeg"), "Authoring request must carry the source text and contact sheet")
	require(String(request.get("settings_path")).ends_with("bodysim_authoring_settings.cfg"), "Bridge must be told where the key settings live")
	require(not JSON.stringify(request).contains("sk-"), "Requests must never carry an API key")
	var sheet: Image = studio.build_contact_sheet_image(studio.catalog[0])
	require(not sheet.is_empty(), "Studio must compose imported source images into a contact sheet")
	require(sheet.get_width() > sheet.get_height(), "Two-frame contact sheet must place frames in a horizontal row")
	require(studio.build_contact_sheet_data_url(studio.catalog[0]).begins_with("data:image/jpeg;base64,"), "Studio must encode the contact sheet as one JPEG data URL")
	# Real thread + Python bridge round trip, rejected before any API call.
	var failures_seen: Array[String] = []
	provider.review_failed.connect(func(message: String) -> void: failures_seen.append(message))
	provider.review("claude-opus-5-5", {}, "")
	require(provider.is_busy(), "Provider must run the bridge on a worker thread")
	var waited := 0
	while failures_seen.is_empty() and waited < 600:
		await process_frame
		waited += 1
	require(failures_seen.size() == 1 and failures_seen[0].contains("frozen revision"), "Bridge errors must come back through the failure signal: %s" % [failures_seen])
	require(not provider.is_busy(), "Provider must release its worker thread")

	var supported: Dictionary = studio.default_supported_response()
	supported["proposed_definition"] = {
		"id": "exercise.phase2b_test.standard",
		"name": "Phase 2B Test",
		"variant": "Standard",
		"aliases": ["phase 2b test"],
		"movement_families": ["squat"],
		"laterality": "bilateral",
		"input_mode": "repetitions",
		"kinematic_profile": {
			"kinetic_chain_type": "closed_chain",
			"primary_joint_actions": [{"joint": "knee_joint", "movement": "extension"}],
			"stabilization_demands": ["anti_flexion_spine"],
		},
	}
	require(CandidateValidators.validate_authoring_response(supported, studio.canonical_ids).is_empty(), "Valid supported response must pass the deterministic gate")
	var trace_report: Dictionary = studio.candidate_trace_gate.evaluate(supported["proposed_definition"])
	require(trace_report.get("ok", false), "Valid definition must pass the isolated Python tracer gate")
	require(trace_report.get("summary", {}).get("total_muscles", 0) == 466, "Python tracer gate must produce all 466 canonical muscles")
	require(trace_report.get("summary", {}).get("mapped_muscles", 0) > 0, "Python tracer gate must map at least one affected muscle")
	studio.current_response = supported.duplicate(true)
	studio.populate_form(studio.current_response["proposed_definition"])
	var integrated_errors: Array[String] = studio.validate_current()
	require(integrated_errors.is_empty(), "Studio validation must include and pass the Python tracer gate")
	require(studio.trace_summary_label.text.contains("Python tracer PASS"), "Candidate gate tab must show the tracer result")
	require(not studio.submit_button.disabled, "Passing authoring and tracer gates must enable candidate submission")
	supported["questions_requiring_context"] = ["Which stance?"]
	require(not CandidateValidators.validate_authoring_response(supported, studio.canonical_ids).is_empty(), "Supported response with unresolved questions must fail")
	var ambiguous := supported.duplicate(true)
	ambiguous["classification"] = "ambiguous"
	ambiguous["proposed_definition"] = null
	require(not CandidateValidators.validate_authoring_response(ambiguous, studio.canonical_ids).is_empty(), "Ambiguous response must not advance through the candidate gate")
	var malformed_id := supported.duplicate(true)
	malformed_id["classification_reasons"] = []
	malformed_id["proposed_definition"]["id"] = "phase2b_test_standard"
	var normalized: Dictionary = studio.normalize_generated_response(malformed_id)
	require(normalized["proposed_definition"]["id"] == "exercise.phase_2b_test.standard", "Studio must deterministically normalize malformed model IDs")
	require(not normalized["classification_reasons"].is_empty(), "ID normalization must be visible in classification reasons")
	var provider_shape := supported.duplicate(true)
	provider_shape["proposed_definition"].erase("movement_families")
	provider_shape["proposed_definition"]["primary_movement_family"] = "squat"
	provider_shape["proposed_definition"]["additional_movement_families"] = ["hip_hinge", "squat"]
	var normalized_families: Dictionary = studio.normalize_generated_response(provider_shape)
	require(normalized_families["proposed_definition"]["movement_families"] == ["squat", "hip_hinge"], "Studio must normalize required primary and optional additional movement families")
	var legacy := normalized.duplicate(true)
	legacy["field_confidence"]["load_vector"] = "high"
	legacy["proposed_definition"]["kinematic_profile"]["load_vector"] = "legacy_vector"
	var stripped: Dictionary = studio.strip_deprecated_load_vector(legacy)
	require(not stripped["field_confidence"].has("load_vector"), "Studio must remove deprecated load-vector confidence from active drafts")
	require(not stripped["proposed_definition"]["kinematic_profile"].has("load_vector"), "Studio must remove deprecated load vectors from active definitions")

	studio.queue_free()
	provider.queue_free()
	if failures.is_empty():
		print("Kinematic Definition Studio passed: authored UI, strict request, response parsing, and candidate gate")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
