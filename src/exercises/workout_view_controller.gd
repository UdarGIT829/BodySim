class_name WorkoutViewController
extends RefCounted

const WorkoutScorerScript = preload("res://src/exercises/workout_scorer.gd")

var scorer: RefCounted
var current_summary: Dictionary = {}
var display_mode: String = "normalized" # "normalized" | "raw_exposure" | "opensim_force"

# Color map thresholds for heatmaps
const ZERO_COLOR := Color(0.2, 0.25, 0.35, 0.2)
const LOW_COLOR := Color(0.1, 0.7, 0.9, 0.75)       # Cyan/Blue
const MED_COLOR := Color(1.0, 0.75, 0.1, 0.88)      # Amber/Yellow
const HIGH_COLOR := Color(0.95, 0.15, 0.15, 0.96)    # Vibrant Crimson Red


func _init():
	scorer = WorkoutScorerScript.new()


func load_data(
	catalog_path: String = "res://data/anatomy/structures.json",
	profiles_path: String = "res://data/exercises/engagement_profiles.json",
	opensim_path: String = "res://data/exercises/opensim_calibration.json"
) -> bool:
	if not scorer.load_data(catalog_path, profiles_path, opensim_path):
		push_error("WorkoutViewController: Scorer data load failed.")
		return false
	return true


func load_and_score_workout(
	workout_path: String = "res://data/workouts/example_workout.json",
	catalog_path: String = "res://data/anatomy/structures.json",
	profiles_path: String = "res://data/exercises/engagement_profiles.json",
	opensim_path: String = "res://data/exercises/opensim_calibration.json"
) -> bool:
	if not load_data(catalog_path, profiles_path, opensim_path):
		return false

	var file := FileAccess.open(workout_path, FileAccess.READ)
	if file == null:
		push_error("WorkoutViewController: Unable to open workout file %s" % workout_path)
		return false

	var workout_dict = JSON.parse_string(file.get_as_text())
	if not workout_dict is Dictionary:
		push_error("WorkoutViewController: Invalid workout file %s" % workout_path)
		return false
	current_summary = scorer.score_workout(workout_dict as Dictionary)
	return not current_summary.is_empty()


func score_single_exercise(exercise_id: String) -> bool:
	if not scorer.engagement_profiles.has(exercise_id):
		push_error("WorkoutViewController: No engagement profile for %s" % exercise_id)
		return false
	current_summary = scorer.score_workout({
		"session_id": "exercise_preview:%s" % exercise_id,
		"exercises": [{
			"exercise_id": exercise_id,
			"sets": [{"repetitions": 1, "rpe": 8.0}],
		}],
	})
	return not current_summary.is_empty()


func set_candidate_profile(profile: Dictionary) -> bool:
	var entries: Array = profile.get("muscles", [])
	if entries.size() != 466:
		push_error("WorkoutViewController: Candidate profile must contain all 466 muscles.")
		return false
	var muscles := {}
	var active := 0
	var maximum := 0.0
	for entry in entries:
		if not entry is Dictionary:
			continue
		var coefficient := float(entry.get("coefficient", 0.0))
		if coefficient > 0.0:
			active += 1
		maximum = maxf(maximum, coefficient)
		muscles[String(entry.get("muscle_id", ""))] = {
			"raw_exposure": coefficient,
			"normalized_emphasis": coefficient * 100.0,
			"opensim_estimated_force_n": 0.0,
			"contributions": [{
				"exercise_id": profile.get("exercise_id", "candidate"),
				"role": entry.get("role", "none"),
				"coefficient": coefficient,
				"raw_exposure": coefficient,
			}],
		}
	current_summary = {
		"session_id": "review_candidate:%s" % profile.get("exercise_id", "candidate"),
		"active_muscles": active,
		"max_raw_exposure": maximum,
		"muscles": muscles,
	}
	return true


func get_muscle_color(muscle_id: String) -> Color:
	if current_summary.is_empty() or not current_summary.has("muscles"):
		return ZERO_COLOR

	var muscles_dict: Dictionary = current_summary["muscles"]
	if not muscles_dict.has(muscle_id):
		return ZERO_COLOR

	var m_data: Dictionary = muscles_dict[muscle_id]
	var emphasis: float = float(m_data.get("normalized_emphasis", 0.0))

	if emphasis <= 0.0:
		return ZERO_COLOR
	elif emphasis < 35.0:
		var t := emphasis / 35.0
		return ZERO_COLOR.lerp(LOW_COLOR, t)
	elif emphasis < 70.0:
		var t := (emphasis - 35.0) / 35.0
		return LOW_COLOR.lerp(MED_COLOR, t)
	else:
		var t := (emphasis - 70.0) / 30.0
		return MED_COLOR.lerp(HIGH_COLOR, t)


func apply_heatmap_to_scene(canonical_root: Node3D, registry: RefCounted) -> void:
	if canonical_root == null or registry == null:
		return

	var muscles_dict: Dictionary = current_summary.get("muscles", {})

	for muscle_id in scorer.canonical_muscle_ids:
		var mesh_node: MeshInstance3D = registry.get_structure_node(muscle_id)
		if mesh_node != null:
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.albedo_color = get_muscle_color(muscle_id)
			mesh_node.material_override = mat


func get_muscle_contribution_details(muscle_id: String) -> String:
	if current_summary.is_empty() or not current_summary.has("muscles"):
		return "No workout session loaded."

	var muscles_dict: Dictionary = current_summary["muscles"]
	if not muscles_dict.has(muscle_id):
		return "Muscle ID not found in current workout summary."

	var m_data: Dictionary = muscles_dict[muscle_id]
	var raw_exp: float = float(m_data.get("raw_exposure", 0.0))
	var emphasis: float = float(m_data.get("normalized_emphasis", 0.0))
	var force_n: float = float(m_data.get("opensim_estimated_force_n", 0.0))
	var contribs: Array = m_data.get("contributions", [])

	if raw_exp <= 0.0:
		return "Muscle: %s\nStatus: Zero Exposure in this workout." % muscle_id

	var lines: Array[String] = [
		"Muscle: %s" % muscle_id,
		"Workout Emphasis: %.1f%%  (Raw Exposure: %.2f)" % [emphasis, raw_exp],
		"OpenSim Estimated Force: %.1f N" % force_n if force_n > 0 else "OpenSim Estimated Force: N/A",
		"Contributing Exercises (%d):" % contribs.size()
	]

	for c in contribs:
		if c is Dictionary:
			lines.append("  • %s [%s] - coeff: %.2f, exp: %.2f" % [
				c.get("exercise_id", ""),
				c.get("role", ""),
				float(c.get("coefficient", 0.0)),
				float(c.get("raw_exposure", 0.0))
			])

	return "\n".join(lines)
