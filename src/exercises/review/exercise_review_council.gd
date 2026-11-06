class_name ExerciseReviewCouncil
extends Control

## Claude model used by the council's model member (saved as [anthropic] review_model).
var model_id: String = ClaudeSettings.DEFAULT_MODEL
const CATALOG_PATH := "res://data/exercises/catalog/candidates.json"
const DRAFT_DIR := "res://data/exercises/authoring/drafts"
const SCHEMA_PATH := "res://data/exercises/authoring/schemas/kinematic_review_response.schema.json"
const PROMPT_PATH := "res://data/exercises/authoring/prompts/review_v2.md"
const MEDIA_ROOT := "res://assets/exercises/free_exercise_db"
const SETTINGS_PATH := "user://bodysim_authoring_settings.cfg"
const ReviewRevisionStoreScript := preload("res://src/exercises/review/review_revision_store.gd")

@onready var provider: ClaudeProvider = $ClaudeProvider
@onready var candidate_tree: Tree = %CandidateTree
@onready var source_title: Label = %SourceTitle
@onready var source_meta: Label = %SourceMetadata
@onready var source_instructions: RichTextLabel = %SourceInstructions
@onready var source_image_a: TextureRect = %SourceImageA
@onready var source_image_b: TextureRect = %SourceImageB
@onready var revision_label: Label = %RevisionLabel
@onready var status_label: Label = %StatusLabel
@onready var definition_json: TextEdit = %DefinitionJson
@onready var interpretation_text: RichTextLabel = %InterpretationText
@onready var muscles_tree: Tree = %MusclesTree
@onready var validation_text: RichTextLabel = %ValidationText
@onready var prior_feedback_text: RichTextLabel = %PriorFeedbackText
@onready var comparison_text: RichTextLabel = %ComparisonText
@onready var heatmap: Control = %CandidateHeatmap
@onready var model_option: OptionButton = %ModelOption
@onready var custom_model_input: LineEdit = %CustomModelInput
@onready var review_context: TextEdit = %ReviewContext
@onready var model_result: RichTextLabel = %ModelResult
@onready var human_decision: OptionButton = %HumanDecision
@onready var human_feedback: TextEdit = %HumanFeedback
@onready var freeze_button: Button = %FreezeButton
@onready var reject_button: Button = %RejectButton
@onready var request_review_button: Button = %RequestReviewButton

var catalog_by_source: Dictionary = {}
var entries: Array[Dictionary] = []
var selected_entry: Dictionary = {}
var current_revision: Dictionary = {}
var schema: Dictionary = {}
var system_prompt := ""
var pending_model_vote: Dictionary = {}

func _ready() -> void:
	configure_ui()
	load_support_files()
	load_model_preference()
	configure_model_selector()
	reload_entries()
	provider.review_succeeded.connect(_on_model_review_succeeded)
	provider.review_failed.connect(func(message: String) -> void:
		request_review_button.disabled = false
		set_status(message, true))
	candidate_tree.item_selected.connect(_on_candidate_selected)
	freeze_button.pressed.connect(freeze_selected_draft)
	reject_button.pressed.connect(reject_selected_candidate)
	request_review_button.pressed.connect(request_model_review)
	%RecordHumanVoteButton.pressed.connect(record_human_vote)
	%PromoteButton.pressed.connect(promote_current_revision)
	%RejectAndClearButton.pressed.connect(reject_and_clear_selected)
	%ClearRejectedButton.pressed.connect(clear_all_rejected)
	%ShowClearedCheck.toggled.connect(func(_on: bool) -> void: populate_tree())
	%AutoButton.pressed.connect(open_auto_mode)
	%AutoRunModal.run_finished.connect(func(_state: String) -> void: reload_entries())
	model_option.item_selected.connect(_on_model_selected)
	custom_model_input.text_changed.connect(_on_custom_model_changed)
	set_status("Select a passing candidate draft or frozen revision.", false)

func configure_ui() -> void:
	candidate_tree.set_column_title(0, "Candidate / revision")
	candidate_tree.set_column_title(1, "State")
	muscles_tree.set_column_title(0, "Affected structure")
	muscles_tree.set_column_title(1, "Role")
	muscles_tree.set_column_title(2, "Coefficient")
	for value in ["accept", "reject"]:
		human_decision.add_item(value.capitalize())
		human_decision.set_item_metadata(human_decision.item_count - 1, value)

