class_name AutoPipeline
extends RefCounted

## Shared state for auto mode in the Kinematic Definition Studio and the
## Review Council: where every catalog exercise is in the pipeline, which
## ones each auto run should pick up, and token/cost accounting.
##
## Pipeline state of a catalog exercise:
##   promoted      visualizable (the council promoted it)
##   candidate     a passing draft or frozen revision is waiting in the council
##   needs_rework  the council rejected it; re-authoring will use the feedback
##   attempted     authored, but it failed the candidate gate (often Claude
##                 said BodySim can't model it); auto mode doesn't retry these
##   cleared       hidden from the council queue by the owner; left alone
##   new           never authored

const CATALOG_PATH := "res://data/exercises/catalog/candidates.json"
const DRAFT_DIR := "res://data/exercises/authoring/drafts"
const SETTINGS_SECTION := "auto_mode"
const DEFAULT_TOKEN_BUDGET := 2000000
const RETRYABLE_ERRORS := ["rate_limit", "overloaded", "network"]
const FATAL_ERRORS := ["auth", "model"]

## USD per million tokens: input, output, cache read, 1-hour cache write.
## The prompts cache their prefix with a 1-hour TTL. An estimate only; the
## Claude Console is the source of truth for billing.
const PRICES := {
	"claude-opus-5-5": [4.0, 20.0, 0.20, 8.0],
	"claude-sonnet-5-5": [2.0, 10.0, 0.20, 4.0],
	"claude-haiku-5-5": [0.10, 0.50, 0.01, 0.20],
	"claude-fable-5-1": [10.0, 50.0, 0.25, 20.0],
}


static func load_catalog() -> Array:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file else null
	return parsed if parsed is Array else []


static func load_drafts() -> Dictionary:
	var drafts := {}
	var directory := DirAccess.open(DRAFT_DIR)
	if directory == null:
		return drafts
	for filename in directory.get_files():
		if not filename.ends_with(".json"):
			continue
		var file := FileAccess.open("%s/%s" % [DRAFT_DIR, filename], FileAccess.READ)
		var draft = JSON.parse_string(file.get_as_text()) if file else null
		if draft is Dictionary:
			drafts[String(draft.get("source_id", ""))] = draft
	return drafts


## Pipeline state for one catalog source (see the table at the top).
static func source_state(source: Dictionary, draft: Dictionary, cleared: Dictionary) -> String:
	if source.get("status", "") == "promoted":
		return "promoted"
	if draft.is_empty():
		return "new"
	if ReviewRevisionStore.is_cleared("draft", draft, cleared):
		return "cleared"
	match String(draft.get("status", "")):
		"review_rejected":
			return "needs_rework"
		"definition_candidate":
			if not ReviewRevisionStore.validate_eligibility(draft).is_empty():
				return "attempted"
			var hash := ReviewRevisionStore.draft_revision_hash(draft, source)
			if not ReviewRevisionStore.load_promotion(hash).is_empty():
				return "promoted"
			if ReviewRevisionStore.load_review(hash).get("status", "") == "changes_requested":
				return "cleared" if hash in cleared.get("revisions", {}) else "needs_rework"
			return "candidate"
	return "attempted"


## {"states": {source_id: state}, "counts": {state: n}, "total": n}
static func snapshot() -> Dictionary:
	var drafts := load_drafts()
	var cleared := ReviewRevisionStore.load_cleared()
	var states := {}
	var counts := {"promoted": 0, "candidate": 0, "needs_rework": 0, "attempted": 0, "cleared": 0, "new": 0}
	var catalog := load_catalog()
	for source in catalog:
		var source_id := String(source.get("source_id", ""))
		var state := source_state(source, drafts.get(source_id, {}), cleared)
		states[source_id] = state
		counts[state] += 1
	return {"states": states, "counts": counts, "total": catalog.size()}


## The three layers both auto-mode modals draw.
static func layers(snap: Dictionary) -> Dictionary:
	var counts: Dictionary = snap.get("counts", {})
	var done := int(counts.get("promoted", 0))
	var candidate := int(counts.get("candidate", 0))
	return {"done": done, "candidate": candidate, "remaining": int(snap.get("total", 0)) - done - candidate}


## Studio auto queue: exercises the council sent back first (their feedback
## goes into the request), then never-authored ones in catalog order.
static func studio_queue(catalog_only: Array) -> Array:
	var states: Dictionary = snapshot()["states"]
	var rework: Array = []
	var fresh: Array = []
	for source in catalog_only:
		match String(states.get(String(source.get("source_id", "")), "new")):
			"needs_rework": rework.append(source)
			"new": fresh.append(source)
	return rework + fresh


static func total_tokens(usage: Dictionary) -> int:
	return int(usage.get("input_tokens", 0)) + int(usage.get("output_tokens", 0)) \
		+ int(usage.get("cache_read_input_tokens", 0)) + int(usage.get("cache_creation_input_tokens", 0))


## Estimated USD for a usage total; -1 when the model has no known price.
static func estimate_cost(model: String, usage: Dictionary) -> float:
	if not PRICES.has(model):
		return -1.0
	var p: Array = PRICES[model]
	return (float(usage.get("input_tokens", 0)) * p[0] + float(usage.get("output_tokens", 0)) * p[1] \
		+ float(usage.get("cache_read_input_tokens", 0)) * p[2] \
		+ float(usage.get("cache_creation_input_tokens", 0)) * p[3]) / 1000000.0


static func load_setting(key: String, default_value):
	var settings := ConfigFile.new()
	if settings.load(ClaudeSettings.SETTINGS_PATH) != OK:
		return default_value
	return settings.get_value(SETTINGS_SECTION, key, default_value)


static func save_setting(key: String, value) -> void:
	var settings := ConfigFile.new()
	settings.load(ClaudeSettings.SETTINGS_PATH)   # keep the API key and every other setting
	settings.set_value(SETTINGS_SECTION, key, value)
	settings.save(ClaudeSettings.SETTINGS_PATH)
