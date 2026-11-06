class_name WorkoutScorer
extends RefCounted

var canonical_muscle_ids: Array[String] = []
var engagement_profiles: Dictionary = {}
var opensim_anchors: Dictionary = {}


func load_data(
	catalog_path: String = "res://data/anatomy/structures.json",
	profiles_path: String = "res://data/exercises/engagement_profiles.json",
	opensim_path: String = "res://data/exercises/opensim_calibration.json"
) -> bool:
	canonical_muscle_ids.clear()
	engagement_profiles.clear()
	opensim_anchors.clear()

	# 1. Load catalog
	var cat_file := FileAccess.open(catalog_path, FileAccess.READ)
	if cat_file == null:
		push_error("WorkoutScorer: Failed to open catalog %s" % catalog_path)
		return false

	var cat_parsed = JSON.parse_string(cat_file.get_as_text())
	if not cat_parsed is Dictionary or not cat_parsed.has("structures"):
		push_error("WorkoutScorer: Invalid catalog format %s" % catalog_path)
		return false

	for record in cat_parsed["structures"]:
		var id_str := String(record.get("id", ""))
		if id_str.begins_with("muscle."):
			canonical_muscle_ids.append(id_str)

	if canonical_muscle_ids.size() != 466:
		push_error("WorkoutScorer: Expected 466 muscles, found %d" % canonical_muscle_ids.size())
		return false

	# 2. Load profiles
	var prof_file := FileAccess.open(profiles_path, FileAccess.READ)
	if prof_file != null:
		var prof_parsed = JSON.parse_string(prof_file.get_as_text())
		if prof_parsed is Dictionary and prof_parsed.has("profiles"):
			engagement_profiles = prof_parsed["profiles"]

	# 3. Load OpenSim anchors
	var opensim_file := FileAccess.open(opensim_path, FileAccess.READ)
	if opensim_file != null:
		var opensim_parsed = JSON.parse_string(opensim_file.get_as_text())
		if opensim_parsed is Array:
			for c in opensim_parsed:
				if c is Dictionary and c.has("exercise_id"):
					opensim_anchors[String(c["exercise_id"])] = c

	return true


func calculate_effort_factor(set_dict: Dictionary) -> float:
	var rep_factor := 1.0
	if set_dict.has("repetitions"):
		rep_factor = float(set_dict["repetitions"])
	elif set_dict.has("duration_seconds"):
		rep_factor = float(set_dict["duration_seconds"]) / 5.0

	var rpe_factor := 1.0
	if set_dict.has("rpe"):
		rpe_factor = 1.0 + (float(set_dict["rpe"]) - 8.0) * 0.1
		rpe_factor = clampf(rpe_factor, 0.5, 1.5)

	return maxf(0.1, rep_factor * rpe_factor)


func score_workout(workout_dict: Dictionary) -> Dictionary:
	var session_id := String(workout_dict.get("session_id", "unknown_session"))
	var performed_exercises: Array = workout_dict.get("exercises", [])

	var muscle_summary: Dictionary = {}
	for m_id in canonical_muscle_ids:
		muscle_summary[m_id] = {
			"muscle_id": m_id,
			"raw_exposure": 0.0,
			"opensim_estimated_force_n": 0.0,
			"contributions": [],
			"normalized_emphasis": 0.0
		}

	var exercise_summaries: Array = []

	for ex_entry in performed_exercises:
		if not ex_entry is Dictionary:
			continue
		var ex_id := String(ex_entry.get("exercise_id", ""))
		var sets: Array = ex_entry.get("sets", [])

		var total_effort := 0.0
		for s in sets:
			if s is Dictionary:
				total_effort += calculate_effort_factor(s)

		var prof_info: Dictionary = engagement_profiles.get(ex_id, {})
		var profile_muscles: Array = prof_info.get("muscles", [])
		var profile_map: Dictionary = {}
		for m in profile_muscles:
			if m is Dictionary and m.has("muscle_id"):
				profile_map[String(m["muscle_id"])] = m

		var anchor: Dictionary = opensim_anchors.get(ex_id, {})
		var primary_force_n: float = float(anchor.get("opensim_force_n", 0.0))

		var ex_mapped_muscles := 0

		for m_id in canonical_muscle_ids:
			var m_info: Dictionary = profile_map.get(m_id, {"coefficient": 0.0, "role": "none"})
			var coeff: float = float(m_info.get("coefficient", 0.0))
			var role: String = String(m_info.get("role", "none"))

			if coeff > 0.0:
				ex_mapped_muscles += 1
				var raw_exp := coeff * total_effort
				muscle_summary[m_id]["raw_exposure"] += raw_exp

				var est_force := coeff * primary_force_n
				muscle_summary[m_id]["opensim_estimated_force_n"] += est_force

				var contrib := {
					"exercise_id": ex_id,
					"role": role,
					"coefficient": coeff,
					"raw_exposure": raw_exp,
					"opensim_estimated_force_n": est_force
				}
				muscle_summary[m_id]["contributions"].append(contrib)

		exercise_summaries.append({
			"exercise_id": ex_id,
			"set_count": sets.size(),
			"total_effort_factor": total_effort,
			"mapped_muscles": ex_mapped_muscles,
			"opensim_calibrated": not anchor.is_empty()
		})

	var max_raw := 0.0
	for m_id in canonical_muscle_ids:
		var raw: float = muscle_summary[m_id]["raw_exposure"]
		if raw > max_raw:
			max_raw = raw

	var mapped_count := 0
	for m_id in canonical_muscle_ids:
		var raw: float = muscle_summary[m_id]["raw_exposure"]
		if raw > 0.0:
			mapped_count += 1
			muscle_summary[m_id]["normalized_emphasis"] = (raw / max_raw) * 100.0 if max_raw > 0.0 else 0.0

	return {
		"session_id": session_id,
		"total_canonical_muscles": 466,
		"active_muscles": mapped_count,
		"zero_exposure_muscles": 466 - mapped_count,
		"max_raw_exposure": max_raw,
		"exercises": exercise_summaries,
		"muscles": muscle_summary
	}
