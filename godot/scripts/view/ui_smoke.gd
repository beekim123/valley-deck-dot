extends SceneTree
const Rules = preload("res://scripts/core/day_rules.gd")
const Bots = preload("res://scripts/core/bots.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, note: String) -> void:
	if not ok:
		failures += 1
		push_error(note)
func run() -> void:
	var table = load("res://scenes/card_table.tscn").instantiate()
	root.add_child(table)
	await process_frame
	table.save_enabled = false
	check(table.mode == "case", "case opens")
	table.show_intro()
	check(table.mode == "intro", "intro opens")
	table.start_game()
	check(table.state.day == 1, "true first day")
	table.begin_night()
	check(table.state.day == 1 and not table.locked, "tutorial blocks premature night")
	table.close_modal()
	table.awaken_tutorial("res.toby")
	table.awaken_tutorial("res.mira")
	table.select_resident("res.toby")
	table.show_preview("loc.pines")
	table.choose_location("loc.pines")
	var before := JSON.stringify(table.state.resources)
	table.close_modal()
	check(JSON.stringify(table.state.resources) == before and table.state.assignments.is_empty(), "picker cancel no mutation")
	table.confirm_use("loc.pines", "chop", int(table.state.revision))
	check(table.state.assignments.size() == 1, "real UI assignment")
	var assignment_id: String = table.state.assignments[0].id
	table.cancel_assignment(assignment_id)
	check(table.state.assignments.is_empty(), "UI undo")
	table.begin_night()
	var day: int = table.state.day
	table.begin_night()
	check(table.state.day == day, "night double-click blocked")
	table.show_summary()
	table.finish_night()
	check(not table.locked, "summary releases lock")
	var saves := root.get_node("SaveService")
	var path := "user://ui-integration-save.json"
	check(saves.write_dawn(table.state, {}, path) == OK, "UI dawn snapshot saves")
	var saved: Dictionary = saves.load_game(table.defs, path)
	check(not saved.is_empty() and saved.day == table.state.day and saved.assignments.is_empty(), "continue binds defs and restores dawn")
	check(not FileAccess.get_file_as_string(path).contains('"defs"') and not FileAccess.get_file_as_string(path).contains('"dawn_snapshot"'), "serialized save excludes recursive definitions")
	DirAccess.remove_absolute(path)
	var bot := Bots.context("goal", 1)
	while not table.state.chapter_complete and table.state.day <= 60:
		var played: Dictionary = Bots.play_day(table.state, bot)
		check(played.errors.is_empty(), "bot legal commands")
		table.begin_night()
		table.show_summary()
		table.finish_night()
		await process_frame
	check(table.state.chapter_complete and table.mode == "ending", "true rules reach ending")
	table.freeplay()
	check(table.state.ending_seen and table.mode == "table", "freeplay")
	table.begin_night()
	table.show_summary()
	table.finish_night()
	check(table.mode == "table", "ending not repeated")
	print("D1 UI integration: %d failures; true goal reached day %d" % [failures, table.state.day])
	quit(1 if failures else 0)
