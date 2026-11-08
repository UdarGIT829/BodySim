class_name KinematicDefinitionStudio
extends Control

## Claude model used for authoring (saved as [anthropic] authoring_model).
var model_id: String = ClaudeSettings.DEFAULT_MODEL

const CATALOG_PATH := "res://data/exercises/catalog/candidates.json"
const CANONICAL_PATH := "res://data/exercises/exercises.json"
const SCHEMA_PATH := "res://data/exercises/authoring/schemas/kinematic_authoring_response.schema.json"
const PROMPT_PATH := "res://data/exercises/authoring/prompts/authoring_v2.md"
const MEDIA_ROOT := "res://assets/exercises/free_exercise_db"
const SETTINGS_PATH := "user://bodysim_authoring_settings.cfg"

@onready var provider: ClaudeProvider = $ClaudeProvider
@onready var candidate_trace_gate: Node = $CandidateTraceGate
@onready var model_option: OptionButton = %ModelOption
@onready var custom_model_input: LineEdit = %CustomModelInput
@onready var active_model_label: Label = %ActiveModelLabel
@onready var search_input: LineEdit = %SearchInput
@onready var catalog_tree: Tree = %CatalogTree
@onready var source_title: Label = %SourceTitle
@onready var source_metadata: Label = %SourceMetadata
@onready var source_instructions: RichTextLabel = %SourceInstructions
@onready var source_image_a: TextureRect = %SourceImageA
@onready var source_image_b: TextureRect = %SourceImageB
@onready var id_input: LineEdit = %IdInput
@onready var name_input: LineEdit = %NameInput
@onready var variant_input: LineEdit = %VariantInput
@onready var aliases_input: LineEdit = %AliasesInput
@onready var families_input: LineEdit = %FamiliesInput
@onready var laterality_option: OptionButton = %LateralityOption
@onready var input_mode_option: OptionButton = %InputModeOption
@onready var chain_option: OptionButton = %ChainOption
@onready var one_sided_option: OptionButton = %OneSidedOption
@onready var assist_check: CheckBox = %AssistCheck
@onready var both_sides_check: CheckBox = %BothSidesCheck
@onready var joint_option: OptionButton = %JointOption
@onready var movement_option: OptionButton = %MovementOption
@onready var actions_tree: Tree = %ActionsTree
@onready var stabilization_list: ItemList = %StabilizationList
@onready var classification_label: Label = %ClassificationLabel
@onready var rationale_text: RichTextLabel = %RationaleText
@onready var context_input: TextEdit = %ContextInput
@onready var json_editor: TextEdit = %JsonEditor
@onready var validation_tree: Tree = %ValidationTree
@onready var trace_summary_label: Label = %TraceSummaryLabel
@onready var evidence_tabs: TabContainer = $Margin/Column/Workspace/DefinitionAndEvidence/EvidencePanel/Tabs
@onready var candidate_gate_panel: VBoxContainer = $Margin/Column/Workspace/DefinitionAndEvidence/EvidencePanel/Tabs/CandidateGate
@onready var diff_text: RichTextLabel = %DiffText
@onready var status_label: Label = %StatusLabel
@onready var generate_button: Button = %GenerateButton
@onready var submit_button: Button = %SubmitButton

var catalog: Array[Dictionary] = []
var selected_source: Dictionary = {}
var canonical_ids: Dictionary = {}
var schema: Dictionary = {}
var system_prompt := ""
var current_response: Dictionary = {}
var provider_metadata: Dictionary = {}
var baseline_response: Dictionary = {}
var last_trace_report: Dictionary = {}
var preview_window: Window = null
var preview_view: Control = null
var preview_summary: Label = null
const PREVIEW_VIEW_SCENE := preload("res://scenes/exercises/candidate_heatmap_view.tscn")
var joint_actions: Array[Dictionary] = []
## one_sided_limbs choices; null means "infer from actions" (the key is omitted).
## Catalog status filter: [label, pipeline states shown (empty = all)]. The
## Studio's catalog only holds catalog-only sources, so promoted exercises
## never appear; demoted ones do (they need re-authoring).
const STATUS_FILTERS := [
	["Show: all catalog exercises", []],
	["Show: sent back with changes", ["needs_rework"]],
	["Show: set aside after repeated rejections", ["set_aside"]],
	["Show: never drafted", ["new"]],
]
var source_states: Dictionary = {}   # source_id -> AutoPipeline state, refreshed by refresh_states()
const ONE_SIDED_CHOICES := [["Infer from actions", null], ["None (both sides)", []], ["Arm", ["arm"]], ["Leg", ["leg"]], ["Arm and leg", ["arm", "leg"]]]


