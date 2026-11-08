extends SceneTree

## Auto-mode check. Writes drafts, votes and promotions, so it only runs in
## the disposable copy made by tools/exercises/verify_auto_mode.sh, with
## tools/exercises/fake_claude_bridge.py standing in for Claude.

const ModalScene := preload("res://scenes/exercises/auto_run_modal.tscn")
const StudioScene := preload("res://scenes/exercises/kinematic_definition_studio.tscn")
const CouncilScene := preload("res://scenes/exercises/exercise_review_council.tscn")
const FAKE_BRIDGE := "res://tools/exercises/fake_claude_bridge.py"
const FAKE_USAGE := 16500   # tokens per fake request

var failures: Array[String] = []


func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _initialize() -> void:
	if OS.get_environment("BODYSIM_SANDBOX") != "1":
		push_error("verify_auto_mode.gd modifies data/; run tools/exercises/verify_auto_mode.sh instead.")
		quit(2)
		return
	call_deferred("run")


func run() -> void:
	check_pipeline_rules()
	await check_runner()
	await check_studio_auto()
	await check_council_auto()
	if failures.is_empty():
		print("Auto mode passed: runner (spend limit, credits and ledger, API credit errors, retries, fatal, limit, stop, failure streak), pipeline states, studio (search filter, skip stretches) and council (stretch rule, no Claude call, suggested edits applied in-step and from the queue) runs")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func check_pipeline_rules() -> void:
	var cleared := {"drafts": {"Cleared_One": {"draft_saved_at_unix": 10.0}}, "revisions": {}}
	# Re-authoring replaces earlier council feedback instead of stacking it, and keeps the owner's notes.
	var old_context := "Council feedback from openai_reviewer:\n- a: stale v1 finding\n- b: another\n\n%s\nFrom model_reviewer:\n- c: newer finding\n%s\nOwner note: the bar is back-supported." % [CandidateRepository.FEEDBACK_START, CandidateRepository.FEEDBACK_END]
	var stripped := CandidateRepository.strip_council_feedback(old_context)
	require(stripped == "Owner note: the bar is back-supported.", "old feedback is stripped, notes kept: %s" % stripped)
	# Retry cap: Claude's rejections under the current tracer set an exercise aside.
	var rejected := {"source_id": "X", "status": "review_rejected"}
	require(AutoPipeline.source_state({"source_id": "X"}, rejected, cleared, {"X": 1}) == "needs_rework", "one rejection: re-author")
	require(AutoPipeline.source_state({"source_id": "X"}, rejected, cleared, {"X": AutoPipeline.MAX_CLAUDE_REJECTIONS}) == "set_aside", "the cap sets it aside")
	# A demotion after the draft was saved means it needs a new revision, whatever its hash.
	require(AutoPipeline.source_state({"source_id": "X", "demotions": [{"demoted_at_unix": 20.0}]}, {"source_id": "X", "status": "definition_candidate", "saved_at_unix": 10.0}, cleared) == "needs_rework", "demoted drafts need rework")
	# Promotion and demotion fields don't change a draft's revision hash.
	var some_draft := {"source_id": "X", "authoring_response": {"a": 1}, "candidate_trace_report": {"ok": true}}
	var source := {"source_id": "X", "name": "X", "category": "strength", "status": "catalog_only"}
	var changed := source.duplicate(true)
	changed["status"] = "promoted"
	changed["promotions"] = [{"exercise_id": "exercise.x.y"}]
	require(ReviewRevisionStore.draft_revision_hash(some_draft, source) == ReviewRevisionStore.draft_revision_hash(some_draft, changed), "revision hash ignores promotion fields")
	changed["name"] = "Renamed"
	require(ReviewRevisionStore.draft_revision_hash(some_draft, source) != ReviewRevisionStore.draft_revision_hash(some_draft, changed), "revision hash still covers the source content")
	require(AutoPipeline.source_state({"status": "promoted"}, {}, cleared) == "promoted", "promoted source")
	require(AutoPipeline.source_state({}, {}, cleared) == "new", "no draft is new")
	require(AutoPipeline.source_state({}, {"source_id": "X", "status": "review_rejected"}, cleared) == "needs_rework", "rejected draft needs rework")
	require(AutoPipeline.source_state({}, {"source_id": "X", "status": "authoring_draft"}, cleared) == "attempted", "gate failure is attempted")
	require(AutoPipeline.source_state({}, {"source_id": "Cleared_One", "status": "review_rejected", "saved_at_unix": 5.0}, cleared) == "cleared", "cleared draft is left alone")
	require(AutoPipeline.total_tokens({"input_tokens": 1, "output_tokens": 2, "cache_read_input_tokens": 3, "cache_creation_input_tokens": 4}) == 10, "token total")
	require(is_equal_approx(AutoPipeline.estimate_cost("claude-sonnet-5-5", {"input_tokens": 1000000, "output_tokens": 1000000}), 12.0), "Sonnet 5.5 cost")
	require(AutoPipeline.estimate_cost("claude-unknown", {"input_tokens": 1}) < 0.0, "unknown model has no estimate")
	var layers := AutoPipeline.layers(AutoPipeline.snapshot())
	require(layers["done"] + layers["candidate"] + layers["remaining"] == AutoPipeline.load_catalog().size(), "layers cover the catalog")


