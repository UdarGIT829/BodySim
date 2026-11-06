extends SceneTree

const COUNCIL_SCENE := preload("res://scenes/exercises/exercise_review_council.tscn")
const PROVIDER_SCENE := preload("res://scenes/exercises/openai_review_provider.tscn")
const ReviewRevisionStoreScript := preload("res://src/exercises/review/review_revision_store.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("verify")

func verify() -> void:
	var council = COUNCIL_SCENE.instantiate()
	root.add_child(council)
	await process_frame
	require(council.openai_api_key is String, "Council root must expose its internal API key")
	require(council.openai_model is String and not council.openai_model.is_empty(), "Council root must expose the review model")
	require(council.schema.get("$id") == "bodysim.kinematic_review_response.v1", "Council must load the strict review schema")
	require(council.model_option.item_count == 5, "Council must offer named model presets plus a custom model")
	require(council.get_node_or_null("Margin/Column/Workspace/BrowserPanel") != null, "Review queue must be editor-authored")
	require(council.get_node_or_null("Margin/Column/Workspace/EvidenceAndCouncil/Evidence/EvidenceTabs/Candidate heatmap/CandidateHeatmap") != null, "Candidate heatmap must be editor-authored")
	require(council.get_node_or_null("Margin/Column/Workspace/EvidenceAndCouncil/Council") != null, "Council decision panel must be editor-authored")
	require(council.reject_button is Button, "Council must expose an explicit candidate rejection action")
	require(ReviewRevisionStoreScript.council_status({}) == "review_pending", "No votes must remain pending")
	require(ReviewRevisionStoreScript.council_status({"human_owner": {"decision": "accept"}, "openai_reviewer": {"decision": "accept"}}) == "accepted", "Two accepts must satisfy unanimity")
	require(ReviewRevisionStoreScript.council_status({"human_owner": {"decision": "accept"}, "openai_reviewer": {"decision": "reject"}}) == "changes_requested", "Any rejection must request changes")
	var ineligible := {"status": "definition_candidate", "validation_errors": [], "candidate_trace_report": {}}
	require(not ReviewRevisionStoreScript.validate_eligibility(ineligible).is_empty(), "Draft without saved Phase 2C trace must not freeze")
	var provider = PROVIDER_SCENE.instantiate(); root.add_child(provider); await process_frame
	var body: Dictionary = provider.build_request_body("gpt-5.6-terra", "review", "frozen", {"type": "object"}, "data:image/jpeg;base64,AA==")
	require(body.get("text", {}).get("format", {}).get("strict") == true, "Review request must use strict Structured Outputs")
	require(body.get("text", {}).get("format", {}).get("name") == "bodysim_kinematic_review_response", "Review request must use its own schema name")
	require(body.get("input", [])[0].get("content", []).size() == 2, "Review request must send one contact-sheet image")
	var parsed: Dictionary = provider.extract_structured_output({"status": "completed", "output": [{"content": [{"type": "output_text", "text": "{\"decision\":\"accept\"}"}]}]})
	require(parsed.get("value", {}).get("decision") == "accept", "Review provider must parse structured output")
	council.queue_free(); provider.queue_free()
	if failures.is_empty():
		print("Phase 2D council passed: authored scene, frozen-revision policy, strict reviewer, and unanimous votes")
		quit(0)
	for failure in failures: push_error(failure)
	quit(1)

func require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
