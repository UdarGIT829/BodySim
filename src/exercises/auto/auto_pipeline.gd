class_name AutoPipeline
extends RefCounted

## Shared state for auto mode in the Kinematic Definition Studio and the
## Review Council: where every catalog exercise is in the pipeline, which
## ones each auto run should pick up, and token/cost accounting.
##
## Pipeline state of a catalog exercise:
##   promoted      visualizable (the council promoted it)
##   candidate     a passing draft or frozen revision is waiting in the council
##   needs_rework  the council rejected it (or it was demoted after promotion);
##                 re-authoring will use the feedback
##   attempted     authored, but it failed the candidate gate (often Claude
##                 said BodySim can't model it); auto mode doesn't retry these
##   edits_pending Claude rejected it but proposed edits that fix every
##                 blocking finding; the council applies them (no re-authoring)
##   set_aside     Claude rejected it MAX_CLAUDE_REJECTIONS times under the
##                 current tracer; auto mode stops re-authoring it for you to look at
##   cleared       hidden from the council queue by the owner; left alone
##   new           never authored

const CATALOG_PATH := "res://data/exercises/catalog/candidates.json"
const DRAFT_DIR := "res://data/exercises/authoring/drafts"
const SETTINGS_SECTION := "auto_mode"
const RETRYABLE_ERRORS := ["rate_limit", "overloaded", "network"]
const FATAL_ERRORS := ["auth", "model"]
## Must match TRACER_VERSION in tools/exercises/kinematic_tracer.py (a test checks).
const CURRENT_TRACER := "kinematic_tracer_v3"
## After this many Claude rejections under the current tracer, auto mode stops
## re-authoring an exercise.
const MAX_CLAUDE_REJECTIONS := 2

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
static func source_state(source: Dictionary, draft: Dictionary, cleared: Dictionary, rejections := {}) -> String:
	var state := _base_state(source, draft, cleared)
	if state in ["needs_rework", "edits_pending"] and int(rejections.get(String(source.get("source_id", "")), 0)) >= MAX_CLAUDE_REJECTIONS:
		return "set_aside"
	return state


static func _base_state(source: Dictionary, draft: Dictionary, cleared: Dictionary) -> String:
	if source.get("status", "") == "promoted":
		return "promoted"
	if draft.is_empty():
		return "new"
	if ReviewRevisionStore.is_cleared("draft", draft, cleared):
		return "cleared"
	var demotions: Array = source.get("demotions", [])
	if not demotions.is_empty() and float(draft.get("saved_at_unix", 0.0)) <= float(demotions[-1].get("demoted_at_unix", 0.0)):
		return "needs_rework"   # demoted after promotion; the draft predates the demotion
	match String(draft.get("status", "")):
		"review_rejected":
			return "needs_rework"
		"definition_candidate":
			if not ReviewRevisionStore.validate_eligibility(draft).is_empty():
				return "attempted"
			var hash := ReviewRevisionStore.draft_revision_hash(draft, source)
			if not ReviewRevisionStore.load_demotion(hash).is_empty():
				return "needs_rework"   # demoted after promotion; it needs a new revision
			if not ReviewRevisionStore.load_promotion(hash).is_empty():
				return "promoted"
			var review := ReviewRevisionStore.load_review(hash)
			if review.get("status", "") == "changes_requested":
				if hash in cleared.get("revisions", {}):
					return "cleared"
				return "edits_pending" if not ReviewRevisionStore.ready_edits(review).is_empty() else "needs_rework"
			return "candidate"
	return "attempted"


## {"states": {source_id: state}, "counts": {state: n}, "total": n}
static func snapshot() -> Dictionary:
	var drafts := load_drafts()
	var cleared := ReviewRevisionStore.load_cleared()
	var states := {}
	var counts := {"promoted": 0, "candidate": 0, "edits_pending": 0, "needs_rework": 0, "set_aside": 0, "attempted": 0, "cleared": 0, "new": 0}
	var rejections := claude_rejections()
	var catalog := load_catalog()
	for source in catalog:
		var source_id := String(source.get("source_id", ""))
		var state := source_state(source, drafts.get(source_id, {}), cleared, rejections)
		states[source_id] = state
		counts[state] += 1
	return {"states": states, "counts": counts, "total": catalog.size()}