func _ready() -> void:
	configure_controls()
	load_model_preference()
	configure_model_selector()
	load_support_files()
	for choice in STATUS_FILTERS:
		%StatusFilter.add_item(String(choice[0]))
	populate_catalog("")
	provider.generation_succeeded.connect(_on_generation_succeeded)
	provider.generation_failed.connect(_on_generation_failed)
	model_option.item_selected.connect(_on_model_selected)
	custom_model_input.text_changed.connect(_on_custom_model_changed)
	search_input.text_changed.connect(populate_catalog)
	%StatusFilter.item_selected.connect(func(_i: int) -> void: refresh_states(); populate_catalog(search_input.text))
	%AutoRunModal.run_finished.connect(func(_state: String) -> void: refresh_states(); populate_catalog(search_input.text))
	catalog_tree.item_selected.connect(_on_catalog_selected)
	joint_option.item_selected.connect(func(_index: int) -> void: populate_movement_options())
	%AddActionButton.pressed.connect(add_joint_action)
	%RemoveActionButton.pressed.connect(remove_joint_action)
	%SyncJsonButton.pressed.connect(sync_json_from_form)
	%ApplyJsonButton.pressed.connect(apply_json_editor)
	%ValidateButton.pressed.connect(validate_current)
	%PreviewButton.pressed.connect(preview_candidate)
	%SaveDraftButton.pressed.connect(save_draft)
	%DiscardButton.pressed.connect(discard_changes)
	generate_button.pressed.connect(generate_proposal)
	submit_button.pressed.connect(submit_candidate)
	%AutoButton.pressed.connect(open_auto_mode)
	%DemoteButton.pressed.connect(func() -> void: %DemoteDialog.open())
	%DemoteDialog.demoted.connect(func(report: Dictionary) -> void:
		reload_catalog()
		set_status("Demoted %s; its source is back in the catalog." % report.get("exercise_id", ""), false))
	set_status("Select a catalog-only exercise to begin.", false)


func configure_controls() -> void:
	catalog_tree.set_column_title(0, "Catalog exercise")
	catalog_tree.set_column_title(1, "Equipment")
	catalog_tree.set_column_expand(0, true)
	catalog_tree.set_column_expand(1, false)
	actions_tree.set_column_title(0, "Joint")
	actions_tree.set_column_title(1, "Concentric action")
	actions_tree.set_column_expand(0, true)
	actions_tree.set_column_expand(1, true)
	validation_tree.set_column_title(0, "Gate")
	validation_tree.set_column_title(1, "Result")
	fill_option(laterality_option, CandidateValidators.LATERALITIES)
	fill_option(input_mode_option, CandidateValidators.INPUT_MODES)
	fill_option(chain_option, CandidateValidators.CHAIN_TYPES)
	one_sided_option.clear()
	for choice in ONE_SIDED_CHOICES:
		one_sided_option.add_item(String(choice[0]))
	fill_option(joint_option, CandidateValidators.JOINT_ACTIONS.keys())
	for value in CandidateValidators.STABILIZATION_DEMANDS:
		stabilization_list.add_item(String(value).replace("_", " "))
		stabilization_list.set_item_metadata(stabilization_list.item_count - 1, value)
	populate_movement_options()
	evidence_tabs.set_tab_title(evidence_tabs.get_tab_idx_from_control(candidate_gate_panel), "Candidate gate")


func load_model_preference() -> void:
	model_id = ClaudeSettings.load_model("authoring_model")


func save_model_preference() -> void:
	ClaudeSettings.save_model("authoring_model", model_id)


func configure_model_selector() -> void:
	var custom_selected := ClaudeSettings.fill_model_option(model_option, model_id)
	custom_model_input.visible = custom_selected
	custom_model_input.text = model_id if custom_selected else ""
	update_active_model_label()


func _on_model_selected(_index: int) -> void:
	var selected := String(model_option.get_selected_metadata())
	custom_model_input.visible = selected == "custom"
	if selected != "custom":
		model_id = selected
		save_model_preference()
	elif custom_model_input.text.strip_edges().is_empty():
		custom_model_input.grab_focus()
	update_active_model_label()
	refresh_action_state()


func _on_custom_model_changed(value: String) -> void:
	if String(model_option.get_selected_metadata()) == "custom":
		model_id = value.strip_edges()
		save_model_preference()
		update_active_model_label()
		refresh_action_state()


func update_active_model_label() -> void:
	active_model_label.text = "Requests will use: %s" % (model_id if not model_id.is_empty() else "no model selected")


func fill_option(control: OptionButton, values: Array) -> void:
	control.clear()
	for value in values:
		control.add_item(String(value).replace("_", " "))
		control.set_item_metadata(control.item_count - 1, value)


func load_support_files() -> void:
	var parsed_catalog = read_json(CATALOG_PATH)
	if parsed_catalog is Array:
		for entry in parsed_catalog:
			if entry is Dictionary and entry.get("status") == "catalog_only":
				catalog.append(entry)
	var canonical = read_json(CANONICAL_PATH)
	if canonical is Array:
		for entry in canonical:
			canonical_ids[String(entry.get("id", ""))] = entry
	var parsed_schema = read_json(SCHEMA_PATH)
	if parsed_schema is Dictionary:
		schema = parsed_schema
	var prompt_file := FileAccess.open(PROMPT_PATH, FileAccess.READ)
	if prompt_file:
		system_prompt = prompt_file.get_as_text()