func load_support_files() -> void:
	var catalog = read_json(CATALOG_PATH)
	if catalog is Array:
		for source in catalog: catalog_by_source[String(source.get("source_id", ""))] = source
	var parsed_schema = read_json(SCHEMA_PATH)
	if parsed_schema is Dictionary: schema = parsed_schema
	var prompt := FileAccess.open(PROMPT_PATH, FileAccess.READ)
	if prompt: system_prompt = prompt.get_as_text()

func reload_entries() -> void:
	entries.clear()
	var directory := DirAccess.open(DRAFT_DIR)
	if directory:
		for filename in directory.get_files():
			if filename.ends_with(".json"):
				var draft = read_json("%s/%s" % [DRAFT_DIR, filename])
				if draft is Dictionary: entries.append({"kind": "draft", "data": draft})
	for revision in ReviewRevisionStoreScript.list_revisions(): entries.append({"kind": "revision", "data": revision})
	populate_tree()

func populate_tree() -> void:
	candidate_tree.clear()
	var root := candidate_tree.create_item()
	var drafts := candidate_tree.create_item(root); drafts.set_text(0, "Candidate drafts")
	var revisions := candidate_tree.create_item(root); revisions.set_text(0, "Frozen revisions")
	var cleared := ReviewRevisionStoreScript.load_cleared()
	var show_cleared: bool = %ShowClearedCheck.button_pressed
	var hidden := 0
	for index in entries.size():
		var entry := entries[index]
		var data: Dictionary = entry["data"]
		var is_cleared := ReviewRevisionStoreScript.is_cleared(String(entry["kind"]), data, cleared)
		if is_cleared and not show_cleared:
			hidden += 1
			continue
		var parent := drafts if entry["kind"] == "draft" else revisions
		var item := candidate_tree.create_item(parent)
		var source: Dictionary = catalog_by_source.get(String(data.get("source_id", "")), data.get("source", {}))
		item.set_text(0, String(source.get("name", data.get("source_id", "Unknown"))))
		if entry["kind"] == "draft":
			if data.get("status", "") == "review_rejected":
				item.set_text(1, "Rejected")
			else:
				var eligible: bool = ReviewRevisionStoreScript.validate_eligibility(data).is_empty()
				item.set_text(1, "Ready to freeze" if eligible else "Needs Phase 2C save")
		else:
			var review: Dictionary = ReviewRevisionStoreScript.load_review(data.get("revision_sha256", ""))
			var promoted := not ReviewRevisionStoreScript.load_promotion(String(data.get("revision_sha256", ""))).is_empty()
			item.set_text(1, "promoted" if promoted else review.get("status", "review_pending"))
		if is_cleared:
			item.set_text(1, "%s · cleared" % item.get_text(1))
			item.set_custom_color(0, Color(0.55, 0.58, 0.64))
		item.set_metadata(0, index)
	drafts.collapsed = false; revisions.collapsed = false
	%ShowClearedCheck.text = "Show cleared (%d hidden)" % hidden if hidden > 0 else "Show cleared"

func _on_candidate_selected() -> void:
	var item := candidate_tree.get_selected()
	if item == null or item.get_metadata(0) == null: return
	selected_entry = entries[int(item.get_metadata(0))]
	if selected_entry["kind"] == "revision":
		show_revision(selected_entry["data"])
	else:
		show_draft(selected_entry["data"])

func show_draft(draft: Dictionary) -> void:
	current_revision = {}
	show_source(catalog_by_source.get(String(draft.get("source_id", "")), {}))
	show_payload(draft)
	var errors: Array[String] = ReviewRevisionStoreScript.validate_eligibility(draft)
	revision_label.text = "Not frozen"
	validation_text.text = "[color=%s]%s[/color]" % ["#68dda5" if errors.is_empty() else "#ff7676", "Phase 2C PASS — ready to freeze" if errors.is_empty() else "\n".join(errors)]
	freeze_button.disabled = not errors.is_empty()
	reject_button.disabled = draft.get("status", "") == "review_rejected"
	request_review_button.disabled = true
	load_votes({})
	if draft.get("status", "") == "review_rejected":
		var rejection: Dictionary = draft.get("rejection", {})
		prior_feedback_text.text = "[color=#ff7676][b]Rejected by human owner[/b][/color]\n%s" % rejection.get("summary", "No reason recorded.")

