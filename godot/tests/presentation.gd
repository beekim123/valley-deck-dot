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
	for key: String in ["wheel", "dam", "hauling"]:
		check(int(table.defs.balance.progress_caps.get(key, 0)) > 0, "progress cap is positive: " + key)
	check(table.progress_text({"wheel": 2.0}) == "进度 2/2", "JSON float progress displays clean integer and cap")
	for loc: Dictionary in table.defs.locations:
		for use: Dictionary in loc.uses:
			for season: String in ["", ".winter"]:
				var id := "locart." + str(loc.id).trim_prefix("loc.") + ".anim." + str(use.id) + season
				check(catalog.has_art(id) and int(catalog.metadata(id).get("frames", 0)) == 4, "every defined action has four actual seasonal frames: " + id)
	for resident: Dictionary in table.defs.residents:
		var walker := "walker." + str(resident.id).trim_prefix("res.")
		check(catalog.has_art(walker) and int(catalog.metadata(walker).get("frames", 0)) >= 8, "actual resident work animation " + walker)
	if failures: quit(1); return
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
	await process_frame
	var compact: Control
	var hand: Control
	for child in table.screen.get_children():
		if child.get_script() == load("res://scripts/view/resident_token.gd"):
			if child.resident_id == "res.toby" and not child.target_location.is_empty(): compact = child
			if child.resident_id == "res.mira" and child.target_location.is_empty(): hand = child
	check(compact != null and hand != null, "actual badge and hand drop targets exist")
	if compact != null and hand != null:
		hand.force_drag({"resident": "res.mira", "assignment": ""}, Control.new())
		await process_frame
		var move := InputEventMouseMotion.new()
		move.position = compact.get_global_rect().get_center()
		move.global_position = move.position
		root.push_input(move, true)
		await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = move.position
		release.global_position = move.position
		root.push_input(release, true)
		await process_frame
		check(is_instance_valid(table.modal) and table.selected == "res.mira", "actual viewport drop atop assigned face opens common location chooser")
		check(table.state.assignments.size() == 1, "overlay drop remains preview-only until confirmation")
		table.close_modal()
		await process_frame
		var old_assignment := str(table.state.assignments[0].id)
		compact.force_drag({"resident": "res.toby", "assignment": old_assignment}, Control.new())
		await process_frame
		move.position = hand.get_global_rect().get_center()
		move.global_position = move.position
		root.push_input(move, true)
		await process_frame
		release.position = move.position
		release.global_position = move.position
		root.push_input(release, true)
		await process_frame
		check(table.state.assignments.is_empty(), "actual viewport drop onto another hand portrait returns original assignment")
		table.select_resident("res.toby")
		table.confirm_use("loc.pines", "chop", int(table.state.revision))
	table.select_resident("res.mira")
	table.confirm_use("loc.flower_slope", "explore", int(table.state.revision))
	table.begin_night()
	var snapshot := JSON.stringify(table.state)
	var found := false
	for i in table.night_events.size():
		var event: Dictionary = table.night_events[i]
		if event.type == "resolve":
			table.clear_story()
			table.night_index = i
			table.play_next_event()
			check(table.night_art == "locart.pines.anim.chop.winter", "actual resolved use selects its own authored frames")
			check(int(catalog.metadata(table.night_art).frames) == 4, "night action has four frames")
			check(table.night_picture.size == Vector2(256, 192), "night art is exact 4x")
			check(table.night_actor_art == "walker.toby", "night actor is actual assigned resident")
			check(table.night_actor.position == Vector2(296, 162) and table.night_actor.size == Vector2(64, 96), "native work sprite and foot anchor at exact4x")
			found = true
			break
	check(found, "actual core emits resolve for assigned resident")
	await create_timer(0.2).timeout
	check(snapshot == JSON.stringify(table.state), "animation never executes rules or changes state")
	for i in table.night_events.size():
		var event: Dictionary = table.night_events[i]
		if event.type == "resolve" and event.payload.use_id == "explore":
			table.night_index = i
			table.play_next_event()
			check(table.modal.has_node("CardReveal"), "generic explore animates an authored card reveal")
			check(table.modal.get_node("CardReveal").art == "flower_slope", "explore animation is its actual location, never a placeholder")
			break
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
	check(table.banter.muted_speakers.get("ember", -1) == table.state.day, "sulking suppresses voice and bubble, not just visible text")
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
