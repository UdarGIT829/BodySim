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


static func latest_rejection_feedback(source_id: String) -> String:
	var newest_time := -1.0
	var newest_feedback := ""
	var revisions := DirAccess.open(REVISION_DIRECTORY)
	if revisions == null:
		return ""
	for filename in revisions.get_files():
		if not filename.ends_with(".json"): continue
		var revision := _read_dictionary("%s/%s" % [REVISION_DIRECTORY, filename])
		if revision.get("source_id", "") != source_id: continue
		var hash := String(revision.get("revision_sha256", ""))
		var review := _read_dictionary("%s/%s.json" % [REVIEW_DIRECTORY, hash])
		if review.get("status", "") != "changes_requested": continue
		var updated := float(review.get("updated_at_unix", 0.0))
		if updated < newest_time: continue
		var lines: Array[String] = []
		for member in review.get("votes", {}):
			var vote: Dictionary = review["votes"][member]
			if vote.get("decision", "") != "reject": continue
			lines.append("Council feedback from %s:" % member)
			for finding in vote.get("blocking_findings", []):
				lines.append("- %s: %s Suggested correction: %s" % [finding.get("field_path", ""), finding.get("finding", ""), finding.get("suggested_correction", "")])
			if vote.get("blocking_findings", []).is_empty(): lines.append("- %s" % vote.get("summary", "Rejected without detail."))
		newest_time = updated
		newest_feedback = "\n".join(lines)
	return newest_feedback


static func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
