class_name ReviewRevisionStore
extends RefCounted

const REVISION_DIRECTORY := "res://data/exercises/authoring/revisions"
const REVIEW_DIRECTORY := "res://data/exercises/authoring/reviews"


static func freeze_draft(draft: Dictionary, source: Dictionary) -> Dictionary:
	var eligibility := validate_eligibility(draft)
	if not eligibility.is_empty():
		return {"ok": false, "errors": eligibility}
	var payload := {
		"format_version": 1,
		"source_id": draft.get("source_id", ""),
		"catalog_id": draft.get("catalog_id", ""),
		"source_snapshot_sha256": draft.get("source_snapshot_sha256", ""),
		"source": source,
		"additional_context": draft.get("additional_context", ""),
		"authoring_response": draft.get("authoring_response", {}),
		"authoring_provider_metadata": draft.get("provider_metadata", {}),
		"candidate_trace_report": draft.get("candidate_trace_report", {}),
	}
	var canonical := JSON.stringify(sort_json(payload))
	var hash := canonical.sha256_text()
	var revision := payload.duplicate(true)
	revision["revision_sha256"] = hash
	revision["revision_id"] = "%s@%s" % [draft.get("source_id", "candidate"), hash.left(12)]
	revision["status"] = "review_pending"
	var path := revision_path(hash)
	if FileAccess.file_exists(path):
		var existing := read_json(path)
		if existing.get("revision_sha256", "") != hash:
			return {"ok": false, "errors": ["Existing immutable revision does not match its hash."]}
		return {"ok": true, "path": path, "revision": existing, "created": false}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Could not write frozen revision: %s" % path]}
	file.store_string(JSON.stringify(revision, "  "))
	return {"ok": true, "path": path, "revision": revision, "created": true}


static func validate_eligibility(draft: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if draft.get("status", "") != "definition_candidate":
		errors.append("Draft has not reached definition_candidate.")
	if not draft.get("validation_errors", []).is_empty():
		errors.append("Draft still has deterministic validation errors.")
	var trace: Dictionary = draft.get("candidate_trace_report", {})
	if not trace.get("ok", false):
		errors.append("Draft must be revalidated and saved with a passing Phase 2C trace report.")
	if trace.get("summary", {}).get("total_muscles", 0) != 466:
		errors.append("Frozen trace must cover exactly 466 canonical muscles.")
	return errors


static func reject_unfrozen_draft(draft: Dictionary, feedback: String) -> Dictionary:
	var source_id := String(draft.get("source_id", ""))
	if source_id.is_empty():
		return {"ok": false, "error": "Draft has no source ID."}
	if feedback.strip_edges().is_empty():
		return {"ok": false, "error": "Add a rejection reason in the human feedback field."}
	var rejected := draft.duplicate(true)
	rejected["status"] = "review_rejected"
	rejected["rejection"] = {
		"member": "human_owner",
		"summary": feedback.strip_edges(),
		"recorded_at_unix": Time.get_unix_time_from_system(),
		"stage": "unfrozen_candidate",
	}
	var path := "res://data/exercises/authoring/drafts/%s.json" % source_id.validate_filename()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not persist the rejected candidate."}
	file.store_string(JSON.stringify(rejected, "  "))
	return {"ok": true, "path": path, "record": rejected}


static func save_vote(revision_hash: String, member: String, vote: Dictionary, controlled_context := "") -> Dictionary:
	if revision_hash.is_empty() or not FileAccess.file_exists(revision_path(revision_hash)):
		return {"ok": false, "error": "The vote does not reference an existing frozen revision."}
	var record := load_review(revision_hash)
	if record.is_empty():
		record = {"format_version": 1, "revision_sha256": revision_hash, "votes": {}}
	var votes: Dictionary = record.get("votes", {})
	votes[member] = vote
	record["votes"] = votes
	record["controlled_review_context"] = controlled_context
	record["updated_at_unix"] = Time.get_unix_time_from_system()
	record["status"] = council_status(votes)
	var file := FileAccess.open(review_path(revision_hash), FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not persist council votes."}
	file.store_string(JSON.stringify(record, "  "))
	return {"ok": true, "record": record}


static func council_status(votes: Dictionary) -> String:
	for vote in votes.values():
		if vote is Dictionary and vote.get("decision", "") == "reject":
			return "changes_requested"
	if votes.has("human_owner") and votes.has("openai_reviewer"):
		if votes["human_owner"].get("decision") == "accept" and votes["openai_reviewer"].get("decision") == "accept":
			return "accepted"
	return "review_pending"


static func list_revisions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(REVISION_DIRECTORY)
	if directory == null:
		return result
	for filename in directory.get_files():
		if filename.ends_with(".json"):
			var value := read_json("%s/%s" % [REVISION_DIRECTORY, filename])
			if not value.is_empty(): result.append(value)
	return result


static func load_review(hash: String) -> Dictionary:
	return read_json(review_path(hash))


static func revision_path(hash: String) -> String:
	return "%s/%s.json" % [REVISION_DIRECTORY, hash]


static func review_path(hash: String) -> String:
	return "%s/%s.json" % [REVIEW_DIRECTORY, hash]


static func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func sort_json(value):
	if value is Dictionary:
		var ordered := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys: ordered[key] = sort_json(value[key])
		return ordered
	if value is Array:
		var result := []
		for item in value: result.append(sort_json(item))
		return result
	return value
