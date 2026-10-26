extends SceneTree
const Rules = preload("res://scripts/core/day_rules.gd")
const Storage = preload("res://scripts/services/save_service.gd")
const Data = preload("res://scripts/core/rule_data.gd")
var failures := 0
var assertions := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var defs := {}
	for key in ["locations", "residents", "combos", "events", "visitors", "spells", "goals", "schedule", "balance"]:
		defs[key] = JSON.parse_string(FileAccess.get_file_as_string("res://../content/data/" + key + ".json"))[key]
	var save := Storage.new()
	var state := Rules.new_game(defs)
	check(save._valid_game(Data.snapshot(state), defs), "new dawn valid")
	Rules.tutorial_awaken(state, "res.toby")
	Rules.tutorial_awaken(state, "res.mira")
	Rules.end_day(state)
	var good := Data.snapshot(state)
	check(save._valid_game(good, defs), "next dawn valid")
	for field in good:
		var bad := good.duplicate(true)
		bad.erase(field)
		check(not save._valid_game(bad, defs), "missing field " + field)
	var mutations := [
		["locations", {"loc.pines": {}}], ["resources", {"wood": -1, "stone": 0, "warmth": 3}],
		["active_events", [{}]], ["queued_events", ["unknown"]], ["event_history", {"ev.storm": {}}],
		["revision", 1.5], ["day", 2.5], ["flags", {"bad": []}], ["spell_inventory", ["missing"]]
	]
	for pair in mutations:
		var bad := good.duplicate(true)
		bad[pair[0]] = pair[1]
		check(not save._valid_game(bad, defs), "malformed " + pair[0])
	var bad := good.duplicate(true)
	bad.locations["loc.pines"] = {}
	check(not save._valid_game(bad, defs), "empty nested location rejected")
	bad = good.duplicate(true)
	bad.residents["res.toby"].status = []
	check(not save._valid_game(bad, defs), "malformed nested resident rejected")
	bad = good.duplicate(true)
	bad.locations["loc.mill"].progress.wheel = 999
	check(not save._valid_game(bad, defs), "overflow progress rejected")
	bad = good.duplicate(true)
	bad.active_events = [{"id": "ev.storm", "issued_day": 1, "remaining": 99}]
	check(not save._valid_game(bad, defs), "overflow event duration rejected")
	var path := "user://audit-corrupt.json"
	save.write_snapshot(bad, {}, path)
	check(save.load_game(defs, path).is_empty() and not FileAccess.file_exists(path), "malformed file backed up and rejected")
	check(save.write_dawn(state, {}, path) == OK and not save.load_game(defs, path).is_empty(), "valid save roundtrip")
	save.free()
	print("Save validation: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
