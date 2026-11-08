class_name AutoRunModal
extends Window

## Auto mode, shared by the Kinematic Definition Studio and the Review Council.
## The page passes its model and four callables to open_for():
##   queue.call() -> Array               items to work through, in order
##   step.call(item) -> Dictionary       (a coroutine) processes one item:
##       {"outcome": String, "message": String, "usage": Dictionary,
##        "error": String, "error_kind": String}
##   label.call(item) -> String          name shown while it runs
##   snapshot.call() -> Dictionary       AutoPipeline.layers()-shaped counts
## Spending is in estimated dollars: an optional limit for this run, and the
## owner's Claude credit balance (entered here, from the Claude Console),
## minus everything the Studio and the Council have spent since (the ledger
## in AutoPipeline). Before each exercise the run checks the typical cost of
## the next one against both. The run ends as done, stopped, spend limit
## reached, out of credits (estimated, or the API said so), or stopped on an
## error that retrying won't fix.

signal run_finished(state: String)

const COLORS := {"done": Color("68dda5"), "candidate": Color("e3aa57"), "remaining": Color("3a4553")}
const STATE_TEXT := {
	"ready": "Ready", "running": "Running", "stopping": "Stopping after the current exercise…",
	"done": "Done", "stopped": "Stopped", "spend_limit": "Spend limit for this run reached",
	"out_of_credits": "Out of credits", "error": "Stopped on an error",
}
const MAX_RETRIES := 3
const MAX_FAILURES_IN_A_ROW := 5
const LOG_DIR := "user://auto_runs"

@onready var model_label: Label = %ModelLabel
@onready var description_label: Label = %DescriptionLabel
@onready var run_limit_spin: SpinBox = %RunLimitSpin
@onready var max_items_spin: SpinBox = %MaxItemsSpin
@onready var credits_spin: SpinBox = %CreditsSpin
@onready var credits_bar: ProgressBar = %CreditsBar
@onready var credits_label: Label = %CreditsLabel
@onready var spend_label: Label = %SpendLabel
@onready var pipeline_bar: LayeredProgressBar = %PipelineBar
@onready var legend_label: RichTextLabel = %LegendLabel
@onready var run_label: Label = %RunLabel
@onready var current_label: Label = %CurrentLabel
@onready var state_label: Label = %StateLabel
@onready var log_text: RichTextLabel = %LogText
@onready var start_button: Button = %StartButton
@onready var stop_button: Button = %StopButton
@onready var close_button: Button = %CloseButton
@onready var option_check: CheckBox = %OptionCheck

var config: Dictionary = {}
var model_id := ""
var state := "ready"
var stop_requested := false
var usage := {}
var outcomes := {}
var processed := 0
var token_using_items := 0
var log_path := ""
## Tests turn these off so a verifier run doesn't touch user settings or logs.
var persist_settings := true
## Seconds to wait before retry n (1-based). Tests shorten this.
var retry_delay := func(attempt: int) -> float: return 60.0 * attempt


func _ready() -> void:
	close_requested.connect(_on_close_requested)
	start_button.pressed.connect(start)
	stop_button.pressed.connect(request_stop)
	close_button.pressed.connect(_on_close_requested)
	run_limit_spin.value = float(AutoPipeline.load_setting("run_limit_usd", 2.0))
	max_items_spin.value = int(AutoPipeline.load_setting("max_items", 0))
	run_limit_spin.value_changed.connect(func(_v: float) -> void: refresh_spend())
	%SetCreditsButton.pressed.connect(set_balance)
	option_check.toggled.connect(_on_option_toggled)


