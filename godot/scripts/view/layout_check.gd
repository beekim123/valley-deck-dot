extends SceneTree
## Guard against pre-theme minimum sizes growing controls beyond the 640x360 layout.
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)
func run() -> void:
	var table = load("res://scenes/card_table.tscn").instantiate()
	root.add_child(table)
	await process_frame
	table.save_enabled = false
	table.start_game()
	table.awaken_tutorial("res.toby")
	table.awaken_tutorial("res.mira")
	table.select_resident("res.toby")
	table.confirm_use("loc.pines", "chop", int(table.state.revision))
	await process_frame
	for child in table.screen.get_children():
		if child is TextureRect:
			check(child.size == Vector2(32, 24), "pine thumbnail has no card-name overlap")
		if child.get_script() == load("res://scripts/view/resident_token.gd"):
			if child.position.y < 250:
				check(child.size == Vector2(24, 16), "compact assignment badge stays inside card")
			else:
				check(child.size == Vector2(74, 40), "resident hand token fits above status")
		if child is Control:
			check(child.position.x + child.size.x <= 640 and child.position.y + child.size.y <= 360, "direct control stays in viewport")
	root.get_node("AudioService").stop_all()
	table.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("D1 layout checks: %d failures" % failures)
	quit(1 if failures else 0)
