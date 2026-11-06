extends SceneTree

const STUDIO_SCENE := preload("res://scenes/exercises/kinematic_definition_studio.tscn")
const PROVIDER_SCENE := preload("res://scenes/exercises/openai_authoring_provider.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var studio = STUDIO_SCENE.instantiate()
	root.add_child(studio)
	await process_frame
	require(studio.openai_api_key is String, "Studio root must expose the internal API key field")
	require(studio.openai_model is String and not studio.openai_model.is_empty(), "Studio must expose a selected Structured Outputs model")
	require(studio.model_option.item_count == 5, "Studio must provide four model presets and a custom model option")
	require(studio.active_model_label.text.contains(studio.openai_model), "Studio must show the exact active model ID")
	require(studio.get_node_or_null("Margin/Column/Workspace/CatalogPanel") != null, "Catalog panel must be editor-authored")
	require(studio.get_node_or_null("Margin/Column/Workspace/DefinitionAndEvidence/DefinitionPanel") != null, "Visual definition panel must be editor-authored")
	require(studio.get_node_or_null("Margin/Column/Workspace/DefinitionAndEvidence/EvidencePanel/Tabs/Advanced JSON/JsonEditor") is TextEdit, "Advanced JSON editor must be editor-authored")
	require(studio.catalog.size() == 853, "Studio must load all 853 catalog-only records")
	require(studio.schema.get("$id") == "bodysim.kinematic_authoring_response.v1", "Studio must load the versioned authoring schema")

	var provider = PROVIDER_SCENE.instantiate()
	root.add_child(provider)
	await process_frame
	var body: Dictionary = provider.build_request_body("gpt-5-mini", "system", "source", {"type": "object"})
	require(body.get("text", {}).get("format", {}).get("type") == "json_schema", "Responses request must use Structured Outputs")
	require(body.get("text", {}).get("format", {}).get("strict") == true, "Responses request schema must be strict")
	var vision_body: Dictionary = provider.build_request_body("gpt-5-mini", "system", "source", {"type": "object"}, "data:image/jpeg;base64,AA==")
	var vision_content: Array = vision_body.get("input", [])[0].get("content", [])
	require(vision_content.size() == 2, "Vision request must contain one text input and one image input")
	require(vision_content[1].get("type") == "input_image", "Contact sheet must use the Responses input_image type")
	require(vision_content[1].get("detail") == "high", "Exercise contact sheet must request high image detail")
	var sheet: Image = studio.build_contact_sheet_image(studio.catalog[0])
	require(not sheet.is_empty(), "Studio must compose imported source images into a contact sheet")
	require(sheet.get_width() > sheet.get_height(), "Two-frame contact sheet must place frames in a horizontal row")
	require(studio.build_contact_sheet_data_url(studio.catalog[0]).begins_with("data:image/jpeg;base64,"), "Studio must encode the contact sheet as one JPEG data URL")
	var output := {"status": "completed", "output": [{"content": [{"type": "output_text", "text": "{\"classification\":\"unsupported\"}"}]}]}
	require(provider.extract_structured_output(output).get("value", {}).get("classification") == "unsupported", "Provider must parse Responses output_text")
	var refusal := {"status": "completed", "output": [{"content": [{"type": "refusal", "refusal": "cannot comply"}]}]}
	require(not provider.extract_structured_output(refusal).get("ok", false), "Provider must reject refusals")

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