func freeze_selected_draft() -> void:
	if selected_entry.get("kind") != "draft": return
	var draft: Dictionary = selected_entry["data"]
	var source: Dictionary = catalog_by_source.get(String(draft.get("source_id", "")), {})
	var result: Dictionary = ReviewRevisionStoreScript.freeze_draft(draft, source)
	if not result.get("ok", false): return set_status("Freeze blocked: %s" % " ".join(result.get("errors", [])), true)
	show_revision(result["revision"])
	set_status("Frozen immutable revision %s." % result["revision"].get("revision_id", ""), false)
	reload_entries()

func reject_selected_candidate() -> void:
	if selected_entry.is_empty(): return
	var feedback := human_feedback.text.strip_edges()
	if feedback.is_empty(): return set_status("Add a rejection reason in the human feedback field first.", true)
	if selected_entry.get("kind") == "draft":
		var result: Dictionary = ReviewRevisionStoreScript.reject_unfrozen_draft(selected_entry["data"], feedback)
		if not result.get("ok", false): return set_status(result.get("error", "Could not reject candidate."), true)
		selected_entry["data"] = result["record"]
		show_draft(result["record"])
		reload_entries()
		set_status("Candidate rejected and retained in the audit history.", false)
		return
	var vote := {
		"decision": "reject",
		"summary": feedback,
		"blocking_findings": [{"field_path": "review.human", "finding": feedback, "suggested_correction": feedback}],
		"non_blocking_findings": [],
		"confidence": "high",
		"recorded_at_unix": Time.get_unix_time_from_system(),
	}
	var result: Dictionary = ReviewRevisionStoreScript.save_vote(current_revision.get("revision_sha256", ""), "human_owner", vote, review_context.text)
	if not result.get("ok", false): return set_status(result.get("error", "Could not reject revision."), true)
	load_votes(result["record"])
	populate_tree()
	set_status("Frozen revision rejected by the human owner; changes are now requested.", false)

func reject_and_clear_selected() -> void:
	if selected_entry.is_empty(): return set_status("Select a candidate to reject and clear.", true)
	var kind := String(selected_entry["kind"])
	var data: Dictionary = selected_entry["data"]
	if kind == "revision" and not ReviewRevisionStoreScript.load_promotion(String(data.get("revision_sha256", ""))).is_empty():
		return set_status("Promoted revisions are part of the catalog history and can't be cleared.", true)
	if human_feedback.text.strip_edges().is_empty():
		human_feedback.text = "Cleared from the review queue."
	var already_rejected: bool = data.get("status", "") == "review_rejected" if kind == "draft" else ReviewRevisionStoreScript.load_review(String(data.get("revision_sha256", ""))).get("status", "") == "changes_requested"
	if not already_rejected:
		reject_selected_candidate()
		data = selected_entry["data"]
	var result: Dictionary = ReviewRevisionStoreScript.clear_entries([{"kind": kind, "data": data}], human_feedback.text.strip_edges())
	if not result.get("ok", false): return set_status(result.get("error", "Could not clear the candidate."), true)
	selected_entry = {}
	reload_entries()
	set_status("Rejected and cleared from the queue (kept on disk for the audit trail).", false)

func clear_all_rejected() -> void:
	var rejected: Array = []
	for entry in entries:
		var data: Dictionary = entry["data"]
		if entry["kind"] == "draft" and data.get("status", "") == "review_rejected":
			rejected.append(entry)
		elif entry["kind"] == "revision" and ReviewRevisionStoreScript.clear_blocker("revision", data).is_empty() \
				and ReviewRevisionStoreScript.load_review(String(data.get("revision_sha256", ""))).get("status", "") == "changes_requested":
			rejected.append(entry)
	var result: Dictionary = ReviewRevisionStoreScript.clear_entries(rejected, "Cleared rejected candidates in bulk.")
	if not result.get("ok", false): return set_status(result.get("error", "Could not clear candidates."), true)
	reload_entries()
	set_status("Cleared %d rejected candidate(s). Nothing was deleted; tick Show cleared to see them." % result.get("cleared", 0), false)

