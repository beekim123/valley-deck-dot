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
	var table = load("res://scenes/card_table.tscn").instantiate()
	root.add_child(table)
	await process_frame
	table.save_enabled = false
	await capture("d1-scroll-case")
	table.show_intro()
	await capture("d1-intro")
	table.start_game()
	await capture("d1-day1-tutorial")
	table.awaken_tutorial("res.toby")
	table.awaken_tutorial("res.mira")
	await capture("d1-day1-table")
	table.select_resident("res.toby")
	table.show_preview("loc.pines")
	await capture("d1-drag-preview")
	table.choose_location("loc.pines")
	await capture("d1-use-picker")
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
	await capture("d1-day1-assigned")
	table.begin_night()
	await capture("d1-night")
	table.show_summary()
	await capture("d1-summary")
	table.finish_night()
	await capture("d1-day2")
	var bot := Bots.context("goal", 1)
	while not table.state.chapter_complete and table.state.day <= 60:
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
	await capture("d1-ending")
	table.freeplay()
	await capture("d1-freeplay")
	table.show_panorama()
	await capture("d1-panorama")
	print("D1 real playthrough screenshots complete, day %d" % table.state.day)
	quit()