## Re-read the catalog and canonical IDs (after a demotion changes them).
func reload_catalog() -> void:
	catalog.clear()
	canonical_ids.clear()
	load_support_files()
	refresh_states()
	populate_catalog(search_input.text)


func read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else null


func populate_catalog(query: String) -> void:
	catalog_tree.clear()
	var root := catalog_tree.create_item()
	var count := 0
	for source in filtered_catalog(query):
		var item := catalog_tree.create_item(root)
		item.set_text(0, str(source.get("name", "")))
		item.set_text(1, str(source.get("equipment", "—")) if source.get("equipment") != null else "—")
		item.set_metadata(0, source.get("catalog_id", ""))
		count += 1
	var states: Array = active_status_states()
	%CatalogCount.text = "%d catalog-only candidates" % count if states.is_empty() else "%d %s" % [count, String(STATUS_FILTERS[%StatusFilter.selected][0]).trim_prefix("Show: ")]


## The catalog sources the catalog currently shows: the search text and the
## status filter together (everything when both are empty).
func filtered_catalog(query: String) -> Array:
	var normalized := query.strip_edges().to_lower()
	var states := active_status_states()
	var matches: Array = []
	for source in catalog:
		if not states.is_empty() and String(source_states.get(String(source.get("source_id", "")), "new")) not in states:
			continue
		var haystack := "%s %s %s %s" % [source.get("name", ""), source.get("equipment", ""), source.get("category", ""), source.get("instructions", [])]
		if normalized.is_empty() or normalized in haystack.to_lower():
			matches.append(source)
	return matches


func active_status_states() -> Array:
	return STATUS_FILTERS[maxi(0, %StatusFilter.selected)][1]


## Pipeline states are read from disk, so they're cached and refreshed when
## the filter changes, after a draft is saved, and after an auto run.
func refresh_states() -> void:
	source_states = AutoPipeline.snapshot()["states"] if not active_status_states().is_empty() else {}


func _on_catalog_selected() -> void:
	var item := catalog_tree.get_selected()
	if item == null:
		return
	var catalog_id := String(item.get_metadata(0))
	for source in catalog:
		if source.get("catalog_id") == catalog_id:
			selected_source = source
			break
	baseline_response = {}
	context_input.text = ""
	show_source()
	discard_changes()
	load_existing_draft()


func show_source() -> void:
	source_title.text = String(selected_source.get("name", "No source selected"))
	source_metadata.text = "%s · %s · %s · %s" % [selected_source.get("category", "—"), selected_source.get("equipment", "—"), selected_source.get("level", "—"), selected_source.get("mechanic", "—")]
	var instructions := ""
	var step := 1
	for instruction in selected_source.get("instructions", []):
		instructions += "[b]%d.[/b] %s\n\n" % [step, instruction]
		step += 1
	source_instructions.text = instructions
	var images: Array = selected_source.get("source_images", [])
	set_source_image(source_image_a, images[0] if images.size() > 0 else "")
	set_source_image(source_image_b, images[1] if images.size() > 1 else "")


func set_source_image(view: TextureRect, relative_path: String) -> void:
	view.texture = load("%s/%s" % [MEDIA_ROOT, relative_path]) if not relative_path.is_empty() else null


func discard_changes() -> void:
	current_response = {}
	provider_metadata = {}
	last_trace_report = {}
	joint_actions.clear()
	refresh_actions_tree()
	id_input.text = suggested_id()
	name_input.text = String(selected_source.get("name", ""))
	variant_input.text = "standard"
	aliases_input.text = String(selected_source.get("name", "")).to_lower()
	families_input.text = ""
	laterality_option.select(0)
	input_mode_option.select(0)
	chain_option.select(0)
	one_sided_option.select(0)
	assist_check.button_pressed = false
	both_sides_check.button_pressed = false
	stabilization_list.deselect_all()
	classification_label.text = "Not generated"
	rationale_text.text = "Generate a proposal or build the definition manually."
	json_editor.text = ""
	clear_validation()
	refresh_action_state()
	show_diff()


func load_existing_draft() -> void:
	baseline_response = {}
	var stored := CandidateRepository.load_draft(String(selected_source.get("source_id", "")))
	var feedback := CandidateRepository.latest_rejection_feedback(String(selected_source.get("source_id", "")), selected_source)
	if stored.is_empty():
		if not feedback.is_empty(): context_input.text = feedback
		show_diff()
		return
	var stored_response = stored.get("authoring_response")
	if stored_response is Dictionary:
		baseline_response = strip_deprecated_load_vector(stored_response)
		current_response = strip_deprecated_load_vector(stored_response)
		provider_metadata = stored.get("provider_metadata", {})
		last_trace_report = stored.get("candidate_trace_report", {})
		# Keep the owner's own notes, but replace (don't stack) council feedback
		# from earlier rounds with the latest decision.
		var notes := CandidateRepository.strip_council_feedback(String(stored.get("additional_context", "")))
		context_input.text = feedback if notes.is_empty() else ("%s\n\n%s" % [feedback, notes] if not feedback.is_empty() else notes)
		json_editor.text = JSON.stringify(current_response, "  ")
		show_response_summary()
		if current_response.get("proposed_definition") is Dictionary:
			populate_form(current_response["proposed_definition"])
		validate_current()
	show_diff()


