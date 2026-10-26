extends Control
const PAPER := Color("e8dcc0")
const MUTED := Color("d4a06c")
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
	var style: StyleBox = skin("ui.panel.wood")
	if style == null:
		style = StyleBoxFlat.new()
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
		node.clip_text = true
	parent.add_child(node)
	# Set bounds after inherited font/theme and wrapping remove the initial
	# unwrapped minimum width; otherwise long previews keep an oversized rect.
	node.size = rect.size
	return node
func button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_color_override("font_color", PAPER)
	node.add_theme_color_override("font_disabled_color", MUTED)
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style: StyleBox = skin("ui.panel.preview" if state_name in ["hover", "focus"] else "ui.panel.wood")
		if style == null:
			style = StyleBoxFlat.new()
			style.bg_color = Color("4a2f22")
			style.border_color = GOLD
			style.set_border_width_all(1)
		node.add_theme_stylebox_override(state_name, style)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func skin(id: String) -> StyleBoxTexture:
	if not AssetCatalog.has_art(id): return null
	var style := StyleBoxTexture.new()
	style.texture = AssetCatalog.texture(id)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 4)
		style.set_content_margin(side, 4)
	return style
func picture(parent: Node, id: String, position_at: Vector2, factor: int = 1, frame: int = 0) -> TextureRect:
	var node := TextureRect.new()
	node.texture = AssetCatalog.texture(id, frame)
	node.position = position_at
	if node.texture != null: node.size = node.texture.get_size() * maxi(1, factor)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
