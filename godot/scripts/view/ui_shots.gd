extends SceneTree
## Real rendered screens, true core commands; no fabricated ending or state shortcuts.
const Bots = preload("res://scripts/core/bots.gd")
const Rules = preload("res://scripts/core/day_rules.gd")
var destination := "res://../artifacts/screenshots"
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	var error := picture.save_png(destination.path_join(name + ".png"))
	if error != OK:
		push_error("Capture failed: " + name)
		quit(1)
	print("CAPTURE " + name)
func run() -> void:
	destination = ProjectSettings.globalize_path(destination)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots-dir="):
			destination = arg.trim_prefix("--shots-dir=")
	DirAccess.make_dir_recursive_absolute(destination)
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await capture("d2-title")
	title.queue_free()
	await process_frame
	var table = load("res://scenes/card_table.tscn").instantiate()
	root.add_child(table)
	await process_frame
	table.save_enabled = false
	# Capture complete captions deterministically without changing any rule state.
	table.settings.text_speed = 0
	table.short_night = false
	await capture("d2-scroll-case")
	table.show_intro()
	await capture("d2-intro")
	table.start_game()
	await capture("d2-day1-tutorial")
	table.awaken_tutorial("res.toby")
	await create_timer(3.1).timeout
	await capture("d2-awaken-toby")
	table.clear_story()
	table.awaken_tutorial("res.mira")
	table.clear_story()
	await capture("d2-day1-table")
	table.select_resident(table.defs.balance.thaw_resident)
	table.choose_location("loc.mill")
	await capture("d2-insufficient-preview")
	table.close_modal()
	table.select_resident("res.toby")
	table.show_preview("loc.pines")
	await capture("d2-drag-preview")
	table.choose_location("loc.pines")
	await capture("d2-use-picker")
	table.confirm_use("loc.pines", "chop", int(table.state.revision))
	table.select_resident("res.mira")
	table.confirm_use("loc.flower_slope", "explore", int(table.state.revision))
	# Use actual awake protagonist ID from data rather than assuming its spelling.
	for resident: Dictionary in table.defs.residents:
		if resident.id not in ["res.toby", "res.mira"] and table.state.residents[resident.id].status == "awake":
			table.select_resident(resident.id)
			var preview: Dictionary = Rules.preview(table.state, resident.id, "loc.hut")
			for use: Dictionary in preview.uses:
				if use.enabled:
					table.confirm_use("loc.hut", use.id, int(table.state.revision))
					break
	await capture("d2-day1-assigned")
	table.begin_night()
	while table.night_art.is_empty() and table.night_index < table.night_events.size():
		table.clear_story()
		table.play_next_event()
	await create_timer(0.3).timeout
	await capture("d2-night")
	table.show_summary()
	await capture("d2-summary")
	table.finish_night()
	await capture("d2-day2")
	var bot := Bots.context("goal", 1)
	var captured_awaken := false
	while not table.state.chapter_complete and table.state.day <= 60:
		if not captured_awaken:
			for loc: Dictionary in table.defs.locations:
				if table.state.locations[loc.id].state == "frozen" and not loc.get("awaken", []).is_empty():
					table.render_table()
					table.select_resident(table.defs.balance.thaw_resident)
					table.choose_location(loc.id)
					await capture("d2-public-awaken-preview")
					table.close_modal()
					captured_awaken = true
					break
		var played: Dictionary = Bots.play_day(table.state, bot)
		if not played.errors.is_empty():
			push_error("Screenshot playthrough command failure")
			quit(1)
			return
		table.render_table()
		table.begin_night()
		table.show_summary()
		table.finish_night()
		await process_frame
	if not table.state.chapter_complete:
		push_error("Screenshot playthrough did not finish")
		quit(1)
		return
	await capture("d2-ending")
	table.clear_story()
	table.ending_pan()
	await create_timer(1).timeout
	await capture("d2-ending-pan")
	table.freeplay()
	await capture("d2-freeplay")
	table.show_panorama()
	await capture("d2-panorama")
	table.close_modal()
	table.show_settings()
	await capture("d2-settings")
	print("D2 real playthrough screenshots complete, day %d" % table.state.day)
	quit()