func make_modal() -> AutoRunModal:
	var modal: AutoRunModal = ModalScene.instantiate()
	root.add_child(modal)
	modal.persist_settings = false
	modal.retry_delay = func(_attempt: int) -> float: return 0.0
	return modal


## Runs a fake queue of n items through `step`.
func run_fake(modal: AutoRunModal, n: int, step: Callable, limit_usd := 0.0, max_items := 0) -> void:
	var items: Array = []
	for index in n: items.append(index)
	modal.open_for({"model": "claude-sonnet-5-5", "queue": func() -> Array: return items, "step": step,
		"label": func(item) -> String: return "item %d" % item,
		"snapshot": func() -> Dictionary: return {"done": 1, "candidate": 2, "remaining": 3}, "estimate_usd": 0.01})
	modal.run_limit_spin.value = limit_usd
	modal.max_items_spin.value = max_items
	await modal.start()


func check_runner() -> void:
	var modal := make_modal()
	var ok_step := func(_item) -> Dictionary:
		await process_frame
		return {"outcome": "drafted", "usage": {"input_tokens": 7000}}
	# 7,000 Sonnet input tokens ≈ $0.014 per item: a $0.04 limit stops before the third.
	await run_fake(modal, 3, ok_step, 0.04)
	require(modal.state == "spend_limit" and modal.processed == 2, "the spend limit must stop before the third item (%s, %d)" % [modal.state, modal.processed])
	require(is_equal_approx(modal.run_cost(), 0.028) and modal.spend_label.text.contains("$0.028"), "the run's spend is shown: %s" % modal.spend_label.text)

	# Credits: none set means no estimate-based stop; too little left stops before starting.
	require(AutoPipeline.credits_left() < 0.0, "no balance set yet (sandbox credits file)")
	AutoPipeline.set_credits(0.005)
	await run_fake(modal, 3, ok_step)
	require(modal.state == "out_of_credits" and modal.processed == 0, "too few estimated credits stop the run")
	# Ledger: spend recorded after the balance was set comes off it, and sets the typical cost.
	AutoPipeline.set_credits(5.0)
	AutoPipeline.record_spend("author", "claude-sonnet-5-5", {"input_tokens": 1000000})
	require(is_equal_approx(AutoPipeline.credits_left(), 3.0), "credits left = balance - spend since: %f" % AutoPipeline.credits_left())
	require(is_equal_approx(AutoPipeline.typical_cost("author", "claude-sonnet-5-5"), 2.0), "typical cost comes from the ledger")
	require(AutoPipeline.typical_cost("author", "claude-unknown") < 0.0, "no price, no estimate")
	modal.refresh_credits()
	require(modal.credits_label.text.contains("$3.00 left") and is_equal_approx(modal.credits_bar.value, 3.0), "the credits bar shows what's left: %s" % modal.credits_label.text)
	DirAccess.remove_absolute(AutoPipeline.credits_path())   # leave later checks without a balance

	await run_fake(modal, 3, ok_step, 0.0, 1)
	require(modal.state == "done" and modal.processed == 1, "item limit")

	await run_fake(modal, 3, func(_item) -> Dictionary: return {"outcome": "failed", "error_kind": "credits", "error": "no credit"})
	require(modal.state == "out_of_credits" and modal.processed == 0, "credit errors stop the run")

	await run_fake(modal, 3, func(_item) -> Dictionary: return {"outcome": "failed", "error_kind": "auth", "error": "bad key"})
	require(modal.state == "error" and modal.processed == 0, "auth errors stop the run")

	var calls := [0]
	var flaky := func(_item) -> Dictionary:
		calls[0] += 1
		return {"outcome": "failed", "error_kind": "rate_limit"} if calls[0] == 1 else {"outcome": "drafted"}
	await run_fake(modal, 1, flaky)
	require(modal.state == "done" and calls[0] == 2 and modal.outcomes.get("drafted") == 1, "rate limits are retried")

	await run_fake(modal, 8, func(_item) -> Dictionary: return {"outcome": "failed", "error": "boom"})
	require(modal.state == "error" and modal.processed == AutoRunModal.MAX_FAILURES_IN_A_ROW, "a failure streak stops the run")

	var stopper := func(_item) -> Dictionary:
		modal.request_stop()
		return {"outcome": "drafted"}
	await run_fake(modal, 3, stopper)
	require(modal.state == "stopped" and modal.processed == 1, "stop finishes the current item, then stops")
	require(modal.legend_label.get_parsed_text().contains("Has a candidate 2"), "legend shows the layers")
	modal.queue_free()


