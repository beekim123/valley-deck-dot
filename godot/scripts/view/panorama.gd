extends Control
## A clipped, continuous side-view ribbon. Rendering never mutates rule state.
signal opened
signal walker_clicked(resident_id: String)
const ORDER := ["pines", "tree_hole", "hut", "flower_slope", "herb_garden", "river_bend", "flood_beach", "misty_bank", "mill", "gravel", "old_bridge"]
var snapshot: Dictionary = {}
var offset := 0.0
var zoom := 1
var elapsed := 0.0
var transitions: Dictionary = {}
var ending_pan := false
var dragging := false
var drag_distance := 0.0
var walker_rects: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
func configure(state: Dictionary, scale_factor: int = 1) -> void:
	snapshot = state.duplicate(true)
	zoom = maxi(1, scale_factor)
	queue_redraw()
func restore_segment(id: String) -> void:
	transitions[id] = 0.0
func _process(delta: float) -> void:
	elapsed += delta
	for id: String in transitions.keys():
		transitions[id] = minf(1.0, float(transitions[id]) + delta / 2.0)
	if ending_pan: offset = minf(max_offset(), offset + delta * 65.0)
	queue_redraw()
func max_offset() -> float:
	return maxf(0, ORDER.size() * 128 * zoom - size.x)
func pan(amount: float) -> void:
	offset = clampf(offset + amount, 0, max_offset())
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("b9c6d3"))
	var y := int((size.y - 80 * zoom) / 2)
	for i in ORDER.size():
		var id: String = "loc." + ORDER[i]
		var status: String = snapshot.get("locations", {}).get(id, {}).get("state", "hidden")
		var rect := Rect2(i * 128 * zoom - int(offset), y, 128 * zoom, 80 * zoom)
		var winter: String = "pano." + ORDER[i] + ".winter"
		if AssetCatalog.has_art(winter): draw_texture_rect(AssetCatalog.texture(winter), rect, false)
		if status == "restored":
			var spring: String = "pano." + ORDER[i] + ".spring"
			if AssetCatalog.has_art(spring):
				# Hard-edged ordered dissolve preserves crisp pixel clusters.
				var progress := float(transitions.get(id, 1.0))
				var texture := AssetCatalog.texture(spring)
				if progress >= 1.0: draw_texture_rect(texture, rect, false)
				else:
					for row in 20:
						for col in 32:
							if float(posmod(col * 13 + row * 7, 16)) / 16.0 < progress:
								draw_texture_rect_region(texture, Rect2(rect.position + Vector2(col * 4, row * 4) * zoom, Vector2(4, 4) * zoom), Rect2(col * 4, row * 4, 4, 4))
		elif status in ["hidden", "fog"]:
			# Unknown segments are unmarked snow, not prematurely revealed buildings.
			draw_rect(rect, Color("b9c6d3"))
			draw_rect(Rect2(rect.position + Vector2(0, 48 * zoom), Vector2(128, 32) * zoom), Color("e9eef2"))
	walker_rects.clear()
	var index := 0
	for id: String in snapshot.get("residents", {}):
		if snapshot.residents[id].status != "awake": continue
		var suffix := id.trim_prefix("res.")
		var art := "walker." + suffix
		if not AssetCatalog.has_art(art): continue
		var segment := index % ORDER.size()
		for assignment: Dictionary in snapshot.get("assignments", []):
			if assignment.resident_id == id: segment = maxi(0, ORDER.find(str(assignment.location_id).trim_prefix("loc.")))
		var walk := int(elapsed * 8.0 + index * 19) % 88
		var rect := Rect2((segment * 128 + 12 + walk) * zoom - int(offset), y + 51 * zoom, 16 * zoom, 24 * zoom)
		draw_texture_rect(AssetCatalog.texture(art, int(elapsed * 6) % 4), rect, false)
		walker_rects[id] = rect
		index += 1
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			pan(-64 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 64)
			accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_distance = 0
			else:
				dragging = false
				if drag_distance < 4:
					for id: String in walker_rects:
						if walker_rects[id].has_point(event.position):
							walker_clicked.emit(id)
							return
					opened.emit()
	elif event is InputEventMouseMotion and dragging:
		pan(-event.relative.x)
		drag_distance += absf(event.relative.x)