func suggested_id() -> String:
	var slug := String(selected_source.get("source_id", "new_exercise")).to_lower()
	for token in ["-", "/", " ", "(", ")", "."]:
		slug = slug.replace(token, "_")
	while "__" in slug:
		slug = slug.replace("__", "_")
	slug = slug.trim_prefix("_").trim_suffix("_")
	return "exercise.%s.standard" % slug


func populate_movement_options() -> void:
	var joint = joint_option.get_selected_metadata()
	fill_option(movement_option, CandidateValidators.JOINT_ACTIONS.get(joint, []))


func add_joint_action() -> void:
	var action := {"joint": joint_option.get_selected_metadata(), "movement": movement_option.get_selected_metadata(),
		"emphasis": "assist" if assist_check.button_pressed else "primary",
		"sides": "both" if both_sides_check.button_pressed else "working"}
	for existing in joint_actions:   # re-adding a pair updates its flags
		if existing.get("joint") == action["joint"] and existing.get("movement") == action["movement"]:
			joint_actions.erase(existing)
			break
	joint_actions.append(action)
	refresh_actions_tree()
	sync_json_from_form()


func remove_joint_action() -> void:
	var selected := actions_tree.get_selected()
	if selected != null:
		var index := int(selected.get_metadata(0))
		if index >= 0 and index < joint_actions.size():
			joint_actions.remove_at(index)
	refresh_actions_tree()
	sync_json_from_form()


func refresh_actions_tree() -> void:
	actions_tree.clear()
	var root := actions_tree.create_item()
	for index in joint_actions.size():
		var item := actions_tree.create_item(root)
		item.set_text(0, String(joint_actions[index]["joint"]).replace("_", " "))
		var flags: Array[String] = []
		if joint_actions[index].get("emphasis", "primary") == "assist": flags.append("assist")
		if joint_actions[index].get("sides", "working") == "both": flags.append("both sides")
		item.set_text(1, String(joint_actions[index]["movement"]).replace("_", " ") + (" (%s)" % ", ".join(flags) if not flags.is_empty() else ""))
		item.set_metadata(0, index)


func build_definition_from_form() -> Dictionary:
	var stabs: Array[String] = []
	for index in stabilization_list.get_selected_items():
		stabs.append(String(stabilization_list.get_item_metadata(index)))
	var definition := {
		"id": id_input.text.strip_edges(),
		"name": name_input.text.strip_edges(),
		"variant": variant_input.text.strip_edges(),
		"aliases": split_csv(aliases_input.text),
		"movement_families": split_csv(families_input.text),
		"laterality": laterality_option.get_selected_metadata(),
		"input_mode": input_mode_option.get_selected_metadata(),
		"kinematic_profile": {
			"kinetic_chain_type": chain_option.get_selected_metadata(),
			"primary_joint_actions": joint_actions.duplicate(true),
			"stabilization_demands": stabs,
		}
	}
	var limbs = ONE_SIDED_CHOICES[maxi(0, one_sided_option.selected)][1]
	if limbs != null:
		definition["kinematic_profile"]["one_sided_limbs"] = limbs.duplicate()
	return definition


func split_csv(value: String) -> Array[String]:
	var result: Array[String] = []
	for part in value.split(","):
		var cleaned := part.strip_edges().to_lower().replace(" ", "_")
		if not cleaned.is_empty() and cleaned not in result:
			result.append(cleaned)
	return result


func sync_json_from_form() -> void:
	if current_response.is_empty():
		current_response = default_supported_response()
	current_response["proposed_definition"] = build_definition_from_form()
	json_editor.text = JSON.stringify(current_response, "  ")
	refresh_action_state()
	show_diff()


func default_supported_response() -> Dictionary:
	return {
		"classification": "supported",
		"classification_reasons": ["Manually authored in BodySim."],
		"assumptions": [],
		"questions_requiring_context": [],
		"field_confidence": {"variant": "medium", "laterality": "medium", "input_mode": "medium", "kinetic_chain_type": "medium", "primary_joint_actions": "medium", "stabilization_demands": "medium"},
		"proposed_definition": build_definition_from_form(),
	}


