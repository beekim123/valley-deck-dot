extends Node
## Versioned storage shell. D1 owns dawn snapshot construction, never day assignments.
const VERSION := 1
const SAVE_PATH := "user://save.json"
var last_error := ""

func write_snapshot(state: Dictionary, settings: Dictionary = {}, path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "state": _serializable(state), "settings": settings}))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func read_snapshot(path: String = SAVE_PATH) -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	var parsed_ok := parser.parse(FileAccess.get_file_as_string(path)) == OK
	var value: Variant = parser.data if parsed_ok else null
	if value is Dictionary and value.get("version") == VERSION and value.get("state") is Dictionary and value.get("settings") is Dictionary:
		return value
	last_error = "存档无法读取，已保留备份。"
	var backup := path + ".broken-" + str(Time.get_unix_time_from_system())
	var error := DirAccess.rename_absolute(path, backup)
	if error != OK:
		last_error = "存档无法读取；备份改名失败，原文件仍保留。"
	return {}

## Drop shared definitions and nested dawn copies at every level, not only the root.
func _serializable(value: Variant) -> Variant:
	if value is Dictionary:
		var clean: Dictionary = {}
		for key: Variant in value:
			if key != "defs" and key != "dawn_snapshot":
				clean[key] = _serializable(value[key])
		return clean
	if value is Array:
		var clean: Array = []
		for item: Variant in value:
			clean.append(_serializable(item))
		return clean
	return value

func write_dawn(state: Dictionary, settings: Dictionary = {}, path: String = SAVE_PATH) -> Error:
	var dawn: Dictionary = state.get("dawn_snapshot", {})
	return write_snapshot(state if dawn.is_empty() else dawn, settings, path)

func load_game(defs: Dictionary, path: String = SAVE_PATH) -> Dictionary:
	var envelope := read_snapshot(path)
	if envelope.is_empty():
		return {}
	var state: Dictionary = envelope.state
	if not _valid_game(state, defs):
		last_error = "存档内容不完整，已保留备份。"
		var error := DirAccess.rename_absolute(path, path + ".broken-" + str(Time.get_unix_time_from_system()))
		if error != OK:
			last_error = "存档无法读取；备份改名失败，原文件仍保留。"
		return {}
	state["defs"] = defs
	state["dawn_snapshot"] = _serializable(state)
	return state

