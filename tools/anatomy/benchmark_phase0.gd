extends SceneTree

const PREVIEW_SCENE := "res://scenes/anatomy/whole_body_preview.tscn"
const OUTPUT_JSON := "res://reports/phase0_performance.json"
const OUTPUT_MD := "res://reports/phase0_performance.md"
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 180
const BUDGETS := {
	"load_to_ready_ms_max": 3000.0,
	"incremental_static_memory_bytes_max": 1073741824,
	"average_fps_min": 30.0,
	"p95_frame_ms_max": 33.34,
}


func _initialize() -> void:
	call_deferred("run_benchmark")


func run_benchmark() -> void:
	var memory_before := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var load_started := Time.get_ticks_usec()
	var packed := load(PREVIEW_SCENE) as PackedScene
	if packed == null:
		push_error("Unable to load whole-body preview")
		quit(1)
		return
	var preview = packed.instantiate()
	root.add_child(preview)
	for frame in range(5):
		await process_frame
	var load_to_ready_ms := (Time.get_ticks_usec() - load_started) / 1000.0
	var canonical := preview.get_node_or_null("CanonicalBody")
	var canonical_meshes: int = preview.count_meshes(canonical) if canonical != null else 0
	var memory_after := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	for frame in range(WARMUP_FRAMES):
		await process_frame

	var frame_samples: Array[float] = []
	for frame in range(SAMPLE_FRAMES):
		var frame_started := Time.get_ticks_usec()
		await process_frame
		frame_samples.append((Time.get_ticks_usec() - frame_started) / 1000.0)
	frame_samples.sort()
	var total_ms := 0.0
	for sample in frame_samples:
		total_ms += sample
	var average_frame_ms := total_ms / frame_samples.size()
	var average_fps := 1000.0 / average_frame_ms if average_frame_ms > 0.0 else 0.0
	var p95_index := mini(ceili(frame_samples.size() * 0.95) - 1, frame_samples.size() - 1)
	var p95_frame_ms: float = frame_samples[p95_index]

	var measurements := {
		"canonical_meshes": canonical_meshes,
		"load_to_ready_ms": load_to_ready_ms,
		"static_memory_before_bytes": memory_before,
		"static_memory_after_bytes": memory_after,
		"incremental_static_memory_bytes": maxi(memory_after - memory_before, 0),
		"average_frame_ms": average_frame_ms,
		"average_fps": average_fps,
		"p95_frame_ms": p95_frame_ms,
		"sample_frames": SAMPLE_FRAMES,
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"rendered_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"rendered_primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
	}
	var checks := {
		"canonical_coverage": canonical_meshes == 960,
		"load_time": load_to_ready_ms <= BUDGETS["load_to_ready_ms_max"],
		"incremental_memory": measurements["incremental_static_memory_bytes"] <= BUDGETS["incremental_static_memory_bytes_max"],
		"average_fps": average_fps >= BUDGETS["average_fps_min"],
		"p95_frame_time": p95_frame_ms <= BUDGETS["p95_frame_ms_max"],
	}
	var passed := checks.values().all(func(value: bool) -> bool: return value)
	var report := {
		"schema_version": 1,
		"status": "passed" if passed else "failed",
		"measured_at_utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info(),
		"platform": {
			"os": OS.get_name(),
			"processor": OS.get_processor_name(),
			"display_server": DisplayServer.get_name(),
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
			"window_size": {"width": root.size.x, "height": root.size.y},
		},
		"budgets": BUDGETS,
		"measurements": measurements,
		"checks": checks,
	}
	write_report(report)
	print("Phase 0 performance benchmark: %s" % report["status"])
	print(JSON.stringify(measurements))
	quit(0 if passed else 1)


func write_report(report: Dictionary) -> void:
	var json_file := FileAccess.open(OUTPUT_JSON, FileAccess.WRITE)
	json_file.store_string(JSON.stringify(report, "  ", true) + "\n")
	var measurements: Dictionary = report["measurements"]
	var budgets: Dictionary = report["budgets"]
	var lines := [
		"# Phase 0 Performance",
		"",
		"Status: **%s**" % String(report["status"]).to_upper(),
		"",
		"Measured with Godot %s using `%s` / `%s` at %dx%d." % [
			report["engine"]["string"],
			report["platform"]["rendering_method"],
			report["platform"]["rendering_driver"],
			report["platform"]["window_size"]["width"],
			report["platform"]["window_size"]["height"],
		],
		"",
		"| Measurement | Result | Budget |",
		"|---|---:|---:|",
		"| Canonical meshes | %d | 960 |" % measurements["canonical_meshes"],
		"| Load to ready | %.2f ms | ≤ %.0f ms |" % [measurements["load_to_ready_ms"], budgets["load_to_ready_ms_max"]],
		"| Incremental static memory | %d bytes | ≤ %d bytes |" % [measurements["incremental_static_memory_bytes"], budgets["incremental_static_memory_bytes_max"]],
		"| Average frame rate | %.2f FPS | ≥ %.0f FPS |" % [measurements["average_fps"], budgets["average_fps_min"]],
		"| 95th-percentile frame | %.3f ms | ≤ %.2f ms |" % [measurements["p95_frame_ms"], budgets["p95_frame_ms_max"]],
		"| Draw calls | %d | recorded |" % measurements["draw_calls"],
		"| Rendered primitives | %d | recorded |" % measurements["rendered_primitives"],
		"",
		"The benchmark keeps all 960 canonical meshes loaded and visible. Budgets are the",
		"Phase 0 reference-desktop contract; future optimizations may improve these values",
		"but may not remove canonical anatomy.",
		"",
	]
	var md_file := FileAccess.open(OUTPUT_MD, FileAccess.WRITE)
	md_file.store_string("\n".join(lines))
