extends Node
## Versioned storage shell. D1 owns dawn snapshot construction, never day assignments.
const VERSION := 1
const SAVE_PATH := "user://save.json"
var last_error := ""

func write_snapshot(state: Dictionary, settings: Dictionary = {}, path: String = SAVE_PATH) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"version": VERSION, "state": state, "settings": settings}))
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