## config keys: title, model, completed_label, description, scope (what the
## queue covers, e.g. the active search), queue, step, label, snapshot,
## task ("author" or "review": prices the next exercise from history before
## this run has any of its own; or estimate_usd to fix it), and option:
## {"label", "setting", "default"} for a remembered checkbox that the page's
## queue reads through option_enabled().
func open_for(new_config: Dictionary) -> void:
	if state in ["running", "stopping"]:
		popup_centered()
		return
	config = new_config
	model_id = String(config.get("model", ""))
	title = String(config.get("title", "Auto mode"))
	model_label.text = "Model: %s" % model_id
	var scope := String(config.get("scope", ""))
	description_label.text = String(config.get("description", "")) + ("\n" + scope if not scope.is_empty() else "")
	var option: Dictionary = config.get("option", {})
	option_check.visible = not option.is_empty()
	if option_check.visible:
		option_check.text = String(option.get("label", ""))
		var enabled: bool = option.get("default", true)
		if persist_settings:
			enabled = bool(AutoPipeline.load_setting(String(option["setting"]), enabled))
		option_check.set_pressed_no_signal(enabled)
	reset_run()
	set_state("ready")
	refresh_credits(true)
	refresh_pipeline()
	refresh_queued()
	popup_centered(Vector2i(820, 720))


func option_enabled() -> bool:
	return option_check.visible and option_check.button_pressed


func _on_option_toggled(enabled: bool) -> void:
	var option: Dictionary = config.get("option", {})
	if persist_settings and not option.is_empty():
		AutoPipeline.save_setting(String(option["setting"]), enabled)
	if state == "ready":
		refresh_queued()


func refresh_queued() -> void:
	var queued: int = config["queue"].call().size()
	run_label.text = "Ready: %d exercise(s) waiting for this step." % queued if queued > 0 else "Nothing is waiting for this step right now."


func reset_run() -> void:
	usage = {"input_tokens": 0, "output_tokens": 0, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}
	outcomes = {}
	processed = 0
	token_using_items = 0
	log_text.clear()
	current_label.text = ""
	refresh_spend()
	refresh_run_label()


func start() -> void:
	if state in ["running", "stopping"]:
		return
	if persist_settings:
		AutoPipeline.save_setting("run_limit_usd", float(run_limit_spin.value))
		AutoPipeline.save_setting("max_items", int(max_items_spin.value))
	reset_run()
	stop_requested = false
	open_log()
	set_state("running")
	var queue: Array = config["queue"].call()
	var left := AutoPipeline.credits_left()
	log_line("Started with %s. %d exercise(s) queued; spend limit %s; credits %s; a typical exercise ≈ %s." % [model_id, queue.size(),
		money(run_limit_spin.value) if run_limit_spin.value > 0 else "none", money(left) + " left (estimated)" if left >= 0.0 else "not set",
		money(next_cost())])
	if next_cost() < 0.0:
		log_line("No price is known for %s, so spending can't be estimated; only the API's own out-of-credits error will stop the run." % model_id, true)
	var finished := false
	var failures_in_a_row := 0
	for item in queue:
		if stop_requested:
			finish("stopped", "Stopped by you after %d exercise(s)." % processed)
			finished = true
			break
		if max_items_spin.value > 0 and processed >= int(max_items_spin.value):
			finish("done", "Reached the limit of %d exercise(s)." % int(max_items_spin.value))
			finished = true
			break
		var stop := spending_stop()
		if not stop.is_empty():
			finish(stop[0], stop[1])
			finished = true
			break
		var name := String(config["label"].call(item))
		current_label.text = "Now: %s" % name
		var result: Dictionary = await run_step(item, name)
		var kind := String(result.get("error_kind", ""))
		if kind == "credits":
			finish("out_of_credits", "%s: %s" % [name, result.get("error", "")])
			finished = true
			break
		if kind in AutoPipeline.FATAL_ERRORS:
			finish("error", "%s: %s" % [name, result.get("error", "")])
			finished = true
			break
		processed += 1
		var outcome := String(result.get("outcome", "failed"))
		outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
		var detail := String(result.get("message", result.get("error", "")))
		log_line("%s — %s%s" % [name, outcome.replace("_", " "), (": " + detail) if not detail.is_empty() else ""], outcome == "failed")
		failures_in_a_row = failures_in_a_row + 1 if outcome == "failed" else 0
		refresh_run_label()
		refresh_pipeline()
		if failures_in_a_row >= MAX_FAILURES_IN_A_ROW:
			finish("error", "%d failures in a row; stopping so nothing is wasted. Last error: %s" % [failures_in_a_row, result.get("error", "")])
			finished = true
			break
	if not finished:
		finish("done", "Everything queued has been processed." if not queue.is_empty() else "Nothing to do: the queue is empty.")


