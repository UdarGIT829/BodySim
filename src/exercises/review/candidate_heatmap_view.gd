class_name CandidateHeatmapView
extends SubViewportContainer

@onready var viewport: SubViewport = $Viewport
@onready var body_preview: Node3D = $Viewport/WholeBodyPreview
var pending_profile: Dictionary = {}

func _ready() -> void:
	body_preview.set_embedded_review_mode(true)
	if not pending_profile.is_empty(): body_preview.show_candidate_profile(pending_profile)

func show_profile(profile: Dictionary) -> void:
	pending_profile = profile
	if is_node_ready(): body_preview.show_candidate_profile(profile)