func show_revision(revision: Dictionary) -> void:
	current_revision = revision
	show_source(revision.get("source", {}))
	show_payload(revision)
	revision_label.text = "Frozen SHA-256\n%s" % revision.get("revision_sha256", "")
	var trace: Dictionary = revision.get("candidate_trace_report", {})
	validation_text.text = "[color=#68dda5]Deterministic gate PASS[/color]\n466 / 466 canonical muscles\nTracer: %s\nStructures: %s" % [trace.get("provenance", {}).get("tracer", ""), trace.get("provenance", {}).get("structures_sha256", "")]
	freeze_button.disabled = true
	reject_button.disabled = false
	request_review_button.disabled = false
	load_votes(ReviewRevisionStoreScript.load_review(revision.get("revision_sha256", "")))

func show_source(source: Dictionary) -> void:
	source_title.text = source.get("name", "Unknown source")
	source_meta.text = "%s · %s · %s" % [source.get("category", "—"), source.get("equipment", "—"), source.get("level", "—")]
	var lines := ""; var step := 1
	for instruction in source.get("instructions", []): lines += "[b]%d.[/b] %s\n\n" % [step, instruction]; step += 1
	source_instructions.text = lines
	var images: Array = source.get("source_images", [])
	set_image(source_image_a, images[0] if images.size() > 0 else "")
	set_image(source_image_b, images[1] if images.size() > 1 else "")

func show_payload(record: Dictionary) -> void:
	var response: Dictionary = record.get("authoring_response", {})
	definition_json.text = JSON.stringify(response.get("proposed_definition", {}), "  ")
	interpretation_text.text = "[b]Assumptions[/b]\n• %s\n\n[b]Field confidence[/b]\n%s\n\n[b]Author context / response to feedback[/b]\n%s" % ["\n• ".join(response.get("assumptions", [])), JSON.stringify(response.get("field_confidence", {}), "  "), record.get("additional_context", "None")]
	var trace: Dictionary = record.get("candidate_trace_report", {})
	populate_muscles(trace.get("profile", {}).get("muscles", []))
	heatmap.show_profile(trace.get("profile", {}))
	prior_feedback_text.text = format_prior_feedback(record.get("revision_sha256", ""))
	comparison_text.text = build_comparison(record)

func build_comparison(record: Dictionary) -> String:
	var definition: Dictionary = record.get("authoring_response", {}).get("proposed_definition", {})
	var lines: Array[String] = ["[b]Aliases[/b]", "• %s" % "\n• ".join(definition.get("aliases", []))]
	var previous: Array[Dictionary] = []
	for revision in ReviewRevisionStoreScript.list_revisions():
		if revision.get("source_id") == record.get("source_id") and revision.get("revision_sha256") != record.get("revision_sha256"):
			previous.append(revision)
	lines.append("\n[b]Other frozen revisions for this source[/b]")
	if previous.is_empty(): lines.append("None")
	for revision in previous:
		var old_definition: Dictionary = revision.get("authoring_response", {}).get("proposed_definition", {})
		lines.append("• %s — %s / %s / %s joint actions" % [String(revision.get("revision_sha256", "")).left(12), old_definition.get("variant", ""), old_definition.get("laterality", ""), old_definition.get("kinematic_profile", {}).get("primary_joint_actions", []).size()])
	lines.append("\n[b]Neighboring variant signals[/b]")
	lines.append("Movement families: %s\nVariant: %s\nLaterality: %s" % [", ".join(definition.get("movement_families", [])), definition.get("variant", ""), definition.get("laterality", "")])
	return "\n".join(lines)

func populate_muscles(entries_to_show: Array) -> void:
	muscles_tree.clear(); var root := muscles_tree.create_item(); var groups := {}
	for role in ["primary", "synergist", "stabilizer"]:
		var group := muscles_tree.create_item(root); group.set_text(0, role.capitalize()); groups[role] = group
	for muscle in entries_to_show:
		if float(muscle.get("coefficient", 0.0)) <= 0.0: continue
		var item := muscles_tree.create_item(groups.get(muscle.get("role", "stabilizer"), root))
		item.set_text(0, muscle.get("muscle_id", "")); item.set_text(1, muscle.get("role", "")); item.set_text(2, "%.2f" % muscle.get("coefficient", 0.0))

func request_model_review() -> void:
	if current_revision.is_empty(): return
	if not ClaudeSettings.has_api_key(): return set_status(ClaudeSettings.missing_key_message(), true)
	request_review_button.disabled = true
	set_status("Claude (%s) is reviewing the frozen revision…" % model_id, false)
	provider.review(model_id, current_revision, review_context.text, build_contact_sheet_data_url(current_revision.get("source", {})))

