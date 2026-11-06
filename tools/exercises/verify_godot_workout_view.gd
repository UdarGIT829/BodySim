extends SceneTree

const WorkoutViewControllerScript = preload("res://src/exercises/workout_view_controller.gd")

func _initialize() -> void:
	call_deferred("run_verification")

func run_verification() -> void:
	print("--- Godot WorkoutViewController Heatmap Verification ---")
	var vc = WorkoutViewControllerScript.new()
	var success: bool = vc.load_and_score_workout(
		"res://data/workouts/example_workout.json",
		"res://data/anatomy/structures.json",
		"res://data/exercises/engagement_profiles.json",
		"res://data/exercises/opensim_calibration.json"
	)

	if not success:
		push_error("Failed to load and score workout!")
		quit(1)
		return

	if not vc.score_single_exercise("exercise.ab_wheel_rollout.kneeling"):
		push_error("Failed to score a supported single exercise!")
		quit(1)
		return
	if vc.current_summary["exercises"].size() != 1:
		push_error("Single exercise preview must contain exactly one exercise summary!")
		quit(1)
		return
	if vc.current_summary["exercises"][0]["exercise_id"] != "exercise.ab_wheel_rollout.kneeling":
		push_error("Single exercise preview selected the wrong engagement profile!")
		quit(1)
		return

	# Restore the representative workout for the existing aggregate checks.
	vc.load_and_score_workout()

	print("Workout Summary Session: ", vc.current_summary["session_id"])
	print("Active Muscles: ", vc.current_summary["active_muscles"])

	# Check heat map colors for active muscles vs zero exposure muscles
	var quad_color: Color = vc.get_muscle_color("muscle.rectus_femoris.left")
	# Facial muscles are always an explicit zero in the tracer.
	var zero_color: Color = vc.get_muscle_color("muscle.zygomaticus_major.left")

	print("Rectus Femoris (Squat active) Heatmap Color: ", quad_color)
	print("Zygomaticus Major (Zero exposure) Heatmap Color: ", zero_color)

	# Verify contribution breakdown text
	var details: String = vc.get_muscle_contribution_details("muscle.rectus_femoris.left")
	print("\n--- Muscle Contribution Details ---\n", details)

	if quad_color.a > 0.5 and zero_color.a < 0.3:
		print("\nSUCCESS: Native Godot WorkoutViewController verified!")
		quit(0)
	else:
		push_error("Heatmap color verification failed!")
		quit(1)
