class_name AnatomyStructureRegistry
extends RefCounted

var records_by_id: Dictionary = {}
var nodes_by_id: Dictionary = {}
var ordered_ids: Array[String] = []
var catalog_sha256 := ""


func load_manifest(path: String) -> bool:
	records_by_id.clear()
	nodes_by_id.clear()
	ordered_ids.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open anatomy manifest: %s" % path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("structures"):
		push_error("Invalid anatomy manifest: %s" % path)
		return false
	catalog_sha256 = String(parsed.get("catalog_sha256", ""))
	for record in parsed["structures"]:
		var structure_id := String(record.get("id", ""))
		if structure_id.is_empty() or records_by_id.has(structure_id):
			push_error("Invalid or duplicate anatomy ID: %s" % structure_id)
			return false
		records_by_id[structure_id] = record
		ordered_ids.append(structure_id)
	return true


func bind_scene(root: Node) -> Array[String]:
	nodes_by_id.clear()
	var errors: Array[String] = []
	bind_node_recursive(root, errors)
	for structure_id in ordered_ids:
		if not nodes_by_id.has(structure_id):
			errors.append("Manifest structure has no scene node: %s" % structure_id)
	return errors


func bind_node_recursive(node: Node, errors: Array[String]) -> void:
	if node is MeshInstance3D:
		var extras: Dictionary = node.get_meta("extras", {})
		var structure_id := String(extras.get("bodysim_id", node.get_meta("bodysim_id", "")))
		if not structure_id.is_empty():
			if not records_by_id.has(structure_id):
				errors.append("Scene node has no manifest record: %s" % structure_id)
			elif nodes_by_id.has(structure_id):
				errors.append("Duplicate scene node identity: %s" % structure_id)
			else:
				nodes_by_id[structure_id] = node
				node.set_meta("bodysim_id", structure_id)
				node.set_meta(
					"bodysim_display_depth",
					records_by_id[structure_id].get("display_depth", "structural")
				)
	for child in node.get_children():
		bind_node_recursive(child, errors)


func is_complete() -> bool:
	return records_by_id.size() > 0 and nodes_by_id.size() == records_by_id.size()


func get_record(structure_id: String) -> Dictionary:
	return records_by_id.get(structure_id, {})


func get_structure_node(structure_id: String) -> MeshInstance3D:
	return nodes_by_id.get(structure_id) as MeshInstance3D


func search(query: String, limit := 960) -> Array[Dictionary]:
	var normalized_query := normalize(query)
	var terms := normalized_query.split(" ", false)
	var matches: Array[Dictionary] = []
	for structure_id in ordered_ids:
		var record: Dictionary = records_by_id[structure_id]
		var haystack := normalize("%s %s %s %s" % [
			record.get("name", ""),
			structure_id.replace(".", " ").replace("_", " "),
			record.get("latin_name", ""),
			record.get("source_object", ""),
		])
		var matches_all := true
		for term in terms:
			if not haystack.contains(term):
				matches_all = false
				break
		if not matches_all:
			continue
		var score := search_score(record, normalized_query, haystack)
		matches.append({"record": record, "score": score})
	matches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] < b["score"]
		return String(a["record"]["id"]) < String(b["record"]["id"])
	)
	var results: Array[Dictionary] = []
	for index in range(min(limit, matches.size())):
		results.append(matches[index]["record"])
	return results


func search_score(record: Dictionary, query: String, haystack: String) -> int:
	if query.is_empty():
		return 100
	var name := normalize(String(record.get("name", "")))
	var structure_id := normalize(String(record.get("id", "")).replace(".", " ").replace("_", " "))
	if name == query or structure_id == query:
		return 0
	if name.begins_with(query):
		return 10
	if structure_id.begins_with(query):
		return 20
	return 30 + haystack.find(query) if haystack.contains(query) else 100


func normalize(value: String) -> String:
	return value.strip_edges().to_lower().replace("-", " ").replace("_", " ")