func _on_model_review_succeeded(response: Dictionary, metadata: Dictionary) -> void:
	pending_model_vote = response.duplicate(true); pending_model_vote["provider_metadata"] = metadata
	var result: Dictionary = ReviewRevisionStoreScript.save_vote(current_revision.get("revision_sha256", ""), ReviewRevisionStoreScript.MODEL_MEMBER, pending_model_vote, review_context.text)
	request_review_button.disabled = false
	if not result.get("ok", false): return set_status(result.get("error", "Could not save model vote."), true)
	load_votes(result["record"]); set_status("Claude vote recorded against this exact revision hash.", false)

func record_human_vote() -> void:
	if current_revision.is_empty(): return set_status("Freeze a revision before voting.", true)
	var vote := {"decision": human_decision.get_selected_metadata(), "summary": human_feedback.text, "blocking_findings": [], "non_blocking_findings": [], "confidence": "high", "recorded_at_unix": Time.get_unix_time_from_system()}
	if vote["decision"] == "reject": vote["blocking_findings"] = [{"field_path": "review.human", "finding": human_feedback.text, "suggested_correction": human_feedback.text}]
	var result: Dictionary = ReviewRevisionStoreScript.save_vote(current_revision.get("revision_sha256", ""), "human_owner", vote, review_context.text)
	if not result.get("ok", false): return set_status(result.get("error", "Could not save human vote."), true)
	load_votes(result["record"]); set_status("Human vote recorded against this exact revision hash.", false)

func load_votes(review: Dictionary) -> void:
	var votes: Dictionary = review.get("votes", {})
	var model: Dictionary = ReviewRevisionStoreScript.model_vote(votes)
	model_result.text = "No model vote yet." if model.is_empty() else format_vote("Claude reviewer (%s)" % model.get("provider_metadata", {}).get("model", "legacy vote"), model)
	prior_feedback_text.text = format_prior_feedback(current_revision.get("revision_sha256", "")) if not current_revision.is_empty() else prior_feedback_text.text
	var status: String = String(review.get("status", "review_pending"))
	var promotion: Dictionary = ReviewRevisionStoreScript.load_promotion(String(current_revision.get("revision_sha256", ""))) if not current_revision.is_empty() else {}
	if not promotion.is_empty():
		status = "promoted"
	%CouncilOutcome.text = "Council outcome: %s" % String(status).replace("_", " ").capitalize()
	%PromoteButton.disabled = current_revision.is_empty() or status != "accepted"

func promote_current_revision() -> void:
	if current_revision.is_empty(): return set_status("Select an accepted frozen revision first.", true)
	set_status("Promoting… re-running validators against the current catalog.", false)
	var report: Dictionary = ReviewRevisionStoreScript.promote(current_revision)
	if not report.get("ok", false):
		return set_status("Promotion blocked: %s" % " ".join(report.get("errors", [])), true)
	load_votes(ReviewRevisionStoreScript.load_review(current_revision.get("revision_sha256", "")))
	reload_entries()
	if report.get("already_promoted", false):
		return set_status("Already promoted as %s." % report.get("exercise_id", ""), false)
	set_status("Promoted %s (%s muscles mapped). It is now visualizable in the exercise selector." % [report.get("exercise_id", ""), report.get("mapped_muscles", "?")], false)


func format_vote(member: String, vote: Dictionary) -> String:
	var text := "[b]%s: %s[/b] (%s confidence)\n%s" % [member, String(vote.get("decision", "")).to_upper(), vote.get("confidence", ""), vote.get("summary", "")]
	for finding in vote.get("blocking_findings", []): text += "\n[color=#ff7676]BLOCK · %s[/color]\n%s\nSuggested: %s" % [finding.get("field_path", ""), finding.get("finding", ""), finding.get("suggested_correction", "")]
	for finding in vote.get("non_blocking_findings", []): text += "\nNOTE · %s\n%s" % [finding.get("field_path", ""), finding.get("finding", "")]
	return text

func format_prior_feedback(hash: String) -> String:
	if hash.is_empty(): return "No frozen revision selected."
	var review: Dictionary = ReviewRevisionStoreScript.load_review(hash)
	var output := "No rejection feedback for this revision."
	for member in review.get("votes", {}):
		var vote: Dictionary = review["votes"][member]
		if vote.get("decision") == "reject": output = format_vote(String(member), vote)
	return output