## One item, retrying rate limits, overload and network errors with a wait.
func run_step(item, name: String) -> Dictionary:
	var attempt := 0
	while true:
		var result: Dictionary = await config["step"].call(item)
		add_usage(result.get("usage", {}))
		if String(result.get("error_kind", "")) not in AutoPipeline.RETRYABLE_ERRORS or attempt >= MAX_RETRIES or stop_requested:
			return result
		attempt += 1
		var delay: float = retry_delay.call(attempt)
		log_line("%s — %s; retrying in %d s (attempt %d of %d)." % [name, result.get("error", ""), int(delay), attempt + 1, MAX_RETRIES + 1])
		current_label.text = "Now: %s · waiting %d s to retry" % [name, int(delay)]
		var waited := 0.0
		while waited < delay and not stop_requested:
			await get_tree().create_timer(min(1.0, delay - waited)).timeout
			waited += 1.0
	return {}


func request_stop() -> void:
	if state == "running":
		stop_requested = true
		set_state("stopping")


func finish(final_state: String, message: String) -> void:
	set_state(final_state)
	current_label.text = message
	log_line("%s. %s" % [STATE_TEXT[final_state], message], final_state in ["error", "out_of_credits"])
	var left := AutoPipeline.credits_left()
	log_line("This run: ≈ %s, %s tokens.%s Log: %s" % [money(run_cost()), group(tokens_used()),
		(" Credits left ≈ %s." % money(left)) if left >= 0.0 else "", ProjectSettings.globalize_path(log_path)])
	refresh_credits()
	refresh_pipeline()
	run_finished.emit(final_state)


func set_state(new_state: String) -> void:
	state = new_state
	state_label.text = STATE_TEXT.get(new_state, new_state)
	var colors := {"done": Color("68dda5"), "running": Color("a9bdd0"), "stopping": Color("e3aa57"),
		"spend_limit": Color("e3aa57"), "out_of_credits": Color("ff7676"), "error": Color("ff7676")}
	state_label.modulate = colors.get(new_state, Color.WHITE)
	var busy := new_state in ["running", "stopping"]
	start_button.disabled = busy
	start_button.text = "Start auto mode" if new_state == "ready" else "Run again"
	stop_button.disabled = new_state != "running"
	close_button.disabled = busy
	run_limit_spin.editable = not busy
	max_items_spin.editable = not busy
	option_check.disabled = busy


func _on_close_requested() -> void:
	if state in ["running", "stopping"]:
		current_label.text = "Auto mode is running. Stop it first; it finishes the current exercise, then stops."
		return
	hide()


func add_usage(new_usage: Dictionary) -> void:
	if new_usage.is_empty():
		return
	for key in usage:
		usage[key] = int(usage[key]) + int(new_usage.get(key, 0))
	token_using_items += 1
	refresh_spend()
	refresh_credits()


func tokens_used() -> int:
	return AutoPipeline.total_tokens(usage)


## Estimated dollars this run has spent.
func run_cost() -> float:
	return maxf(0.0, AutoPipeline.estimate_cost(model_id, usage))


## Typical dollars for the next exercise: this run's average so far, else the
## page's history-based estimate (-1 when the model has no known price).
func next_cost() -> float:
	if AutoPipeline.estimate_cost(model_id, usage) < 0.0:
		return -1.0
	if token_using_items > 0:
		return run_cost() / token_using_items
	if config.has("estimate_usd"):
		return float(config["estimate_usd"])
	return AutoPipeline.typical_cost(String(config.get("task", "author")), model_id)


## [state, message] if the next exercise would go past the run's spend limit
## or the estimated credits, else [].
func spending_stop() -> Array:
	var next := next_cost()
	if next < 0.0:
		return []
	if run_limit_spin.value > 0 and run_cost() + next > run_limit_spin.value:
		return ["spend_limit", "This run has spent ≈ %s of its %s limit; the next exercise typically costs ≈ %s." % [money(run_cost()), money(run_limit_spin.value), money(next)]]
	var left := AutoPipeline.credits_left()
	if left >= 0.0 and left < next:
		return ["out_of_credits", "Estimated credits left (≈ %s) won't cover the next exercise (≈ %s). If you've added credits, set your balance again." % [money(left), money(next)]]
	return []