func apply_json_editor() -> void:
	var parsed = JSON.parse_string(json_editor.text)
	if not parsed is Dictionary:
		set_status("The advanced editor does not contain a JSON object.", true)
		return
	current_response = strip_deprecated_load_vector(parsed)
	show_response_summary()
	var definition = current_response.get("proposed_definition")
	if definition is Dictionary:
		populate_form(definition)
	validate_current()
	show_diff()


func populate_form(definition: Dictionary) -> void:
	id_input.text = String(definition.get("id", ""))
	name_input.text = String(definition.get("name", ""))
	variant_input.text = String(definition.get("variant", ""))
	aliases_input.text = ", ".join(definition.get("aliases", []))
	families_input.text = ", ".join(definition.get("movement_families", []))
	select_metadata(laterality_option, definition.get("laterality"))
	select_metadata(input_mode_option, definition.get("input_mode"))
	var profile: Dictionary = definition.get("kinematic_profile", {})
	select_metadata(chain_option, profile.get("kinetic_chain_type"))
	one_sided_option.select(0)
	for index in ONE_SIDED_CHOICES.size():
		if ONE_SIDED_CHOICES[index][1] != null and profile.get("one_sided_limbs") is Array and ONE_SIDED_CHOICES[index][1] == profile["one_sided_limbs"]:
			one_sided_option.select(index)
	joint_actions.clear()
	for action in profile.get("primary_joint_actions", []):
		if action is Dictionary:
			joint_actions.append(action)
	refresh_actions_tree()
	stabilization_list.deselect_all()
	for index in stabilization_list.item_count:
		if stabilization_list.get_item_metadata(index) in profile.get("stabilization_demands", []):
			stabilization_list.select(index, false)


func select_metadata(control: OptionButton, value) -> void:
	for index in control.item_count:
		if control.get_item_metadata(index) == value:
			control.select(index)
			return


func generate_proposal() -> void:
	if selected_source.is_empty():
		set_status("Select a catalog exercise first.", true)
		return
	if not ClaudeSettings.has_api_key():
		set_status(ClaudeSettings.missing_key_message(), true)
		return
	var contact_sheet_data_url := build_contact_sheet_data_url(selected_source)
	if contact_sheet_data_url.is_empty():
		set_status("Could not build the two-frame source contact sheet; request not sent.", true)
		return
	generate_button.disabled = true
	set_status("Claude (%s) is drafting from the source text and the two-frame contact sheet…" % model_id, false)
	provider.generate(model_id, build_source_context(), contact_sheet_data_url)


func build_source_context() -> String:
	var clean_source := selected_source.duplicate(true)
	clean_source.erase("source_muscle_tags")
	return "SOURCE EXERCISE:\n%s\n\nDEMONSTRATION CONTACT SHEET:\nOne attached image contains the two source frames in chronological left-to-right order: frame 1 (start/setup), then frame 2 (later/end position). Use visible body orientation, support contact, grip, apparatus, and resistance path to resolve textual ambiguity. Treat images as demonstrations, not precise joint-angle measurements. If image and text materially conflict, classify ambiguous and explain the conflict.\n\nADDITIONAL AUTHOR CONTEXT:\n%s\n\nOnly use values permitted by the attached response schema." % [JSON.stringify(clean_source, "  "), context_input.text.strip_edges()]


func build_contact_sheet_data_url(source: Dictionary) -> String:
	var contact_sheet := build_contact_sheet_image(source)
	if contact_sheet == null or contact_sheet.is_empty():
		return ""
	var jpeg := contact_sheet.save_jpg_to_buffer(0.9)
	if jpeg.is_empty():
		return ""
	return "data:image/jpeg;base64,%s" % Marshalls.raw_to_base64(jpeg)


func build_contact_sheet_image(source: Dictionary) -> Image:
	var frames: Array[Image] = []
	for relative_path in source.get("source_images", []):
		var file := FileAccess.open("%s/%s" % [MEDIA_ROOT, relative_path], FileAccess.READ)
		if file == null:
			continue
		var frame := Image.new()
		if frame.load_jpg_from_buffer(file.get_buffer(file.get_length())) != OK:
			continue
		frame.convert(Image.FORMAT_RGB8)
		if frame.get_height() > 512:
			var scaled_width := maxi(1, roundi(float(frame.get_width()) * 512.0 / float(frame.get_height())))
			frame.resize(scaled_width, 512, Image.INTERPOLATE_LANCZOS)
		frames.append(frame)
	if frames.is_empty():
		return Image.new()
	var gap := 12
	var total_width := gap * (frames.size() - 1)
	var max_height := 1
	for frame in frames:
		total_width += frame.get_width()
		max_height = maxi(max_height, frame.get_height())
	var sheet := Image.create(total_width, max_height, false, Image.FORMAT_RGB8)
	sheet.fill(Color("111820"))
	var offset_x := 0
	for frame in frames:
		var offset_y := (max_height - frame.get_height()) / 2
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(offset_x, offset_y))
		offset_x += frame.get_width() + gap
	return sheet