func build_contact_sheet_data_url(source: Dictionary) -> String:
	var images: Array = source.get("source_images", [])
	var loaded: Array[Image] = []
	for relative in images:
		var texture = load("%s/%s" % [MEDIA_ROOT, relative])
		if texture is Texture2D: loaded.append(texture.get_image())
	if loaded.is_empty(): return ""
	var height := 512; var width := 0
	for image in loaded: width += int(float(image.get_width()) / image.get_height() * height)
	var sheet := Image.create(width, height, false, Image.FORMAT_RGB8); sheet.fill(Color.BLACK)
	var x := 0
	for image in loaded:
		var copy := image.duplicate(); var w := int(float(copy.get_width()) / copy.get_height() * height); copy.resize(w, height); sheet.blit_rect(copy, Rect2i(0, 0, w, height), Vector2i(x, 0)); x += w
	return "data:image/jpeg;base64,%s" % Marshalls.raw_to_base64(sheet.save_jpg_to_buffer(0.9))

func configure_model_selector() -> void:
	custom_model_input.visible = ClaudeSettings.fill_model_option(model_option, model_id)
	custom_model_input.text = model_id if custom_model_input.visible else ""

func load_model_preference() -> void:
	model_id = ClaudeSettings.load_model("review_model")

func save_model_preference() -> void:
	ClaudeSettings.save_model("review_model", model_id)

func _on_model_selected(_index: int) -> void:
	var value := String(model_option.get_selected_metadata()); custom_model_input.visible = value == "custom"
	if value != "custom": model_id = value; save_model_preference()

func _on_custom_model_changed(value: String) -> void:
	if model_option.get_selected_metadata() == "custom": model_id = value.strip_edges(); save_model_preference()

func set_image(view: TextureRect, relative: String) -> void:
	view.texture = load("%s/%s" % [MEDIA_ROOT, relative]) if not relative.is_empty() else null

func set_status(message: String, error: bool) -> void:
	status_label.text = message; status_label.modulate = Color("ff7676") if error else Color("a9bdd0")

func read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else null


# ── Auto mode ───────────────────────────────────────────────────────────────
# For each waiting candidate: freeze it, record the owner's vote as an
# automatic approval, ask the selected Claude reviewer, and promote it if the
# council is unanimous. Claude can still reject; rejected candidates stay in
# the queue with its findings, ready for the Studio to re-author.

const AUTO_HUMAN_SUMMARY := "Approved in advance by the owner through auto mode; the Claude reviewer decides."

func open_auto_mode() -> void:
	if not ClaudeSettings.has_api_key(): return set_status(ClaudeSettings.missing_key_message(), true)
	if model_id.strip_edges().is_empty(): return set_status("Choose a Claude model before starting auto mode.", true)
	if provider.is_busy(): return set_status("Wait for the current Claude review to finish first.", true)
	%AutoRunModal.open_for({
		"title": "Auto mode · Exercise Review Council",
		"model": model_id,
		"completed_label": "Promoted",
		"description": "For each waiting candidate: freeze it, record your vote as an automatic approval, ask this Claude model to review it, and promote it if Claude accepts. Claude can still reject; rejections keep their findings for the Studio's next auto run. Cleared candidates are skipped. Commit and deploy stay manual.",
		"queue": auto_council_queue,
		"step": auto_review,
		"label": func(entry: Dictionary) -> String: return auto_label(entry),
		"snapshot": func() -> Dictionary: return AutoPipeline.layers(AutoPipeline.snapshot()),
		"estimate_tokens": 25000,
		"log_name": "council",
	})

