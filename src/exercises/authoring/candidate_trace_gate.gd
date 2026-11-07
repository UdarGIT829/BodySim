class_name CandidateTraceGate
extends Node

const BRIDGE_SCRIPT := "res://tools/exercises/run_candidate_gate.py"

@export var python_executable := "python3"


func evaluate(definition: Dictionary) -> Dictionary:
	var nonce := "%d_%d" % [Time.get_ticks_msec(), get_instance_id()]
	var input_path := "user://candidate_gate_%s_input.json" % nonce
	var output_path := "user://candidate_gate_%s_output.json" % nonce
	var input_file := FileAccess.open(input_path, FileAccess.WRITE)
	if input_file == null:
		return failure("Could not create the isolated candidate-gate input file.")
	input_file.store_string(JSON.stringify(definition, "  "))
	input_file.close()

	var console_output: Array = []
	var exit_code := OS.execute(
		python_executable,
		PackedStringArray([
			ProjectSettings.globalize_path(BRIDGE_SCRIPT),
			"--input", ProjectSettings.globalize_path(input_path),
			"--output", ProjectSettings.globalize_path(output_path),
		]),
		console_output,
		true
	)
	var result: Dictionary = {}
	var output_file := FileAccess.open(output_path, FileAccess.READ)
	if output_file != null:
		var parsed = JSON.parse_string(output_file.get_as_text())
		if parsed is Dictionary:
			result = parsed
	cleanup_temporary_file(input_path)
	cleanup_temporary_file(output_path)

	if result.is_empty():
		return failure("Candidate tracer exited with code %d without a readable report. %s" % [exit_code, " ".join(console_output)])
	if not result.get("ok", false):
		for message in result.get("errors", []):
			push_error("CandidateTraceGate: %s" % message)
	return result


func cleanup_temporary_file(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)


func failure(message: String) -> Dictionary:
	push_error("CandidateTraceGate: %s" % message)
	return {
		"gate_version": "candidate_trace_gate_v3",
		"ok": false,
		"errors": [message],
		"warnings": [],
		"summary": {},
		"profile": {},
	}