func _on_generation_succeeded(response: Dictionary, metadata: Dictionary) -> void:
	generate_button.disabled = false
	provider_metadata = metadata
	provider_metadata["input_contact_sheet"] = {
		"frame_count": selected_source.get("source_images", []).size(),
		"source_images": selected_source.get("source_images", []).duplicate(),
		"layout": "chronological_left_to_right",
		"api_image_inputs": 1,
	}
	provider_metadata["raw_authoring_response"] = response.duplicate(true)
	current_response = normalize_generated_response(response)
	json_editor.text = JSON.stringify(current_response, "  ")
	show_response_summary()
	var definition = current_response.get("proposed_definition")
	if definition is Dictionary:
		populate_form(definition)
	validate_current()


func normalize_generated_response(response: Dictionary) -> Dictionary:
	var normalized := strip_deprecated_load_vector(response)
	var definition = normalized.get("proposed_definition")
	if not definition is Dictionary:
		return normalized
	if definition.has("primary_movement_family"):
		var families: Array = [definition.get("primary_movement_family")]
		for family in definition.get("additional_movement_families", []):
			if family not in families:
				families.append(family)
		definition["movement_families"] = families
		definition.erase("primary_movement_family")
		definition.erase("additional_movement_families")
	var model_id := String(definition.get("id", ""))
	if is_canonical_id_shape(model_id):
		return normalized
	var corrected_id := "exercise.%s.%s" % [
		slugify(String(definition.get("name", "exercise"))),
		slugify(String(definition.get("variant", "standard"))),
	]
	definition["id"] = corrected_id
	var reasons: Array = normalized.get("classification_reasons", [])
	reasons.append("BodySim normalized the model-provided ID '%s' to '%s' to satisfy the canonical namespace." % [model_id, corrected_id])
	normalized["classification_reasons"] = reasons
	return normalized


func strip_deprecated_load_vector(response: Dictionary) -> Dictionary:
	var stripped := response.duplicate(true)
	var confidence = stripped.get("field_confidence")
	if confidence is Dictionary:
		confidence.erase("load_vector")
	var definition = stripped.get("proposed_definition")
	if definition is Dictionary:
		var profile = definition.get("kinematic_profile")
		if profile is Dictionary:
			profile.erase("load_vector")
	return stripped


func is_canonical_id_shape(value: String) -> bool:
	if not value.begins_with("exercise.") or value.split(".").size() != 3:
		return false
	return value == value.to_lower() and " " not in value and "-" not in value


func slugify(value: String) -> String:
	var slug := value.strip_edges().to_lower()
	var normalized := ""
	for character in slug:
		if character >= "a" and character <= "z" or character >= "0" and character <= "9":
			normalized += character
		elif not normalized.ends_with("_"):
			normalized += "_"
	normalized = normalized.trim_prefix("_").trim_suffix("_")
	return normalized if not normalized.is_empty() else "standard"


func _on_generation_failed(message: String) -> void:
	generate_button.disabled = false
	set_status(message, true)


func show_response_summary() -> void:
	var classification := String(current_response.get("classification", "invalid"))
	classification_label.text = classification.capitalize()
	classification_label.modulate = Color("70d6a0") if classification == "supported" else Color("e3aa57") if classification == "ambiguous" else Color("e57373")
	var lines: Array[String] = []
	for heading in ["classification_reasons", "assumptions", "questions_requiring_context"]:
		lines.append("[b]%s[/b]" % String(heading).replace("_", " ").capitalize())
		var values: Array = current_response.get(heading, [])
		lines.append("• " + "\n• ".join(values) if not values.is_empty() else "—")
	rationale_text.text = "\n".join(lines)


func validate_current() -> Array[String]:
	if current_response.is_empty():
		sync_json_from_form()
	else:
		current_response["proposed_definition"] = build_definition_from_form()
		json_editor.text = JSON.stringify(current_response, "  ")
	var errors := CandidateValidators.validate_authoring_response(current_response, canonical_ids)
	last_trace_report = {}
	if errors.is_empty():
		last_trace_report = candidate_trace_gate.evaluate(build_definition_from_form())
		for trace_error in last_trace_report.get("errors", []):
			errors.append("trace: %s" % trace_error)
	show_validation(errors)
	show_trace_summary(errors)
	show_diff()
	var gate_message := "Candidate gate passed."
	if not errors.is_empty():
		gate_message = "Gate: %s" % errors[0]
		if errors.size() > 1:
			gate_message += " (+%d more)" % (errors.size() - 1)
	set_status(gate_message, not errors.is_empty())
	return errors


