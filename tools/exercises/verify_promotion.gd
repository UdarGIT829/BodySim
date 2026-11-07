extends SceneTree

## Phase 2E end-to-end check: freeze → unanimous votes → hash verification →
## promotion through the Python bridge → the exercise becomes visualizable.
## It writes to data/, so it only runs inside the disposable project copy made
## by tools/exercises/verify_promotion.sh (BODYSIM_SANDBOX=1).

const Store := preload("res://src/exercises/review/review_revision_store.gd")
const SelectorScene := preload("res://scenes/exercises/exercise_selector.tscn")
const StudioScene := preload("res://scenes/exercises/kinematic_definition_studio.tscn")
const CouncilScene := preload("res://scenes/exercises/exercise_review_council.tscn")
const DRAFT := "res://data/exercises/authoring/drafts/_promotion_fixture.json"   # written by verify_promotion.sh
const EXERCISE_ID := "exercise.promotion_fixture.standing_bilateral"

var failures: Array[String] = []


func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _initialize() -> void:
	if OS.get_environment("BODYSIM_SANDBOX") != "1":
		push_error("verify_promotion.gd modifies data/; run tools/exercises/verify_promotion.sh instead.")
		quit(2)
		return
	var draft: Dictionary = Store.read_json(DRAFT)
	draft["status"] = "definition_candidate"
	draft["validation_errors"] = []
	draft.erase("rejection")
	var frozen: Dictionary = Store.freeze_draft(draft, {"name": "Promotion fixture"})
	require(frozen.get("ok", false), "freeze failed: %s" % [frozen.get("errors", [])])
	var revision: Dictionary = frozen.get("revision", {})
	var hash := String(revision.get("revision_sha256", ""))

	require(Store.verify_revision_hash(revision), "fresh revision must verify against its hash")
	var reloaded: Dictionary = Store.read_json(Store.revision_path(hash))
	require(Store.verify_revision_hash(reloaded), "revision read back from disk must still verify")
	var tampered := reloaded.duplicate(true)
	tampered["additional_context"] = "edited after review"
	require(not Store.verify_revision_hash(tampered), "a tampered revision must fail verification")

	var blocked: Dictionary = Store.promote(reloaded)
	require(not blocked.get("ok", true), "promotion must be refused before the council accepts")

	Store.save_vote(hash, "human_owner", {"decision": "accept", "summary": "verified"})
	Store.save_vote(hash, Store.MODEL_MEMBER, {"decision": "accept", "summary": "verified"})
	require(Store.load_review(hash).get("status") == "accepted", "two accepts must produce 'accepted'")
	require(not Store.promote(tampered).get("ok", true), "a tampered revision must not be promotable")

	var report: Dictionary = Store.promote(reloaded)
	require(report.get("ok", false), "promotion failed: %s" % [report.get("errors", [])])
	require(report.get("exercise_id") == EXERCISE_ID, "unexpected promoted id %s" % report.get("exercise_id"))
	require(not Store.load_promotion(hash).is_empty(), "promotion record must exist")
	require(Store.promote(reloaded).get("already_promoted", false), "second promotion must be a no-op")

	# Clearing writes cleared.json and never touches promoted revisions.
	require(not Store.clear_blocker("revision", reloaded).is_empty(), "A promoted revision must not be clearable")
	var rejected_draft := {"source_id": "Cleared_Test", "status": "review_rejected", "saved_at_unix": 1.0}
	var cleared_result: Dictionary = Store.clear_entries([{"kind": "revision", "data": reloaded}, {"kind": "draft", "data": rejected_draft}], "test")
	require(cleared_result.get("ok", false) and cleared_result.get("cleared") == 1, "Only the rejected draft must be cleared: %s" % [cleared_result])
	var cleared_now: Dictionary = Store.load_cleared()
	require(Store.is_cleared("draft", rejected_draft, cleared_now), "Cleared draft must be recorded")
	require(not Store.is_cleared("revision", reloaded, cleared_now), "Promoted revision must not be recorded as cleared")

	var selector: Node = SelectorScene.instantiate()
	root.add_child(selector)
	await process_frame
	require(selector.records_by_id.has(EXERCISE_ID), "selector must list the promoted exercise")
	require(selector.records_by_id.get(EXERCISE_ID, {}).get("catalog_status") == "visualizable", "promoted exercise must be visualizable")
	require(not selector.records_by_id.has(String(draft.get("catalog_id", ""))), "source record must leave the catalog-only list")
	require(selector.select_exercise(EXERCISE_ID), "promoted exercise must be selectable")
	selector.queue_free()

	# Demotion, driven through the Studio's dialog like a click.
	var studio = StudioScene.instantiate()
	root.add_child(studio)
	await process_frame
	var source_id := String(draft.get("source_id", ""))
	require(not studio.catalog.any(func(x: Dictionary) -> bool: return x.get("source_id") == source_id), "promoted source must not be in the Studio catalog")
	var dialog: DemoteDialog = studio.get_node("%DemoteDialog")
	dialog.open()
	var index := -1
	for i in dialog.exercises.size():
		if dialog.exercises[i].get("exercise_id") == EXERCISE_ID: index = i
	require(index >= 0, "the dialog must list the council-promoted fixture")
	require(not dialog.exercises.any(func(x: Dictionary) -> bool: return String(x.get("exercise_id", "")) == "exercise.barbell_back_squat.high_bar"), "original exercises must not be listed")
	dialog.exercise_list.select(index)
	dialog._on_selected(index)
	dialog.reason_input.text = "verification demotion"
	dialog._on_demote_pressed()
	require(not Store.load_promotion(hash).is_empty(), "the first click only arms the button")
	dialog._on_demote_pressed()
	require(Store.load_promotion(hash).is_empty() and Store.load_demotion(hash).get("reason") == "verification demotion", "demotion record replaces the promotion record")
	require(studio.catalog.any(func(x: Dictionary) -> bool: return x.get("source_id") == source_id), "the source is back in the Studio catalog")
	require(not dialog.exercises.any(func(x: Dictionary) -> bool: return x.get("exercise_id") == EXERCISE_ID), "the dialog list refreshes")
	var exercises: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/exercises/exercises.json"))
	require(not exercises.any(func(x: Dictionary) -> bool: return x.get("id") == EXERCISE_ID), "the exercise leaves exercises.json")
	var again: Dictionary = Store.promote(reloaded)
	require(not again.get("ok", true) and " ".join(again.get("errors", [])).contains("demoted"), "a demoted revision can't be promoted again: %s" % [again])
	studio.queue_free()
	var council = CouncilScene.instantiate()
	root.add_child(council)
	await process_frame
	council.show_revision(reloaded)
	require(council.get_node("%CouncilOutcome").text.contains("Demoted") and council.get_node("%PromoteButton").disabled, "the council shows it demoted and can't promote it")
	require(not council.auto_council_queue().any(func(e: Dictionary) -> bool: return e["data"].get("revision_sha256") == hash), "auto mode skips a demoted revision")
	council.queue_free()

	if failures.is_empty():
		print("Phase 2E promotion passed: freeze, hash verification, unanimous gate, bridge, idempotence, selector heatmap, demotion from the Studio")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