func check_studio_auto() -> void:
	var studio = StudioScene.instantiate()
	root.add_child(studio)
	await process_frame
	studio.provider.python_executable = ProjectSettings.globalize_path(FAKE_BRIDGE)
	OS.set_environment("FAKE_CLAUDE_MODE", "ok")
	var modal: AutoRunModal = studio.get_node("%AutoRunModal")
	modal.persist_settings = false
	# Auto mode follows the catalog search and skips stretches when ticked.
	require(AutoPipeline.studio_queue(studio.catalog, false).any(func(x: Dictionary) -> bool: return AutoPipeline.is_stretch(x)), "unticked, stretches are queued")
	require(not AutoPipeline.studio_queue(studio.catalog, true).any(func(x: Dictionary) -> bool: return AutoPipeline.is_stretch(x)), "ticked, stretches are skipped")
	studio.search_input.text = "press"
	studio.populate_catalog("press")
	var queue: Array = AutoPipeline.studio_queue(studio.filtered_catalog("press"), true)
	require(queue.size() >= 3, "studio queue must have work")
	require(queue.all(func(x: Dictionary) -> bool: return "press" in ("%s %s %s %s" % [x.get("name", ""), x.get("equipment", ""), x.get("category", ""), x.get("instructions", [])]).to_lower()), "queue follows the search")
	studio.open_auto_mode()
	require(modal.option_check.visible and modal.option_enabled(), "Skip stretches is offered and on by default")
	require(modal.description_label.text.contains("“press”"), "modal names the search it works through")
	require(modal.run_label.text.contains("%d exercise" % queue.size()), "modal counts the filtered queue: %s" % modal.run_label.text)
	require(modal.visible and modal.model_label.text.contains(studio.model_id), "modal shows the selected model")
	modal.max_items_spin.value = 3
	modal.run_limit_spin.value = 0.0
	await modal.start()
	require(modal.state == "done" and modal.outcomes.get("drafted") == 3, "studio auto must draft three exercises: %s %s" % [modal.state, modal.outcomes])
	require(modal.tokens_used() == 3 * FAKE_USAGE, "studio tokens counted")
	for source in queue.slice(0, 3):
		var draft := CandidateRepository.load_draft(String(source["source_id"]))
		require(draft.get("status") == "definition_candidate", "%s must be saved as a candidate" % source["source_id"])

	OS.set_environment("FAKE_CLAUDE_MODE", "credits")
	await modal.start()
	require(modal.state == "out_of_credits" and modal.processed == 0, "studio must stop when credits run out")
	OS.set_environment("FAKE_CLAUDE_MODE", "ok")
	studio.queue_free()
	await process_frame