## {source_id: number of Claude rejections of revisions traced by the current tracer}.
## Rejections by rule (stretches) and by the owner don't count.
static func claude_rejections() -> Dictionary:
	var counts := {}
	for revision in ReviewRevisionStore.list_revisions():
		if revision.get("candidate_trace_report", {}).get("provenance", {}).get("tracer", "") != CURRENT_TRACER:
			continue
		var vote: Dictionary = ReviewRevisionStore.load_review(String(revision.get("revision_sha256", ""))).get("votes", {}).get(ReviewRevisionStore.MODEL_MEMBER, {})
		if vote.get("decision", "") == "reject" and vote.get("provider_metadata", {}).get("provider", "") != "bodysim_rule":
			var source_id := String(revision.get("source_id", ""))
			counts[source_id] = int(counts.get(source_id, 0)) + 1
	return counts


## The three layers both auto-mode modals draw.
static func layers(snap: Dictionary) -> Dictionary:
	var counts: Dictionary = snap.get("counts", {})
	var done := int(counts.get("promoted", 0))
	var candidate := int(counts.get("candidate", 0)) + int(counts.get("edits_pending", 0))   # both wait on the council
	return {"done": done, "candidate": candidate, "remaining": int(snap.get("total", 0)) - done - candidate}


## Studio auto queue, from the given sources (the Studio passes the ones its
## search currently shows): exercises the council sent back first (their
## feedback goes into the request), then never-authored ones in catalog order.
static func studio_queue(sources: Array, skip_stretches := false) -> Array:
	var states: Dictionary = snapshot()["states"]
	var rework: Array = []
	var fresh: Array = []
	for source in sources:
		var state := String(states.get(String(source.get("source_id", "")), "new"))
		# The council rejects stretches by rule, so re-authoring one never helps.
		if is_stretch(source) and (skip_stretches or state == "needs_rework"):
			continue
		match state:
			"needs_rework": rework.append(source)
			"new": fresh.append(source)
	return rework + fresh


# ── Stretches ───────────────────────────────────────────────────────────────
# BodySim models exercises: joint actions that move a load, plus the muscles
# that stabilize it. A stretch lengthens muscles instead, so any profile the
# tracer produces for one is meaningless. The council rejects them by rule,
# without asking Claude.

const STRETCH_RULE := "no_stretches"
const STRETCH_SUMMARY := "Stretches can't be represented: BodySim models muscles moving or holding a load, and a stretch lengthens them instead. Rejected by rule without a model review."


## The catalog's own category (free-exercise-db "stretching") marks stretches;
## most of them don't have "stretch" in the name.
static func is_stretch(source: Dictionary) -> bool:
	return String(source.get("category", "")).strip_edges().to_lower() == "stretching"


## The council's model-member vote for a stretch: a reject from the rule.
static func stretch_rejection_vote() -> Dictionary:
	return {
		"decision": "reject",
		"summary": STRETCH_SUMMARY,
		"blocking_findings": [{"field_path": "source.category", "finding": "The source exercise is a stretch.",
			"suggested_correction": "None; skip stretches when authoring."}],
		"non_blocking_findings": [],
		"confidence": "high",
		"provider_metadata": {"provider": "bodysim_rule", "rule": STRETCH_RULE, "model": "rule: no stretches"},
		"recorded_at_unix": Time.get_unix_time_from_system(),
	}


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


# ── Credits and spending ────────────────────────────────────────────────────
# Every Claude request the Studio or the Council makes (manual or auto) is
# appended to a ledger with its usage and estimated cost (ClaudeProvider does
# this). The owner enters their credit balance from the Claude Console now and
# then; what's left is estimated as that balance minus the ledger's spend since
# it was entered. Estimates use PRICES; re-entering the balance re-syncs it.
# BODYSIM_SPEND_LEDGER and BODYSIM_CREDITS_FILE redirect both files (the
# sandboxed checks use them so tests never touch the owner's real records).

const LEDGER_DEFAULT := "user://claude_spend.jsonl"
const CREDITS_DEFAULT := "user://bodysim_credits.cfg"
## Used for an estimate before there's any history for a task and model.
const DEFAULT_USAGE := {
	"author": {"input_tokens": 3000, "output_tokens": 5000, "cache_read_input_tokens": 17000, "cache_creation_input_tokens": 0},
	"review": {"input_tokens": 6000, "output_tokens": 3000, "cache_read_input_tokens": 17000, "cache_creation_input_tokens": 0},
}