## One entry per exercise: its saved draft if that is a live candidate (the
## newest work), otherwise its waiting frozen revisions.
func auto_council_queue() -> Array:
	reload_entries()
	var cleared := ReviewRevisionStoreScript.load_cleared()
	var by_source := {}
	for entry in entries:
		if entry["kind"] != "draft": continue
		var draft: Dictionary = entry["data"]
		var source: Dictionary = catalog_by_source.get(String(draft.get("source_id", "")), {})
		if AutoPipeline.source_state(source, draft, cleared) == "candidate":
			by_source[String(draft.get("source_id", ""))] = [entry]
	for entry in entries:
		if entry["kind"] != "revision": continue
		var revision: Dictionary = entry["data"]
		var source_id := String(revision.get("source_id", ""))
		var hash := String(revision.get("revision_sha256", ""))
		if by_source.has(source_id) and by_source[source_id][0]["kind"] == "draft": continue
		if ReviewRevisionStoreScript.is_cleared("revision", revision, cleared): continue
		if not ReviewRevisionStoreScript.load_promotion(hash).is_empty(): continue
		if catalog_by_source.get(source_id, {}).get("status", "") == "promoted": continue
		if ReviewRevisionStoreScript.load_review(hash).get("status", "review_pending") in ["review_pending", "accepted"]:
			if not by_source.has(source_id): by_source[source_id] = []
			by_source[source_id].append(entry)
	var queue: Array = []
	for source_id in by_source: queue.append_array(by_source[source_id])
	return queue

func auto_label(entry: Dictionary) -> String:
	var data: Dictionary = entry["data"]
	var name := String(catalog_by_source.get(String(data.get("source_id", "")), {}).get("name", data.get("source_id", "?")))
	return name if entry["kind"] == "draft" else "%s (revision %s)" % [name, String(data.get("revision_sha256", "")).left(12)]

func auto_review(entry: Dictionary) -> Dictionary:
	var revision: Dictionary = entry["data"]
	if entry["kind"] == "draft":
		var source: Dictionary = catalog_by_source.get(String(revision.get("source_id", "")), {})
		var frozen: Dictionary = ReviewRevisionStoreScript.freeze_draft(revision, source)
		if not frozen.get("ok", false): return {"outcome": "failed", "error": "Freeze blocked: %s" % " ".join(frozen.get("errors", []))}
		revision = frozen["revision"]
	if not ReviewRevisionStoreScript.verify_revision_hash(revision):
		return {"outcome": "failed", "error": "Frozen revision content no longer matches its hash."}
	var hash := String(revision.get("revision_sha256", ""))
	selected_entry = {"kind": "revision", "data": revision}
	review_context.text = ""
	show_revision(revision)
	var votes: Dictionary = ReviewRevisionStoreScript.load_review(hash).get("votes", {})
	if not votes.has(ReviewRevisionStoreScript.HUMAN_MEMBER):
		var human := {"decision": "accept", "summary": AUTO_HUMAN_SUMMARY, "blocking_findings": [], "non_blocking_findings": [],
			"confidence": "high", "auto_mode": true, "recorded_at_unix": Time.get_unix_time_from_system()}
		var saved: Dictionary = ReviewRevisionStoreScript.save_vote(hash, ReviewRevisionStoreScript.HUMAN_MEMBER, human, "")
		if not saved.get("ok", false): return {"outcome": "failed", "error": saved.get("error", "Could not save the owner's vote.")}
	var usage := {}
	if not votes.has(ReviewRevisionStoreScript.MODEL_MEMBER):
		provider.review(model_id, revision, "", build_contact_sheet_data_url(revision.get("source", {})))
		var result: Dictionary = await provider.request_finished   # _on_model_review_succeeded saves the vote
		usage = result.get("metadata", {}).get("usage", {})
		if not result.get("ok", false):
			return {"outcome": "failed", "error": String(result.get("error", "")), "error_kind": String(result.get("error_kind", "")), "usage": usage}
	var review: Dictionary = ReviewRevisionStoreScript.load_review(hash)
	load_votes(review)
	var status := String(review.get("status", ""))
	if status == "changes_requested":
		var model: Dictionary = ReviewRevisionStoreScript.model_vote(review.get("votes", {}))
		return {"outcome": "rejected_by_claude", "usage": usage, "message": String(model.get("summary", ""))}
	if status != "accepted":
		return {"outcome": "failed", "usage": usage, "error": "Council status is %s after both votes." % status}
	var report: Dictionary = ReviewRevisionStoreScript.promote(revision)
	load_votes(ReviewRevisionStoreScript.load_review(hash))
	if not report.get("ok", false):
		return {"outcome": "promotion_blocked", "usage": usage, "message": " ".join(report.get("errors", []))}
	# Promotion changes the catalog; keep the source lookup current.
	load_support_files()
	return {"outcome": "promoted", "usage": usage, "message": "%s, %s muscles mapped" % [report.get("exercise_id", ""), report.get("mapped_muscles", "?")]}
