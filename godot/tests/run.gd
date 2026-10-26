extends SceneTree
const Ledger = preload("res://scripts/core/resource_ledger.gd")
var failures := 0
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var original := {"wood": 3, "stone": 2, "warmth": 1}
	var cost := {"wood": 3, "stone": 2}
	var reservation: Dictionary = Ledger.reserve(original, cost)
	expect(reservation.ok, "affordable reservation succeeds")
	expect(reservation.balance == {"wood": 0, "stone": 0, "warmth": 1}, "exact pre-deduction")
	expect(original.wood == 3, "preview does not mutate original state")
	expect(Ledger.refund(reservation.balance, cost) == original, "undo restores exact balance")
	var denied: Dictionary = Ledger.reserve(original, {"warmth": 2})
	expect(not denied.ok and denied.balance == original, "insufficient reservation is atomic")
	expect(not Ledger.reserve(original, {"wood": -1}).ok, "negative costs rejected")
	expect(Ledger.reserve(original, cost) == reservation, "same state and command are deterministic")
	var save_service := root.get_node("SaveService")
	var test_path := "user://d0-test-save.json"
	expect(save_service.write_snapshot({"day": 1}, {"volume": 0.5}, test_path) == OK, "snapshot write succeeds")
	expect(save_service.read_snapshot(test_path).state.day == 1, "versioned snapshot round-trips")
	var broken := FileAccess.open(test_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	expect(save_service.read_snapshot(test_path).is_empty(), "corrupt save returns safely to title")
	expect(not FileAccess.file_exists(test_path), "corrupt save moved out of active slot")
	var user_dir := DirAccess.open("user://")
	for filename: String in user_dir.get_files():
		if filename.begins_with("d0-test-save.json"):
			user_dir.remove(filename)
	print("D0 rule/service tests: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
