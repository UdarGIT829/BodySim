extends SceneTree

const COUNCIL_SCENE := preload("res://scenes/exercises/exercise_review_council.tscn")
const PROVIDER_SCENE := preload("res://scenes/exercises/claude_provider.tscn")
const ReviewRevisionStoreScript := preload("res://src/exercises/review/review_revision_store.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("verify")

func verify() -> void:
	var council = COUNCIL_SCENE.instantiate()
	root.add_child(council)
	await process_frame
	require(council.model_id is String and council.model_id.begins_with("claude-"), "Council must select a Claude review model")
	require(council.provider is ClaudeProvider, "Council must use the Claude provider")
	require(council.schema.get("$id") == "bodysim.kinematic_review_response.v1", "Council must load the strict review schema")
	require(council.model_option.item_count == ClaudeSettings.MODEL_PRESETS.size(), "Council must offer the Claude model presets plus a custom model")
	require(council.get_node_or_null("Margin/Column/Workspace/BrowserPanel") != null, "Review queue must be editor-authored")
	require(council.get_node_or_null("Margin/Column/Workspace/EvidenceAndCouncil/Evidence/EvidenceTabs/Candidate heatmap/CandidateHeatmap") != null, "Candidate heatmap must be editor-authored")
	require(council.get_node_or_null("Margin/Column/Workspace/EvidenceAndCouncil/Council") != null, "Council decision panel must be editor-authored")
	require(council.reject_button is Button, "Council must expose an explicit candidate rejection action")
	require(ReviewRevisionStoreScript.council_status({}) == "review_pending", "No votes must remain pending")
	require(ReviewRevisionStoreScript.council_status({"human_owner": {"decision": "accept"}, "model_reviewer": {"decision": "accept"}}) == "accepted", "Two accepts must satisfy unanimity")
	require(ReviewRevisionStoreScript.council_status({"human_owner": {"decision": "accept"}, "model_reviewer": {"decision": "reject"}}) == "changes_requested", "Any rejection must request changes")
	require(ReviewRevisionStoreScript.council_status({"human_owner": {"decision": "accept"}, "openai_reviewer": {"decision": "accept"}}) == "review_pending", "A legacy OpenAI accept must not satisfy the Claude council")
	require(ReviewRevisionStoreScript.council_status({"human_owner": {"decision": "accept"}, "openai_reviewer": {"decision": "reject"}}) == "changes_requested", "Legacy rejections must still request changes")
	require(ReviewRevisionStoreScript.model_vote({"openai_reviewer": {"decision": "reject"}}).get("decision") == "reject", "Legacy model votes must still display")
	# Clearing rules (pure; nothing is written here).
	require(council.get_node_or_null("%RejectAndClearButton") is Button and council.get_node_or_null("%ClearRejectedButton") is Button, "Council must offer reject-and-clear and clear-all-rejected")
	require(council.get_node_or_null("%ShowClearedCheck") is CheckBox, "Council must let cleared candidates be shown again")
	var cleared := {"drafts": {"EZ-Bar_Curl": {"draft_saved_at_unix": 100.0}}, "revisions": {"abc": {}}}
	require(ReviewRevisionStoreScript.is_cleared("revision", {"revision_sha256": "abc"}, cleared), "Cleared revisions must be hidden")
	require(not ReviewRevisionStoreScript.is_cleared("revision", {"revision_sha256": "def"}, cleared), "Other revisions must stay visible")
	require(ReviewRevisionStoreScript.is_cleared("draft", {"source_id": "EZ-Bar_Curl", "saved_at_unix": 90.0}, cleared), "A cleared draft must stay hidden")
	require(not ReviewRevisionStoreScript.is_cleared("draft", {"source_id": "EZ-Bar_Curl", "saved_at_unix": 200.0}, cleared), "A draft saved again after clearing must reappear")
	require(not ReviewRevisionStoreScript.clear_blocker("draft", {"status": "definition_candidate"}).is_empty(), "Unrejected drafts must not be cleared directly")
	require(ReviewRevisionStoreScript.clear_blocker("draft", {"status": "review_rejected"}).is_empty(), "Rejected drafts must be clearable")
	var ineligible := {"status": "definition_candidate", "validation_errors": [], "candidate_trace_report": {}}
	require(not ReviewRevisionStoreScript.validate_eligibility(ineligible).is_empty(), "Draft without saved Phase 2C trace must not freeze")
	var provider = PROVIDER_SCENE.instantiate(); root.add_child(provider); await process_frame
	var request: Dictionary = provider.build_request("review", "claude-sonnet-5-5", {"revision": {"revision_sha256": "abc"}, "review_context": "ctx", "image_data_url": "data:image/jpeg;base64,AA=="})
	require(request.get("task") == "review" and request.get("model") == "claude-sonnet-5-5", "Review request must name the task and chosen model")
	require(request.get("revision", {}).get("revision_sha256") == "abc", "Review request must carry the exact frozen revision")
	council.queue_free(); provider.queue_free()
	if failures.is_empty():
		print("Phase 2D council passed: authored scene, frozen-revision policy, strict reviewer, and unanimous votes")
		quit(0)
	for failure in failures: push_error(failure)
	quit(1)

func require(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
