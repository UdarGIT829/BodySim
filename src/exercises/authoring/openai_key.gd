class_name OpenAIKey
extends RefCounted

## Resolves the OpenAI API key for the authoring studio and review council
## without ever storing it in the project (which is public on GitHub).
## Order: the Inspector field (if set for a one-off session), then the
## OPENAI_API_KEY environment variable, then [openai] api_key in
## user://bodysim_authoring_settings.cfg (outside the repository).

const SETTINGS_PATH := "user://bodysim_authoring_settings.cfg"


static func resolve(inspector_value: String) -> String:
	if not inspector_value.strip_edges().is_empty():
		return inspector_value.strip_edges()
	var from_env := OS.get_environment("OPENAI_API_KEY").strip_edges()
	if not from_env.is_empty():
		return from_env
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		return String(settings.get_value("openai", "api_key", "")).strip_edges()
	return ""
