extends Control
var board: Control
func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return not board.locked and data is Dictionary and not data.get("assignment", "").is_empty()
func _drop_data(_position: Vector2, data: Variant) -> void:
	board.cancel_assignment(data.assignment)
