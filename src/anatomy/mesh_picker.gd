extends RefCounted

var registry: RefCounted
var entries: Array[Dictionary] = []
var triangle_meshes: Dictionary = {}
var last_query_usec := 0
var last_candidate_count := 0
var last_surface_hit_count := 0


func _init(structure_registry: RefCounted) -> void:
	registry = structure_registry
	refresh()


func refresh() -> void:
	entries.clear()
	if registry == null:
		return
	for structure_id in registry.ordered_ids:
		var mesh_node: MeshInstance3D = registry.get_structure_node(structure_id)
		if mesh_node == null or mesh_node.mesh == null:
			continue
		entries.append({
			"id": structure_id,
			"node": mesh_node,
			"bounds": mesh_node.get_aabb(),
		})


func pick_ray(world_origin: Vector3, world_direction: Vector3) -> Array[Dictionary]:
	var started_usec := Time.get_ticks_usec()
	var hits: Array[Dictionary] = []
	last_candidate_count = 0
	last_surface_hit_count = 0
	if world_direction.is_zero_approx():
		last_query_usec = Time.get_ticks_usec() - started_usec
		return hits
	var normalized_world_direction := world_direction.normalized()
	for entry in entries:
		var mesh_node: MeshInstance3D = entry["node"]
		if not mesh_node.is_visible_in_tree():
			continue
		var inverse_transform := mesh_node.global_transform.affine_inverse()
		var local_origin: Vector3 = inverse_transform * world_origin
		var local_direction: Vector3 = (
			inverse_transform.basis * normalized_world_direction
		).normalized()
		var bounds: AABB = entry["bounds"]
		if bounds.intersects_ray(local_origin, local_direction) == null:
			continue
		last_candidate_count += 1
		var local_hit: Dictionary = intersect_mesh(mesh_node.mesh, local_origin, local_direction)
		if local_hit.is_empty():
			continue
		var local_position: Vector3 = local_hit["position"]
		var world_position: Vector3 = mesh_node.global_transform * local_position
		hits.append({
			"id": entry["id"],
			"node": mesh_node,
			"position": world_position,
			"distance": world_origin.distance_to(world_position),
			"face_index": local_hit.get("face_index", -1),
		})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a["distance"], b["distance"]):
			return a["distance"] < b["distance"]
		return String(a["id"]) < String(b["id"])
	)
	last_surface_hit_count = hits.size()
	last_query_usec = Time.get_ticks_usec() - started_usec
	return hits


func intersect_mesh(mesh: Mesh, local_origin: Vector3, local_direction: Vector3) -> Dictionary:
	var data := get_triangle_data(mesh)
	if data.is_empty():
		return {}
	var coordinate_scale: float = data["coordinate_scale"]
	var hit: Dictionary = data["triangle_mesh"].intersect_ray(
		local_origin * coordinate_scale,
		local_direction
	)
	if not hit.is_empty():
		hit["position"] = Vector3(hit["position"]) / coordinate_scale
	return hit


func get_triangle_data(mesh: Mesh) -> Dictionary:
	var mesh_key := mesh.get_instance_id()
	if triangle_meshes.has(mesh_key):
		return triangle_meshes[mesh_key]
	var bounds := mesh.get_aabb()
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if extent <= 0.0:
		triangle_meshes[mesh_key] = {}
		return {}
	var coordinate_scale := 1.0
	var triangle_mesh: TriangleMesh
	if extent < 0.02:
		coordinate_scale = 1.0 / extent
		var normalized_faces := mesh.get_faces()
		for index in range(normalized_faces.size()):
			normalized_faces[index] *= coordinate_scale
		triangle_mesh = TriangleMesh.new()
		if not triangle_mesh.create_from_faces(normalized_faces):
			triangle_meshes[mesh_key] = {}
			return {}
	else:
		triangle_mesh = mesh.generate_triangle_mesh()
		if triangle_mesh == null:
			triangle_meshes[mesh_key] = {}
			return {}
	var data := {
		"triangle_mesh": triangle_mesh,
		"coordinate_scale": coordinate_scale,
	}
	triangle_meshes[mesh_key] = data
	return data


func cached_triangle_mesh_count() -> int:
	return triangle_meshes.size()
