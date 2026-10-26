extends Control
## Authored textures only; pixel-cluster transition without scaling or rule writes.
var art := ""
var kind := "restore"
var elapsed := 0.0
var duration := 2.0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	elapsed += delta * (2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1)
	queue_redraw()
func _draw() -> void:
	var progress := minf(1.0, elapsed / duration)
	var winter := "locart." + art + ".winter"
	var spring := "locart." + art + ".spring"
	var rect := Rect2(0, 0, 256, 192)
	if kind == "flip" and progress < 0.5:
		draw_texture_rect(AssetCatalog.texture("card.loc_frame.fog"), Rect2(56, 8, 144, 176), false)
		return
	draw_texture_rect(AssetCatalog.texture(winter), rect, false)
	if kind == "restore":
		for row in 12:
			for col in 16:
				if float(posmod(col * 13 + row * 7, 16)) / 16.0 < progress:
					draw_texture_rect_region(AssetCatalog.texture(spring), Rect2(col * 16, row * 16, 16, 16), Rect2(col * 4, row * 4, 4, 4))
	elif kind == "thaw" and progress < 0.9:
		var frame := mini(2, int(progress * 4))
		draw_texture_rect(AssetCatalog.texture("fx.ice_crack", frame), Rect2(56, 0, 144, 192), false)
