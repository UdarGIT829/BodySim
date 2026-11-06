class_name OpenAIAuthoringProvider
extends Node

signal generation_succeeded(response: Dictionary, metadata: Dictionary)
signal generation_failed(message: String)

const RESPONSES_URL := "https://api.openai.com/v1/responses"

@onready var http_request: HTTPRequest = $HTTPRequest


func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)


func generate(api_key: String, model: String, system_prompt: String, source_context: String, schema: Dictionary, image_data_url: String = "") -> void:
	if api_key.strip_edges().is_empty():
		_fail("Add the internal OpenAI API key on the studio root in the Inspector.")
		return
	if model.strip_edges().is_empty():
		_fail("Choose an OpenAI model that supports Structured Outputs.")
		return
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_fail("An authoring request is already running.")
		return
	var body := build_request_body(model, system_prompt, source_context, schema, image_data_url)
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
	])
	var error := http_request.request(RESPONSES_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if error != OK:
		_fail("Could not start the OpenAI request (error %d)." % error)


func _fail(message: String) -> void:
	push_error("OpenAIAuthoringProvider: %s" % message)
	generation_failed.emit(message)


func build_request_body(model: String, system_prompt: String, source_context: String, schema: Dictionary, image_data_url: String = "") -> Dictionary:
	var content: Array[Dictionary] = [
		{"type": "input_text", "text": source_context},
	]
	if not image_data_url.is_empty():
		content.append({
			"type": "input_image",
			"image_url": image_data_url,
			"detail": "high",
		})
	return {
		"model": model,
		"instructions": system_prompt,
		"input": [{"role": "user", "content": content}],
		"text": {
			"format": {
				"type": "json_schema",
				"name": "bodysim_kinematic_authoring_response",
				"strict": true,
				"schema": schema,
			}
		},
	}


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("The OpenAI request failed before a response was received (result %d)." % result)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("OpenAI returned an unreadable response.")
		return
	if response_code < 200 or response_code >= 300:
		var api_error: Dictionary = parsed.get("error", {})
		_fail("OpenAI error %d: %s" % [response_code, api_error.get("message", "Unknown API error")])
		return
	var extracted := extract_structured_output(parsed)
	if not extracted.get("ok", false):
		_fail(String(extracted.get("error", "The response contained no structured output.")))
		return
	var metadata := {
		"provider": "openai",
		"response_id": parsed.get("id", ""),
		"model": parsed.get("model", ""),
		"usage": parsed.get("usage", {}),
		"status": parsed.get("status", ""),
	}
	generation_succeeded.emit(extracted["value"], metadata)


func extract_structured_output(response: Dictionary) -> Dictionary:
	if response.get("status", "") == "incomplete":
		return {"ok": false, "error": "OpenAI returned an incomplete response."}
	for output_item in response.get("output", []):
		if not output_item is Dictionary:
			continue
		for content_item in output_item.get("content", []):
			if not content_item is Dictionary:
				continue
			if content_item.get("type") == "refusal":
				return {"ok": false, "error": "OpenAI refused this authoring request: %s" % content_item.get("refusal", "")}
			if content_item.get("type") == "output_text":
				var value = JSON.parse_string(String(content_item.get("text", "")))
				if value is Dictionary:
					return {"ok": true, "value": value}
	return {"ok": false, "error": "OpenAI returned no parseable output_text item."}
