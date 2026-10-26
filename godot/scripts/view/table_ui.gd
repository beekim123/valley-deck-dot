extends Control
const PAPER := Color("e8dcc0")
const MUTED := Color("b9c6d3")
const INK := Color("1e1a24")
const GOLD := Color("f8c25c")
func setup_theme() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ui_theme := Theme.new()
	ui_theme.default_font = AssetCatalog.pixel_font()
	ui_theme.default_font_size = 12
	theme = ui_theme
func panel(parent: Node, rect: Rect2, fill: Color = Color("23283a"), border: Color = Color("4a5f7a")) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	node.add_theme_stylebox_override("panel", style)
	parent.add_child(node)
	return node
func label(parent: Node, text: String, rect: Rect2, color: Color = PAPER, wrap: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node
func button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_color_override("font_color", PAPER)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4a5f7a") if state_name == "hover" else Color("293448")
		style.border_color = GOLD if state_name == "focus" else Color("8fb4d6")
		style.set_border_width_all(1)
		node.add_theme_stylebox_override(state_name, style)
	node.pressed.connect(action)
	parent.add_child(node)
	return node