## Validates the current form (so the preview reflects unsaved edits) and
## shows the resulting 466-muscle profile on the full-body model.
func preview_candidate() -> void:
	var errors := validate_current()
	var profile: Dictionary = last_trace_report.get("profile", {})
	if not errors.is_empty() or profile.is_empty():
		set_status("Preview needs a passing candidate. %s" % (errors[0] if not errors.is_empty() else "No trace profile was produced."), true)
		return
	ensure_preview_window()
	var definition := build_definition_from_form()
	var summary: Dictionary = last_trace_report.get("summary", {})
	var roles: Dictionary = summary.get("role_counts", {})
	preview_window.title = "Candidate preview · %s · %s" % [definition.get("name", ""), definition.get("variant", "")]
	preview_summary.text = "%s · %d of 466 muscles engaged · primary %d · synergist %d · stabilizer %d   (unsaved candidate, not a canonical exercise)" % [
		definition.get("id", ""), int(summary.get("mapped_muscles", 0)),
		int(roles.get("primary", 0)), int(roles.get("synergist", 0)), int(roles.get("stabilizer", 0)),
	]
	preview_view.show_profile(profile)
	var available := get_viewport().get_visible_rect().size
	preview_window.size = Vector2i(int(minf(1280.0, available.x * 0.9)), int(minf(820.0, available.y * 0.9)))
	preview_window.popup_centered()


func ensure_preview_window() -> void:
	if preview_window != null and is_instance_valid(preview_window):
		return
	preview_window = Window.new()
	preview_window.size = Vector2i(1280, 820)
	preview_window.min_size = Vector2i(720, 480)
	preview_window.wrap_controls = false
	preview_window.close_requested.connect(preview_window.hide)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_summary = Label.new()
	preview_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(preview_summary)
	preview_view = PREVIEW_VIEW_SCENE.instantiate()
	preview_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_view.stretch = true
	column.add_child(preview_view)
	preview_window.add_child(column)
	add_child(preview_window)


func clear_validation() -> void:
	validation_tree.clear()
	trace_summary_label.text = "Tracer has not run for this draft."
	submit_button.disabled = true


func show_trace_summary(errors: Array[String]) -> void:
	if last_trace_report.is_empty():
		trace_summary_label.text = "Tracer not run because the definition has deterministic gate issues." if not errors.is_empty() else "Tracer has not run for this draft."
		return
	var summary: Dictionary = last_trace_report.get("summary", {})
	var roles: Dictionary = summary.get("role_counts", {})
	var state := "PASS" if last_trace_report.get("ok", false) else "FAIL"
	trace_summary_label.text = "Python tracer %s · %d/466 muscles affected · %d primary · %d synergist · %d stabilizer · %d zero" % [
		state,
		int(summary.get("mapped_muscles", 0)),
		int(roles.get("primary", 0)),
		int(roles.get("synergist", 0)),
		int(roles.get("stabilizer", 0)),
		int(summary.get("zero_muscles", 0)),
	]


func show_validation(errors: Array[String]) -> void:
	validation_tree.clear()
	var root := validation_tree.create_item()
	if errors.is_empty():
		var item := validation_tree.create_item(root)
		item.set_text(0, "Deterministic candidate gate")
		item.set_text(1, "PASS")
		item.set_custom_color(1, Color("70d6a0"))
	else:
		for error in errors:
			var item := validation_tree.create_item(root)
			var separator := error.find(":")
			item.set_text(0, error.left(separator) if separator >= 0 else "response")
			item.set_text(1, error.substr(separator + 1).strip_edges() if separator >= 0 else error)
			item.set_custom_color(1, Color("e57373"))
		evidence_tabs.current_tab = evidence_tabs.get_tab_idx_from_control(candidate_gate_panel)
	submit_button.disabled = not errors.is_empty()


func save_draft() -> void:
	if selected_source.is_empty():
		set_status("Select a source exercise first.", true)
		return
	var errors := validate_current()
	var result := CandidateRepository.save_draft(selected_source, context_input.text, current_response, provider_metadata, errors, last_trace_report)
	if result.get("ok", false):
		baseline_response = current_response.duplicate(true)
		show_diff()
		if not active_status_states().is_empty(): refresh_states()
	set_status("Saved %s" % result.get("path", "") if result.get("ok", false) else result.get("error", "Draft save failed."), not result.get("ok", false))


func submit_candidate() -> void:
	var errors := validate_current()
	if not errors.is_empty():
		return
	var result := CandidateRepository.save_draft(selected_source, context_input.text, current_response, provider_metadata, errors, last_trace_report)
	set_status("Definition candidate saved for Phase 2D review: %s" % result.get("path", "") if result.get("ok", false) else result.get("error", "Candidate save failed."), not result.get("ok", false))


func refresh_action_state() -> void:
	generate_button.disabled = selected_source.is_empty() or not ClaudeSettings.has_api_key() or model_id.strip_edges().is_empty() or provider.is_busy()


