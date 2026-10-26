extends SceneTree
## Headless contracts plus actual UI commands; raster QA runs through ui_shots on a display.
var Settings: GDScript
var failures := 0
var assertions := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	Settings = load("res://scripts/view/settings_panel.gd")
	var catalog := root.get_node("AssetCatalog")
	for suffix: String in ["pines", "hut", "flower_slope", "herb_garden", "river_bend", "misty_bank", "tree_hole", "mill", "gravel", "old_bridge", "flood_beach"]:
		for season: String in ["winter", "spring"]:
			for prefix: String in ["locart.", "pano."]:
				var id := prefix + suffix + "." + season
				check(catalog.has_art(id), "required world art: " + id)
	for id: String in ["board.table", "card.loc_frame.fog", "card.loc_frame.frozen", "card.loc_frame.thawed", "card.loc_frame.restored", "card.res_frame", "ui.panel.wood", "ui.panel.preview", "deco.window", "deco.clock", "char.ember"]:
		check(catalog.has_art(id), "required interface art: " + id)
	if failures: quit(1); return
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	check(title.play_button.text.contains("开始"), "prominent real play action")
	check(title.play_button.size.y >= 32, "primary title action has comfortable target")
	title.queue_free()
	await process_frame
	var table = load("res://scenes/card_table.tscn").instantiate()
	root.add_child(table)
	await process_frame
	table.save_enabled = false
	table.start_game()
	check(table.panorama.size == Vector2(640, 80), "continuous native ribbon viewport")
	check(table.panorama.zoom == 1, "table panorama uses integer scale")
	for id: String in table.cards:
		check(table.cards[id].size == Vector2(72, 88), "native card dimensions " + id)
		check(table.cards[id].get_theme_stylebox("normal") is StyleBoxTexture, "authored card frame " + id)
	table.awaken_tutorial("res.toby")
	check(is_instance_valid(table.story_player), "tutorial mounts full awaken director")
	table.clear_story()
	table.awaken_tutorial("res.mira")
	table.clear_story()
	table.select_resident("res.toby")
	table.confirm_use("loc.pines", "chop", int(table.state.revision))
	table.begin_night()
	var snapshot := JSON.stringify(table.state)
	var found := false
	for i in table.night_events.size():
		var event: Dictionary = table.night_events[i]
		if event.type == "resolve":
			table.clear_story()
			table.night_index = i
			table.play_next_event()
			check(table.night_art == "locart.pines.anim.chop", "actual resolved use selects its own authored frames")
			check(int(catalog.metadata(table.night_art).frames) == 4, "night action has four frames")
			check(table.night_picture.size == Vector2(256, 192), "night art is exact 4x")
			found = true
			break
	check(found, "actual core emits resolve for assigned resident")
	await create_timer(0.2).timeout
	check(snapshot == JSON.stringify(table.state), "animation never executes rules or changes state")
	table.show_summary()
	table.finish_night()
	table.show_panorama()
	check(table.modal.has_node("FullPanorama"), "full panorama mounts")
	var full = table.modal.get_node("FullPanorama")
	full.pan(99999)
	check(full.offset == full.max_offset(), "pan clamps at right edge")
	full.pan(-99999)
	check(full.offset == 0, "pan clamps at left edge")
	check(full.zoom == 2, "full view keeps integer scale")
	full.restore_segment("loc.pines")
	check(full.transitions.has("loc.pines"), "restoration has a tracked dissolve")
	table.close_modal()
	var before_poke := JSON.stringify(table.state)
	for i in 5: table.poke("teacup")
	check(table.status.contains("别往我身上倒"), "fifth tea poke")
	for i in 3: table.poke("pipe")
	check(table.status.contains("烟圈"), "third pipe poke")
	for i in 10: table.poke("ember")
	check(table.ember_sulk_day == table.state.day, "tenth ember poke sulks for current day")
	check(before_poke == JSON.stringify(table.state), "hidden jokes do not add mechanics")
	var old_settings := ""
	if FileAccess.file_exists(Settings.PATH): old_settings = FileAccess.get_file_as_string(Settings.PATH)
	var settings = Settings.new()
	root.add_child(settings)
	settings.open(Settings.DEFAULTS.duplicate(), Callable())
	settings.values.master = 0.35
	settings.values.text_speed = 15
	settings.values.short_night = true
	settings.save()
	var restored: Dictionary = Settings.read_values()
	check(is_equal_approx(float(restored.master), 0.35) and restored.text_speed == 15 and restored.short_night, "settings persisted through SaveService envelope")
	if old_settings.is_empty(): DirAccess.remove_absolute(Settings.PATH)
	else:
		var file := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		file.store_string(old_settings)
	settings.queue_free()
	root.get_node("AudioService").stop_all()
	table.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	print("D2 presentation: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
