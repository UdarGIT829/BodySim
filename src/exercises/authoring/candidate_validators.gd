class_name CandidateValidators
extends RefCounted

const LATERALITIES := ["bilateral", "left", "right", "unilateral"]
const INPUT_MODES := ["repetitions", "duration"]
const CHAIN_TYPES := ["open_chain", "closed_chain"]
## Tracer v3 per-action fields (optional; defaults "primary" and "working") and limbs.
const EMPHASES := ["primary", "assist"]
const SIDES := ["working", "both"]
const LIMBS := ["arm", "leg"]
const MOVEMENT_FAMILIES := ["squat", "hip_hinge", "horizontal_push", "vertical_push", "horizontal_pull", "vertical_pull", "loaded_carry", "elbow_flexion", "elbow_extension", "knee_extension", "knee_flexion", "ankle_plantarflexion", "trunk_flexion"]
const STABILIZATION_DEMANDS := ["ankle_stability", "anterior_shoulder_stability", "anti_extension_hip", "anti_extension_spine", "anti_flexion_spine", "anti_rotation_torso", "elbow_joint_integrity", "elbow_stability", "femoral_head_stabilization", "glenohumeral_stabilization", "grip", "humeral_head_stabilization", "intra_abdominal_pressure", "knee_joint_stability", "lumbar_fascia_tension", "patellar_tracking", "pelvic_alignment", "pelvic_leveling_frontal", "postural_stabilization", "postural_sway_control", "scapular_anchoring", "scapular_retraction_stability", "scapular_stabilization", "shoulder_position_hold", "wrist_stability"]
const JOINT_ACTIONS := {
	"ankle_joint": ["dorsiflexion", "plantarflexion"],
	"cervical_spine": ["extension", "flexion", "lateral_flexion", "rotation"],
	"elbow_joint": ["extension", "flexion"],
	"finger_joints": ["abduction", "adduction", "extension", "flexion"],
	"glenohumeral_joint": ["abduction", "adduction", "extension", "external_rotation", "flexion", "horizontal_abduction", "horizontal_adduction", "internal_rotation"],
	"hip_joint": ["abduction", "adduction", "extension", "external_rotation", "flexion", "internal_rotation"],
	"knee_joint": ["extension", "external_rotation", "flexion", "internal_rotation"],
	"lumbar_spine": ["extension", "flexion", "lateral_flexion", "rotation"],
	"radioulnar_joint": ["pronation", "supination"],
	"scapulothoracic_joint": ["depression", "downward_rotation", "elevation", "protraction", "retraction", "upward_rotation"],
	"subtalar_joint": ["eversion", "inversion"],
	"thumb_joints": ["abduction", "adduction", "extension", "flexion", "opposition"],
	"toe_joints": ["extension", "flexion"],
	"wrist_joint": ["extension", "flexion", "radial_deviation", "ulnar_deviation"],
}


static func validate_authoring_response(response: Dictionary, canonical_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var classification := String(response.get("classification", ""))
	if classification not in ["supported", "ambiguous", "unsupported"]:
		errors.append("classification: must be supported, ambiguous, or unsupported")
	if not response.get("classification_reasons") is Array:
		errors.append("classification_reasons: must be an array")
	if not response.get("assumptions") is Array:
		errors.append("assumptions: must be an array")
	if not response.get("questions_requiring_context") is Array:
		errors.append("questions_requiring_context: must be an array")
	if not response.get("field_confidence") is Dictionary:
		errors.append("field_confidence: must be an object")
	var definition = response.get("proposed_definition")
	if classification != "supported":
		if definition != null:
			errors.append("proposed_definition: must be null unless classification is supported")
		errors.append("classification: %s proposals cannot advance to definition_candidate" % classification)
		return errors
	if not response.get("questions_requiring_context", []).is_empty():
		errors.append("questions_requiring_context: supported definitions cannot have unresolved questions")
	if not definition is Dictionary:
		errors.append("proposed_definition: supported responses require a complete object")
		return errors
	errors.append_array(validate_definition(definition, canonical_ids))
	return errors


static func validate_definition(definition: Dictionary, canonical_ids: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var exercise_id := String(definition.get("id", ""))
	if not exercise_id.begins_with("exercise.") or exercise_id.split(".").size() != 3:
		errors.append("id: use exercise.<movement>.<variant>")
	elif exercise_id != exercise_id.to_lower() or " " in exercise_id or "-" in exercise_id:
		errors.append("id: use lowercase snake-case segments")
	elif canonical_ids.has(exercise_id):
		errors.append("id: already belongs to a canonical exercise")
	for field in ["name", "variant"]:
		if String(definition.get(field, "")).strip_edges().is_empty():
			errors.append("%s: is required" % field)
	if definition.get("laterality") not in LATERALITIES:
		errors.append("laterality: unknown value")
	if definition.get("input_mode") not in INPUT_MODES:
		errors.append("input_mode: unknown value")
	var families = definition.get("movement_families")
	if not families is Array or families.is_empty():
		errors.append("movement_families: choose at least one")
	else:
		if _has_duplicates(families):
			errors.append("movement_families: duplicate values are not allowed")
		for value in families:
			if value not in MOVEMENT_FAMILIES:
				errors.append("movement_families: tracer does not know '%s'" % value)
	var profile = definition.get("kinematic_profile")
	if not profile is Dictionary:
		errors.append("kinematic_profile: is required")
		return errors
	if profile.get("kinetic_chain_type") not in CHAIN_TYPES:
		errors.append("kinematic_profile.kinetic_chain_type: unknown value")
	var actions = profile.get("primary_joint_actions")
	if not actions is Array or actions.is_empty():
		errors.append("kinematic_profile.primary_joint_actions: add at least one action")
	else:
		var action_keys: Array[String] = []
		for index in actions.size():
			var action = actions[index]
			if not action is Dictionary or not JOINT_ACTIONS.has(action.get("joint")) or action.get("movement") not in JOINT_ACTIONS.get(action.get("joint"), []):
				errors.append("kinematic_profile.primary_joint_actions[%d]: unknown joint/action pair" % index)
			elif "%s:%s" % [action.get("joint"), action.get("movement")] in action_keys:
				errors.append("kinematic_profile.primary_joint_actions[%d]: duplicate joint/action pair" % index)
			else:
				action_keys.append("%s:%s" % [action.get("joint"), action.get("movement")])
				if action.get("emphasis", "primary") not in EMPHASES:
					errors.append("kinematic_profile.primary_joint_actions[%d].emphasis: use primary or assist" % index)
				if action.get("sides", "working") not in SIDES:
					errors.append("kinematic_profile.primary_joint_actions[%d].sides: use working or both" % index)
	var limbs = profile.get("one_sided_limbs", [])
	if not limbs is Array or _has_duplicates(limbs) or limbs.any(func(limb) -> bool: return limb not in LIMBS):
		errors.append("kinematic_profile.one_sided_limbs: list arm and/or leg, each once")
	var demands: Array = profile.get("stabilization_demands", [])
	if _has_duplicates(demands):
		errors.append("kinematic_profile.stabilization_demands: duplicate values are not allowed")
	for demand in demands:
		if demand not in STABILIZATION_DEMANDS:
			errors.append("kinematic_profile.stabilization_demands: tracer does not know '%s'" % demand)
	return errors


static func _has_duplicates(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false