func show_diff() -> void:
	if diff_text == null:
		return
	if baseline_response.is_empty():
		diff_text.text = "No saved revision exists for this source. The current form is a new draft."
		return
	var current_definition = current_response.get("proposed_definition", {})
	var baseline_definition = baseline_response.get("proposed_definition", {})
	var paths := ["id", "name", "variant", "aliases", "movement_families", "laterality", "input_mode", "kinematic_profile"]
	var lines: Array[String] = []
	for path in paths:
		if JSON.stringify(current_definition.get(path)) != JSON.stringify(baseline_definition.get(path)):
			lines.append("[color=#e3aa57]~ %s[/color]\n  saved: %s\n  current: %s" % [path, JSON.stringify(baseline_definition.get(path)), JSON.stringify(current_definition.get(path))])
	diff_text.text = "No structural changes from the saved revision." if lines.is_empty() else "\n\n".join(lines)


func set_status(message: String, is_error: bool) -> void:
	status_label.text = message
	status_label.modulate = Color("e57373") if is_error else Color("9fb3c8")


# ── Auto mode ───────────────────────────────────────────────────────────────

func open_auto_mode() -> void:
	if not ClaudeSettings.has_api_key():
		return set_status(ClaudeSettings.missing_key_message(), true)
	if model_id.strip_edges().is_empty():
		return set_status("Choose a Claude model before starting auto mode.", true)
	if provider.is_busy():
		return set_status("Wait for the current Claude request to finish first.", true)
	var query := search_input.text.strip_edges()
	var sources := filtered_catalog(query)
	var modal: AutoRunModal = %AutoRunModal
	modal.open_for({
		"title": "Auto mode · Kinematic Definition Studio",
		"scope": scope_text(sources.size(), query) + set_aside_note(),
		"option": {"label": "Skip stretches (the council rejects them anyway)", "setting": "skip_stretches", "default": true},
		"model": model_id,
		"completed_label": "Completed",
		"description": "Drafts catalog exercises one at a time with this model and saves each one for the Review Council. Exercises the council sent back go first, with its feedback in the request. Drafts that fail the candidate gate are saved for you to look at and are not retried.",
		"queue": func() -> Array: return AutoPipeline.studio_queue(sources, modal.option_enabled()),
		"step": auto_author,
		"label": func(source: Dictionary) -> String: return String(source.get("name", source.get("source_id", ""))),
		"snapshot": func() -> Dictionary: return AutoPipeline.layers(AutoPipeline.snapshot()),
		"task": "author",
		"log_name": "studio",
	})


func scope_text(count: int, query: String) -> String:
	var states := active_status_states()
	var filter := String(STATUS_FILTERS[%StatusFilter.selected][0]).trim_prefix("Show: ") if not states.is_empty() else ""
	if query.is_empty() and filter.is_empty():
		return "No search filter: works through all %d catalog exercises. Type in the catalog search or pick a status first to narrow it (e.g. “press”, or “sent back with changes”)." % count
	var parts: Array[String] = []
	if not filter.is_empty(): parts.append("“%s”" % filter)
	if not query.is_empty(): parts.append("matching “%s”" % query)
	return "Works through the %d catalog exercise(s) %s." % [count, " and ".join(parts)]


func set_aside_note() -> String:
	var set_aside := int(AutoPipeline.snapshot()["counts"].get("set_aside", 0))
	return "" if set_aside == 0 else " %d exercise(s) are set aside after %d Claude rejections; review them in the council before re-authoring." % [set_aside, AutoPipeline.MAX_CLAUDE_REJECTIONS]


## One auto-mode step: the same as selecting the exercise, pressing
## Generate, then Save draft.
func auto_author(source: Dictionary) -> Dictionary:
	selected_source = source
	baseline_response = {}
	context_input.text = ""
	show_source()
	discard_changes()
	load_existing_draft()
	var image := build_contact_sheet_data_url(source)
	if image.is_empty():
		return {"outcome": "failed", "error": "No source images to send."}
	generate_button.disabled = true
	provider.generate(model_id, build_source_context(), image)
	var result: Dictionary = await provider.request_finished
	var usage: Dictionary = result.get("metadata", {}).get("usage", {})
	if not result.get("ok", false):
		return {"outcome": "failed", "error": String(result.get("error", "")), "error_kind": String(result.get("error_kind", "")), "usage": usage}
	save_draft()   # re-validates through the candidate gate, then saves
	var saved := CandidateRepository.load_draft(String(source.get("source_id", "")))
	if saved.get("status", "") == "definition_candidate":
		var roles: Dictionary = last_trace_report.get("summary", {}).get("role_counts", {})
		return {"outcome": "drafted", "usage": usage, "message": "%d primary, %d synergist, %d stabilizer" % [
			int(roles.get("primary", 0)), int(roles.get("synergist", 0)), int(roles.get("stabilizer", 0))]}
	var classification := String(current_response.get("classification", ""))
	var errors: Array = saved.get("validation_errors", [])
	if classification in ["unsupported", "ambiguous"]:
		var reasons: Array = current_response.get("classification_reasons", [])
		return {"outcome": classification, "usage": usage, "message": String(reasons[0]) if not reasons.is_empty() else ""}
	return {"outcome": "gate_failed", "usage": usage, "message": String(errors[0]) if not errors.is_empty() else ""}
