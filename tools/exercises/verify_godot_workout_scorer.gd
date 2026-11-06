extends SceneTree

const WorkoutScorerScript = preload("res://src/exercises/workout_scorer.gd")

func _initialize() -> void:
	call_deferred("run_verification")

func run_verification() -> void:
	print("--- Godot WorkoutScorer Verification ---")
	var scorer = WorkoutScorerScript.new()
	var loaded: bool = scorer.load_data(
		"res://data/anatomy/structures.json",
		"res://data/exercises/engagement_profiles.json",
		"res://data/exercises/opensim_calibration.json"
	)

	if not loaded:
		push_error("Godot WorkoutScorer: Failed to load data!")
		quit(1)
		return

	var workout_file := FileAccess.open("res://data/workouts/example_workout.json", FileAccess.READ)
	if workout_file == null:
		push_error("Godot WorkoutScorer: Failed to open workout file!")
		quit(1)
		return

	var workout_dict: Dictionary = JSON.parse_string(workout_file.get_as_text())
	var summary: Dictionary = scorer.score_workout(workout_dict)

	print("Session ID: ", summary["session_id"])
	print("Total Canonical Muscles: ", summary["total_canonical_muscles"])
	print("Active Muscles: ", summary["active_muscles"])
	print("Zero Exposure Muscles: ", summary["zero_exposure_muscles"])
	print("Max Raw Exposure: ", summary["max_raw_exposure"])

	if summary["total_canonical_muscles"] == 466 and summary["active_muscles"] > 0:
		print("SUCCESS: Native Godot WorkoutScorer verified!")
		quit(0)
	else:
		push_error("Verification failed!")
		quit(1)
