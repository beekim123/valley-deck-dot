extends Node
## The sole runtime resolver for semantic art/audio ids and bundled fonts.
var _art: Dictionary = {}
var _audio: Dictionary = {}
var _cache: Dictionary = {}
var _font: FontFile

func _ready() -> void:
	_art = _read_manifest("res://resources/art/manifest.json")
	_audio = _read_manifest("res://resources/audio/manifest.json")

func _read_manifest(path: String) -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(path):
		push_error("Missing synchronized manifest: " + path)
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Invalid manifest: " + path)
		return result
	for entry: Dictionary in parsed.get("assets", []):
		result[str(entry.id)] = entry
	return result

func has_art(id: String) -> bool:
	return _art.has(id)

func has_audio(id: String) -> bool:
	return _audio.has(id)

func metadata(id: String) -> Dictionary:
	return _art.get(id, _audio.get(id, {})).duplicate(true)

func texture(id: String, frame: int = 0) -> Texture2D:
	var key := "%s:%d" % [id, frame]
	if _cache.has(key):
		return _cache[key] as Texture2D
	if not _art.has(id):
		push_error("Unknown art id: " + id)
		return null
	var meta: Dictionary = _art[id]
	if frame < 0 or frame >= int(meta.frames):
		push_error("Invalid art frame: " + key)
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://resources/art/" + str(meta.file)) as Texture2D
	atlas.region = Rect2(frame * int(meta.size[0]), 0, int(meta.size[0]), int(meta.size[1]))
	_cache[key] = atlas
	return atlas

func sound(id: String) -> AudioStream:
	if not _audio.has(id):
		push_error("Unknown audio id: " + id)
		return null
	if not _cache.has(id):
		var meta: Dictionary = _audio[id]
		var stream := AudioStreamWAV.load_from_file("res://resources/audio/" + str(meta.file), {"compress/mode": 0, "force/8_bit": false, "edit/normalize": false, "edit/trim": false})
		if stream == null:
			return null
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if meta.get("loop", false) else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = 0
		stream.loop_end = int(meta.frames)
		_cache[id] = stream
	return _cache[id] as AudioStream

func pixel_font() -> FontFile:
	if _font != null:
		return _font
	var paths := _font_paths("res://resources/fonts")
	paths.sort()
	for path: String in paths:
		if "zh_hans" in path or "zh-hans" in path:
			paths.erase(path)
			paths.push_front(path)
			break
	if paths.is_empty():
		push_error("Fusion Pixel font missing; run npm run sync")
		return null
	_font = load(paths[0]) as FontFile
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting = TextServer.HINTING_NONE
	_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font.multichannel_signed_distance_field = false
	return _font

func _font_paths(directory: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return result
	for file: String in dir.get_files():
		if file.get_extension().to_lower() in ["ttf", "otf", "woff", "woff2"]:
			result.append(directory.path_join(file))
	for child: String in dir.get_directories():
		result.append_array(_font_paths(directory.path_join(child)))
	return result
