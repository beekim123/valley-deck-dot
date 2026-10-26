extends RefCounted
## Read-only registry adapter. Content remains owned by content/ and the sync tool.
static func load_defs() -> Dictionary:
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/registry.json"))
	if not registry is Dictionary or registry.get("format") != "content/1":
		return {}
	var defs: Dictionary = {}
	for entry: Dictionary in registry.get("files", []):
		var path: String = entry.get("path", "")
		if path.contains("..") or path.begins_with("/"):
			return {}
		var body: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + path))
		if not body is Dictionary or body.get("format") != "content/1":
			return {}
		for key: String in body:
			if key != "format":
				defs[key] = body[key]
	return defs
