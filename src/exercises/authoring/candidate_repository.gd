class_name CandidateRepository
extends RefCounted

const DRAFT_DIRECTORY := "res://data/exercises/authoring/drafts"
const REVISION_DIRECTORY := "res://data/exercises/authoring/revisions"
const REVIEW_DIRECTORY := "res://data/exercises/authoring/reviews"


static func draft_path(source_id: String) -> String:
	return "%s/%s.json" % [DRAFT_DIRECTORY, source_id.validate_filename()]


static func load_draft(source_id: String) -> Dictionary:
	var file := FileAccess.open(draft_path(source_id), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func save_draft(source: Dictionary, author_context: String, response: Dictionary, metadata: Dictionary, validation_errors: Array[String], trace_report: Dictionary = {}) -> Dictionary:
	var path := draft_path(String(source.get("source_id", "unknown")))
	var record := {
		"format_version": 1,
		"catalog_id": source.get("catalog_id", ""),
		"source_id": source.get("source_id", ""),
		"source_snapshot_sha256": source.get("source_snapshot_sha256", ""),
		"status": "definition_candidate" if validation_errors.is_empty() else "authoring_draft",
		"additional_context": author_context,
		"authoring_response": response,
		"provider_metadata": metadata,
		"validation_errors": validation_errors,
		"candidate_trace_report": trace_report,
		"saved_at_unix": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s" % path}
	file.store_string(JSON.stringify(record, "  "))
	return {"ok": true, "path": path, "record": record}


## Feedback for re-authoring an exercise: the council's most recent decision
## against it, whichever came last of
##   - a rejected frozen revision (every rejecting vote's blocking findings
##     and suggested corrections), noting when it was reviewed under an older
##     tracer, whose limits some suggestions may have worked around;
##   - a demotion after promotion (its reason);
##   - the owner's rejection of an unfrozen draft (its reason).
## The block is wrapped in FEEDBACK_START / FEEDBACK_END so it can be replaced
## (not stacked) the next time the exercise is re-authored.
const FEEDBACK_START := "[Council feedback on the previous definition]"
const FEEDBACK_END := "[End of council feedback]"


static func latest_rejection_feedback(source_id: String, source: Dictionary = {}) -> String:
	var newest_time := -1.0
	var lines: Array[String] = []
	var revisions := DirAccess.open(REVISION_DIRECTORY)
	if revisions != null:
		for filename in revisions.get_files():
			if not filename.ends_with(".json"): continue
			var revision := _read_dictionary("%s/%s" % [REVISION_DIRECTORY, filename])
			if revision.get("source_id", "") != source_id: continue
			var review := _read_dictionary("%s/%s.json" % [REVIEW_DIRECTORY, String(revision.get("revision_sha256", ""))])
			if review.get("status", "") != "changes_requested": continue
			var updated := float(review.get("updated_at_unix", 0.0))
			if updated < newest_time: continue
			newest_time = updated
			lines = _review_feedback(review, String(revision.get("candidate_trace_report", {}).get("provenance", {}).get("tracer", "")))
	for demotion in source.get("demotions", []):
		if float(demotion.get("demoted_at_unix", 0.0)) >= newest_time:
			newest_time = float(demotion.get("demoted_at_unix", 0.0))
			lines = ["The previous definition was promoted and later demoted. Reason: %s" % demotion.get("reason", "none given")]
	var draft := load_draft(source_id)
	var rejection: Dictionary = draft.get("rejection", {})
	if rejection.get("stage", "") == "unfrozen_candidate" and float(rejection.get("recorded_at_unix", 0.0)) >= newest_time:
		lines = ["The owner rejected the previous draft before review. Reason: %s" % rejection.get("summary", "none given")]
	if lines.is_empty():
		return ""
	return "%s\n%s\n%s" % [FEEDBACK_START, "\n".join(lines), FEEDBACK_END]


static func _review_feedback(review: Dictionary, tracer: String) -> Array[String]:
	var lines: Array[String] = []
	if not tracer.is_empty() and tracer != AutoPipeline.CURRENT_TRACER:
		lines.append("Note: this review judged a trace from %s; the current tracer is %s, which adds per-action emphasis and sides and one_sided_limbs. Where a suggestion only works around a limit of the older tracer, use the current fields instead." % [tracer, AutoPipeline.CURRENT_TRACER])
	for member in review.get("votes", {}):
		var vote: Dictionary = review["votes"][member]
		if vote.get("decision", "") != "reject": continue
		lines.append("From %s:" % member)
		for finding in vote.get("blocking_findings", []):
			lines.append("- %s: %s Suggested correction: %s" % [finding.get("field_path", ""), finding.get("finding", ""), finding.get("suggested_correction", "")])
		if vote.get("blocking_findings", []).is_empty():
			lines.append("- %s" % vote.get("summary", "Rejected without detail."))
	return lines


## Removes earlier council feedback from saved author context, so feedback
## from older rounds isn't stacked into the next request. Handles the
## current markers and the older unmarked "Council feedback from ..." blocks.
static func strip_council_feedback(context: String) -> String:
	var kept: Array[String] = []
	var skipping := false
	var in_marked := false
	for line in context.split("\n"):
		if line.begins_with(FEEDBACK_START):
			in_marked = true
			continue
		if in_marked:
			if line.begins_with(FEEDBACK_END):
				in_marked = false
			continue
		if line.begins_with("Council feedback from "):
			skipping = true
			continue
		if skipping and line.begins_with("- "):
			continue
		skipping = false
		kept.append(line)
	return "\n".join(kept).strip_edges()


static func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
