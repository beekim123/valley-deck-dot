extends SceneTree
## Probe an exported PCK with the matching native engine. This is NOT macOS launch validation.
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var catalog = root.get_node_or_null("AssetCatalog")
	check(catalog != null, "autoload catalog available")
	if catalog == null:
		quit(1)
		return
	var font: Font = catalog.pixel_font()
	check(font != null and font.has_char(0x8C37), "exported Chinese pixel font")
	for kind in ["art", "audio"]:
		var file: String = "res://resources/" + kind + "/manifest.json"
		check(FileAccess.file_exists(file), "manifest " + kind)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
		check(parsed is Dictionary and parsed.has("assets"), "manifest parse " + kind)
		if not parsed is Dictionary: continue
		for item: Dictionary in parsed.assets:
			if kind == "art":
				var tex: Texture2D = catalog.texture(item.id, int(item.frames) - 1)
				check(tex != null and tex.get_width() == int(item.size[0]), "exported atlas " + str(item.id))
			else:
				check(FileAccess.file_exists("res://resources/audio/" + str(item.file)), "raw WAV " + str(item.id))
				var stream: AudioStreamWAV = catalog.sound(item.id)
				check(stream != null and stream.format == AudioStreamWAV.FORMAT_16_BITS, "exported PCM " + str(item.id))
	var loader: Script = load("res://scripts/content/data_loader.gd")
	var rules: Script = load("res://scripts/core/day_rules.gd")
	var defs: Dictionary = loader.load_defs()
	check(defs.get("locations", []).size() == 11, "complete exported content")
	var state: Dictionary = rules.new_game(defs)
	check(not state.is_empty() and state.day == 1, "exported new game")
	var scene: PackedScene = load("res://scenes/title.tscn")
	var title = scene.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame
	check(is_instance_valid(title), "exported title instantiates")
	root.get_node("AudioService").stop_all()
	title.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	print("EXPORTED PACK PROBE: %d checks, %d failures (native pack inspection, not macOS launch)" % [checks, failures])
	quit(1 if failures else 0)
