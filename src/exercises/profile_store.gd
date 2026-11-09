class_name ProfileStore
extends RefCounted

## Loads engagement profiles for the selector and the workout scorer.
##
## The repository and the desktop app use the full file. The web build ships
## a compact copy instead (tools/web/compact_profiles.py, written by
## tools/web/deploy_pages.sh, format bodysim.engagement_profiles.compact.v1):
## the 466 muscle IDs once and, per profile, a zero template plus only the
## entries that differ from it. Both load to the same {exercise_id: profile}
## dictionary, each profile with all 466 muscles in canonical order.

const FULL_PATH := "res://data/exercises/engagement_profiles.json"
const COMPACT_PATH := "res://data/exercises/engagement_profiles.compact.json"
const COMPACT_FORMAT := "bodysim.engagement_profiles.compact.v1"


## {exercise_id: profile}, or {} if neither file can be read. Asking for the
## full file falls back to the compact one when only that is present (web).
static func load_profiles(path: String = FULL_PATH) -> Dictionary:
	if path == FULL_PATH and not FileAccess.file_exists(FULL_PATH) and FileAccess.file_exists(COMPACT_PATH):
		path = COMPACT_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("profiles"):
		return {}
	if parsed.get("format", "") == COMPACT_FORMAT:
		return expand_compact(parsed)
	return parsed["profiles"]


## The inverse of tools/web/compact_profiles.py (which checks the round trip).
static func expand_compact(data: Dictionary) -> Dictionary:
	var ids: Array = data.get("muscle_ids", [])
	var profiles := {}
	for exercise_id in data["profiles"]:
		var rest: Dictionary = data["profiles"][exercise_id]
		var entries: Dictionary = rest.get("entries", {})
		var template: Dictionary = rest.get("zero_template", {})
		var profile := {}
		for key in rest:
			if key != "zero_template" and key != "entries":
				profile[key] = rest[key]
		var muscles: Array = []
		for i in ids.size():
			var entry: Dictionary = {"muscle_id": ids[i]}
			entry.merge(entries.get(str(i), template))
			muscles.append(entry)
		profile["muscles"] = muscles
		profiles[exercise_id] = profile
	return profiles
