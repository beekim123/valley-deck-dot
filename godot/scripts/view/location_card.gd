extends Button
var board: Control
var location_id := ""
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("resident"):
		return false
	board.show_preview(location_id)
	return not board.locked # Drop opens a preview/confirmation; disabled uses never assign.
func _drop_data(_position: Vector2, data: Variant) -> void:
	board.select_resident(data.resident, data.get("assignment", ""))
	board.choose_location(location_id)
