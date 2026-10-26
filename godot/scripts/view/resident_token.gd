extends Button
var board: Control
var resident_id := ""
var assignment_id := ""
func _get_drag_data(_position: Vector2) -> Variant:
	board.select_resident(resident_id, assignment_id)
	var ghost := Label.new()
	ghost.text = text
	ghost.add_theme_font_size_override("font_size", 12)
	set_drag_preview(ghost)
	return {"resident": resident_id, "assignment": assignment_id}
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		board.cancel_assignment(assignment_id)
		accept_event()