func set_balance() -> void:
	AutoPipeline.set_credits(float(credits_spin.value))
	log_line("Balance set to %s." % money(credits_spin.value))
	refresh_credits()


## The credits bar: estimated balance left out of the balance last entered.
## `fill_input` puts the estimate into the box when the modal opens.
func refresh_credits(fill_input := false) -> void:
	var c := AutoPipeline.credits()
	var balance := float(c["balance"])
	if balance < 0.0:
		credits_bar.max_value = 1.0
		credits_bar.value = 0.0
		credits_label.text = "Enter your current balance from the Claude Console and press Set balance. BodySim then subtracts its own estimated spending (every Studio and Council request, manual or auto) until you set it again."
		return
	var spent := AutoPipeline.spend_since(float(c["set_at"]))
	var left := balance - float(spent["cost"])
	credits_bar.max_value = maxf(balance, 0.01)
	credits_bar.value = clampf(left, 0.0, balance)
	var local_offset := int(Time.get_time_zone_from_system().get("bias", 0)) * 60   # minutes east of UTC
	var when := Time.get_datetime_string_from_unix_time(int(c["set_at"]) + local_offset, true).left(16)
	credits_label.text = "≈ %s left · you set %s on %s · spent since ≈ %s over %d request(s)%s" % [money(left), money(balance), when,
		money(spent["cost"]), spent["requests"], (" (%d with no known price)" % spent["unpriced"]) if spent["unpriced"] > 0 else ""]
	if fill_input:
		credits_spin.set_value_no_signal(snappedf(maxf(left, 0.0), 0.01))


func refresh_spend() -> void:
	var next := next_cost()
	spend_label.text = "This run: ≈ %s of %s · %s tokens (%s cache reads, %s output) · next exercise ≈ %s" % [
		money(run_cost()), money(run_limit_spin.value) if run_limit_spin.value > 0 else "no limit", group(tokens_used()),
		group(int(usage.get("cache_read_input_tokens", 0))), group(int(usage.get("output_tokens", 0))),
		money(next) if next >= 0.0 else "unknown (no price for this model)"]


static func money(value: float) -> String:
	return "$%.2f" % value if absf(value) >= 0.1 or value == 0.0 else "$%.3f" % value


func refresh_pipeline() -> void:
	if config.is_empty():
		return
	var counts: Dictionary = config["snapshot"].call()
	var total := int(counts.get("done", 0)) + int(counts.get("candidate", 0)) + int(counts.get("remaining", 0))
	var bar_layers: Array[Dictionary] = []
	for key in ["done", "candidate", "remaining"]:
		bar_layers.append({"value": int(counts.get(key, 0)), "color": COLORS[key]})
	pipeline_bar.set_layers(bar_layers, total)
	legend_label.text = "[color=#%s]■[/color] %s %d   [color=#%s]■[/color] Has a candidate %d   [color=#%s]■[/color] Remaining %d   of %d exercises" % [
		COLORS["done"].to_html(false), config.get("completed_label", "Completed"), int(counts.get("done", 0)),
		COLORS["candidate"].to_html(false), int(counts.get("candidate", 0)),
		COLORS["remaining"].to_html(false), int(counts.get("remaining", 0)), total]


func refresh_run_label() -> void:
	if outcomes.is_empty():
		run_label.text = "This run: nothing processed yet."
		return
	var parts: Array[String] = []
	for key in outcomes:
		parts.append("%d %s" % [outcomes[key], String(key).replace("_", " ")])
	run_label.text = "This run: %s" % " · ".join(parts)


func open_log() -> void:
	log_path = ""
	if String(config.get("log_name", "")).is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	log_path = "%s/%s_%s.log" % [LOG_DIR, String(config.get("log_name", "auto")), stamp]


func log_line(message: String, is_error := false) -> void:
	var stamp := Time.get_time_string_from_system()
	log_text.append_text("[color=#6f8196]%s[/color]  %s\n" % [stamp, ("[color=#ff7676]%s[/color]" % message) if is_error else message])
	if log_path.is_empty():
		return
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line("%s  %s" % [stamp, message])


static func group(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out
