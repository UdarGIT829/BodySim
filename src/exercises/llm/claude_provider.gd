class_name ClaudeProvider
extends Node

## Runs Claude requests through tools/exercises/run_claude.py on a worker
## thread so the editor UI stays responsive. Used by the Kinematic Definition
## Studio (generate) and the Review Council (review).

signal generation_succeeded(response: Dictionary, metadata: Dictionary)
signal generation_failed(message: String)
signal review_succeeded(response: Dictionary, metadata: Dictionary)
signal review_failed(message: String)

const BRIDGE_SCRIPT := "res://tools/exercises/run_claude.py"

@export var python_executable := "python3"
@export var effort := "high"

var _thread: Thread = null


func is_busy() -> bool:
	return _thread != null


func generate(model: String, source_context: String, image_data_url := "") -> void:
	_start("author", build_request("author", model, {"context": source_context, "image_data_url": image_data_url}))


func review(model: String, revision: Dictionary, review_context: String, image_data_url := "") -> void:
	_start("review", build_request("review", model, {"revision": revision, "review_context": review_context, "image_data_url": image_data_url}))


func build_request(task: String, model: String, fields: Dictionary) -> Dictionary:
	var request := {
		"task": task,
		"model": model.strip_edges(),
		"effort": effort,
		"settings_path": ProjectSettings.globalize_path(ClaudeSettings.SETTINGS_PATH),
	}
	request.merge(fields)
	return request


func _start(task: String, request: Dictionary) -> void:
	if is_busy():
		_finish.call_deferred(task, {"ok": false, "error": "A Claude request is already running."})
		return
	if String(request.get("model", "")).is_empty():
		_finish.call_deferred(task, {"ok": false, "error": "Choose a Claude model first."})
		return
	_thread = Thread.new()
	_thread.start(_run.bind(task, request))


## Worker thread: file-based handoff to the Python bridge.
func _run(task: String, request: Dictionary) -> void:
	var nonce := "%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	var input_path := ProjectSettings.globalize_path("user://claude_%s_request.json" % nonce)
	var output_path := ProjectSettings.globalize_path("user://claude_%s_response.json" % nonce)
	var result := {}
	var file := FileAccess.open(input_path, FileAccess.WRITE)
	if file == null:
		result = {"ok": false, "error": "Could not write the Claude request file."}
	else:
		file.store_string(JSON.stringify(request))
		file.close()
		var console: Array = []
		var exit_code := OS.execute(python_executable, PackedStringArray([
			ProjectSettings.globalize_path(BRIDGE_SCRIPT), "--input", input_path, "--output", output_path,
		]), console, true)
		var out := FileAccess.open(output_path, FileAccess.READ)
		if out != null:
			var parsed = JSON.parse_string(out.get_as_text())
			out.close()
			if parsed is Dictionary:
				result = parsed
		if result.is_empty():
			result = {"ok": false, "error": "Claude bridge exited with code %d without a result. %s" % [exit_code, " ".join(console).strip_edges().right(400)]}
	for path in [input_path, output_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_finish.call_deferred(task, result)


func _finish(task: String, result: Dictionary) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	var ok: bool = result.get("ok", false)
	if task == "author":
		if ok: generation_succeeded.emit(result.get("value", {}), result.get("metadata", {}))
		else: generation_failed.emit(String(result.get("error", "Claude request failed.")))
	else:
		if ok: review_succeeded.emit(result.get("value", {}), result.get("metadata", {}))
		else: review_failed.emit(String(result.get("error", "Claude request failed.")))


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