# Validate the complete mutable schema before any core or UI property access.
# JSON numbers decode as floats; integer-valued, finite values are accepted.
func _integer(value: Variant, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= 9007199254740991 and value == floor(float(value))

func _ids(defs: Dictionary, collection: String) -> Array:
	var records: Variant = defs.get(collection, [])
	var result: Array = []
	for record: Dictionary in (records.values() if records is Dictionary else records):
		result.append(record.id)
	return result

func _id_list(value: Variant, allowed: Array, unique: bool = true) -> bool:
	if not value is Array: return false
	var seen := {}
	for id: Variant in value:
		if not id is String or id not in allowed or (unique and seen.has(id)): return false
		seen[id] = true
	return true

func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size(): return false
	for key: Variant in keys:
		if not value.has(key): return false
	return true

func _paid_keys(value: Variant, out: Array) -> void:
	if value is Dictionary:
		if value.get("op") == "spend" and value.has("once_key") and value.once_key not in out:
			out.append(value.once_key)
		for item: Variant in value.values(): _paid_keys(item, out)
	elif value is Array:
		for item: Variant in value: _paid_keys(item, out)

func _progress_limits(value: Variant, out: Dictionary) -> void:
	if value is Dictionary:
		if value.get("op") == "progress":
			out[str(value.loc) + ":" + str(value.key)] = value.max
		for item: Variant in value.values(): _progress_limits(item, out)
	elif value is Array:
		for item: Variant in value: _progress_limits(item, out)

func _duration(defs: Dictionary, id: String) -> int:
	for collection: String in ["events", "visitors"]:
		var records: Variant = defs.get(collection, [])
		for record: Dictionary in (records.values() if records is Dictionary else records):
			if record.id == id: return int(record.duration)
	return 0

func _valid_game(state: Dictionary, defs: Dictionary) -> bool:
	for key: String in ["resources", "locations", "residents", "flags", "goal_steps", "day_modifiers", "event_history"]:
		if not state.get(key) is Dictionary: return false
	for key: String in ["assignments", "paid_once_keys", "triggered_combos", "active_events", "queued_events", "spell_inventory", "schedule_done", "visitors_seen", "last_day_events", "resolved_uses"]:
		if not state.get(key) is Array: return false
	for key: String in ["version", "revision", "day", "idle_streak", "dawn_processed_day"]:
		if not _integer(state.get(key)): return false
	for key: String in ["seed", "rng_state"]:
		if not _integer(state.get(key), -9007199254740991): return false
	for key: String in ["chapter_complete", "ending_seen", "idle_reminder_sent"]:
		if not state.get(key) is bool: return false
	if state.version != VERSION or state.get("content_version") != defs.balance.get("content_version", "content/1"): return false
	if state.day < 1 or state.dawn_processed_day != state.day or state.get("phase", "") not in ["day", "ending"]: return false
	if not state.assignments.is_empty() or not state.resolved_uses.is_empty(): return false
	if not _exact_keys(state.resources, ["wood", "stone", "warmth"]): return false
	for amount: Variant in state.resources.values():
		if not _integer(amount): return false
	var locations := _ids(defs, "locations")
	var residents := _ids(defs, "residents")
	var goals := _ids(defs, "goals")
	var events := _ids(defs, "events") + _ids(defs, "visitors")
	if not _exact_keys(state.locations, locations) or not _exact_keys(state.residents, residents) or not _exact_keys(state.goal_steps, goals): return false
	var limits := {}
	_progress_limits(defs, limits)
	for id: String in locations:
		var loc: Variant = state.locations[id]
		if not loc is Dictionary or loc.get("state", "") not in ["hidden", "fog", "frozen", "thawed", "restored"] or not loc.get("progress") is Dictionary: return false
		for key: String in ["revealed_day", "thawed_day", "restored_day", "blocked_until_day"]:
			if not _integer(loc.get(key)): return false
			if key != "blocked_until_day" and loc[key] > state.day: return false
		for key: Variant in loc.progress:
			if not key is String or not _integer(loc.progress[key]): return false
			var limit_id := id + ":" + str(key)
			if not limits.has(limit_id) or loc.progress[key] > limits[limit_id]: return false
	for id: String in residents:
		var resident: Variant = state.residents[id]
		if not resident is Dictionary or resident.get("status", "") not in ["awake", "frozen"] or not _integer(resident.get("awakened_day")): return false
		if resident.awakened_day > state.day: return false
	for flag: Variant in state.flags.values():
		if not (flag is bool or flag is String or _integer(flag, -9007199254740991)): return false
	var all_complete := not goals.is_empty()
	for done: Variant in state.goal_steps.values():
		if not done is bool: return false
		all_complete = all_complete and done
	if state.chapter_complete != all_complete or (state.ending_seen and not state.chapter_complete): return false
	if not _exact_keys(state.day_modifiers, ["two_actions_resident", "extra_flip"]): return false
	if state.day_modifiers.two_actions_resident != "" or state.day_modifiers.extra_flip != false: return false
	var once_keys: Array = []
	_paid_keys(defs, once_keys)
	if not _id_list(state.paid_once_keys, once_keys): return false
	if not _id_list(state.triggered_combos, _ids(defs, "combos")): return false
	if not _id_list(state.spell_inventory, _ids(defs, "spells"), false): return false
	if not _id_list(state.schedule_done, _ids(defs, "schedule")): return false
	if not _id_list(state.visitors_seen, _ids(defs, "visitors")): return false
	if not _id_list(state.queued_events, events): return false
	if state.active_events.size() > int(defs.balance.event_capacity): return false
	var seen := {}
	for event: Variant in state.active_events:
		if not event is Dictionary or not event.get("id") is String or event.id not in events or seen.has(event.id): return false
		if not _integer(event.get("issued_day"), 1) or event.issued_day > state.day or not _integer(event.get("remaining"), 1): return false
		if event.remaining > _duration(defs, event.id): return false
		seen[event.id] = true
	for id: Variant in state.queued_events:
		if seen.has(id): return false
		seen[id] = true
	for id: Variant in state.event_history:
		if id not in events or seen.has(id): return false
		var event: Variant = state.event_history[id]
		if not event is Dictionary or event.get("status", "") not in ["completed", "expired"] or not _integer(event.get("day"), 1) or event.day > state.day: return false
	for event: Variant in state.last_day_events:
		if not event is Dictionary or not event.get("type") is String or not event.get("payload") is Dictionary or not _integer(event.get("seq")) or not _integer(event.get("day"), 1): return false
	return true
