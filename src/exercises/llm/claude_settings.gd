class_name ClaudeSettings
extends RefCounted

## Claude model choices and the API-key check shared by the Kinematic
## Definition Studio and the Review Council. The key itself is read by the
## Python bridge (ANTHROPIC_API_KEY, or [anthropic] api_key in the settings
## file below); it is never stored in the project.

const SETTINGS_PATH := "user://bodysim_authoring_settings.cfg"
const DEFAULT_MODEL := "claude-opus-5-5"
const MODEL_PRESETS := [
	{"label": "Claude Opus 5.5 · default", "id": "claude-opus-5-5"},
	{"label": "Claude Sonnet 5.5 · half the price", "id": "claude-sonnet-5-5"},
	{"label": "Claude Haiku 5.5 · cheapest", "id": "claude-haiku-5-5"},
	{"label": "Claude Fable 5.1 · most capable, priciest", "id": "claude-fable-5-1"},
	{"label": "Custom model ID…", "id": "custom"},
]


static func has_api_key() -> bool:
	if not OS.get_environment("ANTHROPIC_API_KEY").strip_edges().is_empty():
		return true
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return false
	return not String(settings.get_value("anthropic", "api_key", "")).strip_edges().is_empty()


static func missing_key_message() -> String:
	return "No Anthropic API key: set ANTHROPIC_API_KEY, or add [anthropic] api_key=\"…\" to %s." % ProjectSettings.globalize_path(SETTINGS_PATH)


static func load_model(setting_key: String) -> String:
	var settings := ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return DEFAULT_MODEL
	var value := String(settings.get_value("anthropic", setting_key, DEFAULT_MODEL)).strip_edges()
	return value if not value.is_empty() else DEFAULT_MODEL


static func save_model(setting_key: String, model: String) -> void:
	if model.strip_edges().is_empty():
		return
	var settings := ConfigFile.new()
	settings.load(SETTINGS_PATH)   # keep the API key and every other setting
	settings.set_value("anthropic", setting_key, model.strip_edges())
	settings.save(SETTINGS_PATH)


## Fills a model OptionButton and returns whether "custom" is selected.
static func fill_model_option(option: OptionButton, current_model: String) -> bool:
	option.clear()
	var selected := MODEL_PRESETS.size() - 1
	for index in MODEL_PRESETS.size():
		option.add_item(String(MODEL_PRESETS[index]["label"]))
		option.set_item_metadata(index, MODEL_PRESETS[index]["id"])
		if MODEL_PRESETS[index]["id"] == current_model:
			selected = index
	option.select(selected)
	return String(option.get_selected_metadata()) == "custom"