static func ledger_path() -> String:
	var override := OS.get_environment("BODYSIM_SPEND_LEDGER")
	return override if not override.is_empty() else LEDGER_DEFAULT


static func credits_path() -> String:
	var override := OS.get_environment("BODYSIM_CREDITS_FILE")
	return override if not override.is_empty() else CREDITS_DEFAULT


## Appends one finished request to the ledger. Requests that failed before
## any usage was billed have no usage and aren't recorded.
static func record_spend(task: String, model: String, usage: Dictionary) -> void:
	if usage.is_empty() or total_tokens(usage) == 0:
		return
	var path := ledger_path()
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify({"t": Time.get_unix_time_from_system(), "task": task, "model": model,
		"usage": usage, "cost_usd": estimate_cost(model, usage)}))


static func read_ledger() -> Array:
	var entries: Array = []
	var file := FileAccess.open(ledger_path(), FileAccess.READ)
	if file == null:
		return entries
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty(): continue
		var entry = JSON.parse_string(line)
		if entry is Dictionary: entries.append(entry)
	return entries


## {"balance": USD or -1 when never set, "set_at": unix time}
static func credits() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(credits_path()) != OK:
		return {"balance": -1.0, "set_at": 0.0}
	return {"balance": float(cfg.get_value("credits", "balance_usd", -1.0)), "set_at": float(cfg.get_value("credits", "set_at_unix", 0.0))}


static func set_credits(balance_usd: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("credits", "balance_usd", balance_usd)
	cfg.set_value("credits", "set_at_unix", Time.get_unix_time_from_system())
	cfg.save(credits_path())


## {"cost": USD, "requests": n, "unpriced": n} for ledger entries after `since`.
static func spend_since(since: float) -> Dictionary:
	var cost := 0.0
	var requests := 0
	var unpriced := 0
	for entry in read_ledger():
		if float(entry.get("t", 0.0)) <= since: continue
		requests += 1
		var c := float(entry.get("cost_usd", -1.0))
		if c < 0.0: unpriced += 1
		else: cost += c
	return {"cost": cost, "requests": requests, "unpriced": unpriced}


## Estimated USD left, or -1 when no balance has been entered.
static func credits_left() -> float:
	var c := credits()
	if float(c["balance"]) < 0.0:
		return -1.0
	return float(c["balance"]) - float(spend_since(float(c["set_at"]))["cost"])


## Typical USD for one request of `task` ("author" or "review") on `model`:
## the mean of the last 20 matching ledger entries; before there are any,
## the usage recorded in drafts and reviews on disk; else DEFAULT_USAGE.
## -1 when the model has no known price.
static func typical_cost(task: String, model: String) -> float:
	if not PRICES.has(model):
		return -1.0
	var costs: Array[float] = []
	for entry in read_ledger():
		if entry.get("task") == task and entry.get("model") == model and float(entry.get("cost_usd", -1.0)) >= 0.0:
			costs.append(float(entry["cost_usd"]))
	if costs.is_empty():
		for usage in _recorded_usage(task):
			costs.append(estimate_cost(model, usage))
	if costs.is_empty():
		return estimate_cost(model, DEFAULT_USAGE.get(task, DEFAULT_USAGE["author"]))
	costs = costs.slice(maxi(0, costs.size() - 20))
	var sum := 0.0
	for c in costs: sum += c
	return sum / costs.size()


## Usage recorded on disk before the ledger existed: authoring usage in drafts,
## Claude review usage in council reviews.
static func _recorded_usage(task: String) -> Array:
	var found: Array = []
	if task == "author":
		for draft in load_drafts().values():
			var usage: Dictionary = draft.get("provider_metadata", {}).get("usage", {})
			if total_tokens(usage) > 0: found.append(usage)
	else:
		for revision in ReviewRevisionStore.list_revisions():
			var vote: Dictionary = ReviewRevisionStore.load_review(String(revision.get("revision_sha256", ""))).get("votes", {}).get(ReviewRevisionStore.MODEL_MEMBER, {})
			var usage: Dictionary = vote.get("provider_metadata", {}).get("usage", {})
			if total_tokens(usage) > 0: found.append(usage)
	return found
