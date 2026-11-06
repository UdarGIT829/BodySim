class_name ReviewRevisionStore
extends RefCounted

const REVISION_DIRECTORY := "res://data/exercises/authoring/revisions"
const REVIEW_DIRECTORY := "res://data/exercises/authoring/reviews"
const PROMOTION_DIRECTORY := "res://data/exercises/authoring/promotions"
## Council members. Votes recorded before the switch to Claude used
## "openai_reviewer"; they are still read (rejections stay visible) but can
## no longer satisfy acceptance.
const HUMAN_MEMBER := "human_owner"
const MODEL_MEMBER := "model_reviewer"
const LEGACY_MODEL_MEMBERS := ["openai_reviewer"]
const PROMOTION_BRIDGE := "res://tools/exercises/run_promotion.py"
const PAYLOAD_KEYS := ["format_version", "source_id", "catalog_id", "source_snapshot_sha256", "source",
	"additional_context", "authoring_response", "authoring_provider_metadata", "candidate_trace_report"]


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
	if votes.has(HUMAN_MEMBER) and votes.has(MODEL_MEMBER):
		if votes[HUMAN_MEMBER].get("decision") == "accept" and votes[MODEL_MEMBER].get("decision") == "accept":
			return "accepted"
	return "review_pending"


## The model member's vote, falling back to a pre-Claude vote for display.
static func model_vote(votes: Dictionary) -> Dictionary:
	if votes.get(MODEL_MEMBER) is Dictionary:
		return votes[MODEL_MEMBER]
	for legacy in LEGACY_MODEL_MEMBERS:
		if votes.get(legacy) is Dictionary:
			return votes[legacy]
	return {}


## True when a frozen revision still hashes to the value it was stored
## under, using the same canonical serialization as freeze_draft().
static func verify_revision_hash(revision: Dictionary) -> bool:
	var payload := {}
	for key in PAYLOAD_KEYS:
		payload[key] = revision.get(key)
	# freeze_draft() hashes format_version as the int literal 1; JSON read back
	# from disk turns every number into a float, which serializes as "1.0".
	payload["format_version"] = int(revision.get("format_version", 0))
	var expected := String(revision.get("revision_sha256", ""))
	return not expected.is_empty() and JSON.stringify(sort_json(payload)).sha256_text() == expected


static func load_promotion(hash: String) -> Dictionary:
	return read_json("%s/%s.json" % [PROMOTION_DIRECTORY, hash])


## Phase 2E: verify the revision, then run the Python promotion transaction.
static func promote(revision: Dictionary, python_executable := "python3") -> Dictionary:
	var hash := String(revision.get("revision_sha256", ""))
	if not verify_revision_hash(revision):
		return {"ok": false, "errors": ["Frozen revision content no longer matches its hash; it cannot be promoted."]}
	if load_review(hash).get("status", "") != "accepted":
		return {"ok": false, "errors": ["Only a unanimously accepted revision can be promoted."]}
	var nonce := "%d" % Time.get_ticks_usec()
	var input_path := "user://promotion_%s_input.json" % nonce
	var output_path := "user://promotion_%s_output.json" % nonce
	var input_file := FileAccess.open(input_path, FileAccess.WRITE)
	if input_file == null:
		return {"ok": false, "errors": ["Could not create the promotion request file."]}
	input_file.store_string(JSON.stringify({"revision_sha256": hash, "dry_run": false}))
	input_file.close()
	var console_output: Array = []
	var exit_code := OS.execute(python_executable, PackedStringArray([
		ProjectSettings.globalize_path(PROMOTION_BRIDGE),
		"--input", ProjectSettings.globalize_path(input_path),
		"--output", ProjectSettings.globalize_path(output_path),
	]), console_output, true)
	var report := read_json(output_path)
	for path in [input_path, output_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if report.is_empty():
		return {"ok": false, "errors": ["Promotion exited with code %d without a report. %s" % [exit_code, " ".join(console_output)]]}
	return report


# ── Clearing the review queue ───────────────────────────────────────────────
# Clearing hides a candidate from the council queue without deleting anything:
# drafts, revisions and votes stay on disk for the audit trail. A cleared draft
# reappears if it is saved again later (it is then a new candidate).

const CLEARED_PATH := "res://data/exercises/authoring/cleared.json"


static func load_cleared() -> Dictionary:
	var data := read_json(CLEARED_PATH)
	if data.is_empty():
		data = {"format_version": 1, "drafts": {}, "revisions": {}}
	return data


static func is_cleared(kind: String, record: Dictionary, cleared: Dictionary) -> bool:
	if kind == "revision":
		return cleared.get("revisions", {}).has(String(record.get("revision_sha256", "")))
	var entry: Dictionary = cleared.get("drafts", {}).get(String(record.get("source_id", "")), {})
	return not entry.is_empty() and float(record.get("saved_at_unix", 0.0)) <= float(entry.get("draft_saved_at_unix", -1.0))


## Returns "" when the record may be cleared, otherwise the reason it can't.
static func clear_blocker(kind: String, record: Dictionary) -> String:
	if kind == "revision":
		var hash := String(record.get("revision_sha256", ""))
		if not load_promotion(hash).is_empty():
			return "Promoted revisions are part of the catalog history and can't be cleared."
		if load_review(hash).get("status", "") == "accepted":
			return "Reject this accepted revision first if you no longer want it."
		return ""
	if record.get("status", "") != "review_rejected":
		return "Reject this draft first (Reject and clear does both)."
	return ""


static func clear_entries(items: Array, reason: String) -> Dictionary:
	var cleared := load_cleared()
	var now := Time.get_unix_time_from_system()
	var count := 0
	for item in items:
		var kind: String = item["kind"]
		var record: Dictionary = item["data"]
		if not clear_blocker(kind, record).is_empty() or is_cleared(kind, record, cleared):
			continue
		if kind == "revision":
			cleared["revisions"][String(record.get("revision_sha256", ""))] = {"cleared_at_unix": now, "reason": reason, "revision_id": record.get("revision_id", "")}
		else:
			cleared["drafts"][String(record.get("source_id", ""))] = {"cleared_at_unix": now, "reason": reason, "draft_saved_at_unix": record.get("saved_at_unix", 0.0)}
		count += 1
	if count == 0:
		return {"ok": true, "cleared": 0}
	var file := FileAccess.open(CLEARED_PATH, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Could not write %s." % CLEARED_PATH}
	file.store_string(JSON.stringify(sort_json(cleared), "  "))
	return {"ok": true, "cleared": count}


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
