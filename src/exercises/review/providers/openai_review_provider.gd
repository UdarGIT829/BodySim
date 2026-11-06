class_name OpenAIReviewProvider
extends Node

signal review_succeeded(response: Dictionary, metadata: Dictionary)
signal review_failed(message: String)

const RESPONSES_URL := "https://api.openai.com/v1/responses"
@onready var http_request: HTTPRequest = $HTTPRequest

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)

func review(api_key: String, model: String, system_prompt: String, review_context: String, schema: Dictionary, image_data_url := "") -> void:
	if api_key.strip_edges().is_empty(): return _fail("No OpenAI API key: set OPENAI_API_KEY or [openai] api_key in user://bodysim_authoring_settings.cfg.")
	if model.strip_edges().is_empty(): return _fail("Choose an OpenAI review model.")
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return _fail("A review request is already running.")
	var headers := PackedStringArray(["Authorization: Bearer %s" % api_key, "Content-Type: application/json"])
	var error := http_request.request(RESPONSES_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(build_request_body(model, system_prompt, review_context, schema, image_data_url)))
	if error != OK: _fail("Could not start the OpenAI review request (error %d)." % error)

func build_request_body(model: String, system_prompt: String, review_context: String, schema: Dictionary, image_data_url := "") -> Dictionary:
	var content: Array[Dictionary] = [{"type": "input_text", "text": review_context}]
	if not image_data_url.is_empty(): content.append({"type": "input_image", "image_url": image_data_url, "detail": "high"})
	return {"model": model, "instructions": system_prompt, "input": [{"role": "user", "content": content}], "text": {"format": {"type": "json_schema", "name": "bodysim_kinematic_review_response", "strict": true, "schema": schema}}}

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS: return _fail("The OpenAI review failed before a response was received (result %d)." % result)
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary: return _fail("OpenAI returned an unreadable review response.")
	if response_code < 200 or response_code >= 300:
		return _fail("OpenAI error %d: %s" % [response_code, parsed.get("error", {}).get("message", "Unknown API error")])
	var extracted := extract_structured_output(parsed)
	if not extracted.get("ok", false): return _fail(extracted.get("error", "No structured review output."))
	review_succeeded.emit(extracted["value"], {"provider": "openai", "response_id": parsed.get("id", ""), "model": parsed.get("model", ""), "usage": parsed.get("usage", {}), "status": parsed.get("status", "")})

func extract_structured_output(response: Dictionary) -> Dictionary:
	if response.get("status", "") == "incomplete": return {"ok": false, "error": "OpenAI returned an incomplete review."}
	for item in response.get("output", []):
		for content in item.get("content", []) if item is Dictionary else []:
			if content.get("type") == "refusal": return {"ok": false, "error": "OpenAI refused this review: %s" % content.get("refusal", "")}
			if content.get("type") == "output_text":
				var value = JSON.parse_string(content.get("text", ""))
				if value is Dictionary: return {"ok": true, "value": value}
	return {"ok": false, "error": "OpenAI returned no parseable output_text item."}

func _fail(message: String) -> void:
	push_error("OpenAIReviewProvider: %s" % message)
	review_failed.emit(message)
