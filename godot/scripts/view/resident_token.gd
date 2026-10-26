extends Button
var board: Control
var resident_id := ""
var assignment_id := ""
func _get_drag_data(_position: Vector2) -> Variant:
	board.select_resident(resident_id, assignment_id)
	var ghost := Panel.new()
	ghost.size = Vector2(74, 40)
	ghost.position = Vector2(8, 8)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frame := StyleBoxTexture.new()
	frame.texture = AssetCatalog.texture("card.res_frame")
	ghost.add_theme_stylebox_override("panel", frame)
	var face := TextureRect.new()
	face.texture = AssetCatalog.texture("portrait." + resident_id.trim_prefix("res."))
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(face)
	var caption := Label.new()
	caption.text = "海狸" if resident_id == "res.beavers" else board.display_name(resident_id)
	caption.position = Vector2(40, 10)
	caption.size = Vector2(34, 20)
	caption.add_theme_font_override("font", AssetCatalog.pixel_font())
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("1e1a24"))
	ghost.add_child(caption)
	set_drag_preview(ghost)
	return {"resident": resident_id, "assignment": assignment_id}
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		board.cancel_assignment(assignment_id)
		accept_event()

var target_location := ""
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if board.locked or not data is Dictionary or not data.has("resident"): return false
	if not target_location.is_empty():
		board.show_preview(target_location)
		return true
	return not str(data.get("assignment", "")).is_empty()
func _drop_data(_position: Vector2, data: Variant) -> void:
	if not target_location.is_empty():
		board.select_resident(str(data.resident), str(data.get("assignment", "")))
		board.choose_location(target_location)
	else:
		board.cancel_assignment(str(data.get("assignment", "")))