func check_council_auto() -> void:
	var council = CouncilScene.instantiate()
	root.add_child(council)
	await process_frame
	council.provider.python_executable = ProjectSettings.globalize_path(FAKE_BRIDGE)
	# A stretch is rejected by rule. The fake bridge is out of credits here, so
	# any Claude request would fail the step instead.
	var stretch_entry := make_stretch_draft()
	OS.set_environment("FAKE_CLAUDE_MODE", "credits")
	var stretch_result: Dictionary = await council.auto_review(stretch_entry)
	OS.set_environment("FAKE_CLAUDE_MODE", "ok")
	require(stretch_result.get("outcome") == "rejected_stretch" and stretch_result.get("usage", {}).is_empty(), "stretch must be rejected without Claude: %s" % [stretch_result])
	var stretch_hash := ReviewRevisionStore.draft_revision_hash(stretch_entry["data"], council.catalog_by_source[stretch_entry["data"]["source_id"]])
	var stretch_review := ReviewRevisionStore.load_review(stretch_hash)
	require(stretch_review.get("status") == "changes_requested", "stretch review must request changes")
	require(stretch_review.get("votes", {}).get(ReviewRevisionStore.MODEL_MEMBER, {}).get("provider_metadata", {}).get("provider") == "bodysim_rule", "the vote comes from the rule")
	require(not stretch_review.get("votes", {}).has(ReviewRevisionStore.HUMAN_MEMBER), "no automatic owner approval for a stretch")
	var stretch_id := String(stretch_entry["data"]["source_id"])
	require(not AutoPipeline.studio_queue(AutoPipeline.load_catalog(), false).any(func(x: Dictionary) -> bool: return x.get("source_id") == stretch_id), "a rule-rejected stretch is never re-authored")
	# Suggested edits, in the same step: the reviewer rejects with an edit that
	# fixes everything; it's applied, re-frozen and reviewed again (2 reviews).
	var before_edits: Array = council.auto_council_queue().filter(func(e: Dictionary) -> bool: return e["kind"] == "draft")
	require(before_edits.size() >= 3, "need drafts for the edit checks")
	var edit_id := String(before_edits[1]["data"]["source_id"])
	OS.set_environment("FAKE_EDIT_SOURCE", edit_id)
	var edited: Dictionary = await council.auto_review(before_edits[1])
	OS.set_environment("FAKE_EDIT_SOURCE", "")
	require(edited.get("outcome") == "rejected_by_claude_after_edits", "edits are applied and re-reviewed: %s" % [edited])
	require(AutoPipeline.total_tokens(edited.get("usage", {})) == 2 * FAKE_USAGE, "both reviews are counted")
	var edited_draft := CandidateRepository.load_draft(edit_id)
	require(edited_draft["authoring_response"]["proposed_definition"]["kinematic_profile"]["kinetic_chain_type"] == "closed_chain", "the edit is in the new draft")
	require(edited_draft.get("provider_metadata", {}).has("edited_by_council"), "the draft records where its edits came from")
	# Suggested edits waiting from an earlier review show up as an "edits" entry.
	var waiting: Dictionary = before_edits[2]
	var waiting_id := String(waiting["data"]["source_id"])
	var frozen: Dictionary = ReviewRevisionStore.freeze_draft(waiting["data"], council.catalog_by_source[waiting_id])
	var waiting_hash := String(frozen["revision"]["revision_sha256"])
	ReviewRevisionStore.save_vote(waiting_hash, ReviewRevisionStore.HUMAN_MEMBER, {"decision": "accept"})
	ReviewRevisionStore.save_vote(waiting_hash, ReviewRevisionStore.MODEL_MEMBER, {"decision": "reject", "blocking_findings": [],
		"proposed_edits": [{"op": "set_kinetic_chain_type", "value": "closed_chain"}], "edits_resolve_all_blocking_findings": true})
	require(council.auto_council_queue().any(func(e: Dictionary) -> bool: return e["kind"] == "edits" and e["data"].get("source_id") == waiting_id), "edits waiting to be applied are queued")
	var queue: Array = council.auto_council_queue()
	require(not queue.any(func(e: Dictionary) -> bool: return e["data"].get("source_id") == stretch_id), "the rejected stretch leaves the queue")
	require(queue.size() >= 2, "council queue must have at least the two new drafts")
	var accepted_source := String(queue.filter(func(e: Dictionary) -> bool: return e["kind"] == "draft")[0]["data"].get("source_id", ""))
	OS.set_environment("FAKE_ACCEPT_SOURCE", accepted_source)
	var before: int = AutoPipeline.layers(AutoPipeline.snapshot())["done"]
	var modal: AutoRunModal = council.get_node("%AutoRunModal")
	modal.persist_settings = false
	council.open_auto_mode()
	require(modal.legend_label.get_parsed_text().contains("Promoted"), "council modal labels the first layer Promoted")
	modal.max_items_spin.value = 0             # the sandbox reads the owner's saved settings; pin them
	modal.run_limit_spin.value = 0.0
	await modal.start()
	require(modal.state == "done", "council run must finish: %s" % modal.state)
	require(modal.outcomes.get("promoted") == 1, "exactly the accepted exercise is promoted: %s" % [modal.outcomes])
	require(int(modal.outcomes.get("rejected_by_claude", 0)) + int(modal.outcomes.get("rejected_by_claude_after_edits", 0)) == queue.size() - 1, "Claude's rejections stand: %s" % [modal.outcomes])
	require(int(modal.outcomes.get("rejected_by_claude_after_edits", 0)) == 1, "the waiting edits were applied in the run: %s" % [modal.outcomes])
	require(AutoPipeline.layers(AutoPipeline.snapshot())["done"] == before + 1, "promoted layer grows by one")
	for hash in DirAccess.get_files_at(ReviewRevisionStore.REVIEW_DIRECTORY):
		var review := ReviewRevisionStore.read_json("%s/%s" % [ReviewRevisionStore.REVIEW_DIRECTORY, hash])
		var human: Dictionary = review.get("votes", {}).get("human_owner", {})
		if human.get("auto_mode", false):
			require(human.get("decision") == "accept", "auto mode records the owner's approval")
	require(council.auto_council_queue().is_empty(), "nothing waits after the run")
	council.queue_free()
	await process_frame


## A passing draft re-keyed to a catalog stretch, saved like a Studio draft.
func make_stretch_draft() -> Dictionary:
	var stretch: Dictionary = {}
	for source in AutoPipeline.load_catalog():
		if AutoPipeline.is_stretch(source) and source.get("status") == "catalog_only" and CandidateRepository.load_draft(String(source["source_id"])).is_empty():
			stretch = source
			break
	var template: Dictionary = {}
	for draft in AutoPipeline.load_drafts().values():
		if draft.get("status") == "definition_candidate" and ReviewRevisionStore.validate_eligibility(draft).is_empty():
			template = draft
			break
	require(not stretch.is_empty() and not template.is_empty(), "need a stretch source and a passing draft")
	var draft := template.duplicate(true)
	for key in ["source_id", "catalog_id", "source_snapshot_sha256"]:
		draft[key] = stretch.get(key, "")
	var file := FileAccess.open(CandidateRepository.draft_path(String(stretch["source_id"])), FileAccess.WRITE)
	file.store_string(JSON.stringify(draft, "  "))
	file.close()
	return {"kind": "draft", "data": draft}
