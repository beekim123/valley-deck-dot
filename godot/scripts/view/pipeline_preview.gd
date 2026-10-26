extends Control
## D0 asset-pipeline preview, not a fake playable chapter.
const PAPER := Color("e8dcc0")
const MUTED := Color("b9c6d3")
const INK := Color("1e1a24")
const GOLD := Color("f8c25c")
var spring := false
var season_label: Label
var quote_label: Label
var switch_button: Button
var winter_panel: Panel
var spring_panel: Panel
var winter_picture: TextureRect
var spring_picture: TextureRect
var music_button: Button
var music_started := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var font := AssetCatalog.pixel_font()
	var ui_theme := Theme.new()
	if font != null:
		ui_theme.default_font = font
	ui_theme.default_font_size = 12
	theme = ui_theme
	_build()
	_update_season()
	if "--shots" in OS.get_cmdline_user_args():
		_capture_sequence.call_deferred()

func _panel(rect: Rect2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func _label(text: String, rect: Rect2, color: Color = PAPER, font_size: int = 12, centered: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _picture(id: String, rect: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = AssetCatalog.texture(id)
	picture.position = rect.position
	picture.size = rect.size
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture

func _button(text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.position = rect.position
	button.size = rect.size
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if state == "hover" else PAPER
		style.border_color = GOLD if state == "focus" else Color("a8714a")
		style.set_border_width_all(1)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build() -> void:
	_panel(Rect2(0, 0, 640, 360), INK, INK)
	_panel(Rect2(16, 16, 608, 328), Color("23283a"), Color("4a5f7a"))
	_label("第一卷 · 河湾", Rect2(30, 24, 580, 16), MUTED, 12, true)
	_label("一副山谷", Rect2(30, 44, 580, 32), PAPER, 24, true)
	_label("整座山谷冻在一副牌里。春天来了，把它一张张焐暖。", Rect2(30, 79, 580, 20), MUTED, 12, true)
	winter_panel = _panel(Rect2(50, 112, 220, 172), Color("2f4766"), Color("8fb4d6"))
	spring_panel = _panel(Rect2(370, 112, 220, 172), Color("1d3b2a"), Color("4f8f4f"))
	winter_picture = _picture("locart.pines.winter", Rect2(64, 120, 192, 144))
	spring_picture = _picture("locart.pines.spring", Rect2(384, 120, 192, 144))
	# Opaque caption panels keep text readable over both seasons.
	_panel(Rect2(50, 264, 220, 20), Color("2f4766"), Color("8fb4d6"))
	_panel(Rect2(370, 264, 220, 20), Color("1d3b2a"), Color("4f8f4f"))
	_label("松林 · 冬", Rect2(50, 264, 220, 20), PAPER, 12, true)
	_label("松林 · 春", Rect2(370, 264, 220, 20), PAPER, 12, true)
	_picture("portrait.toby", Rect2(280, 136, 80, 80))
	_label("托比", Rect2(280, 216, 80, 20), PAPER, 12, true)
	season_label = _label("", Rect2(272, 116, 96, 16), GOLD, 12, true)
	quote_label = _label("", Rect2(30, 284, 580, 16), PAPER, 12, true)
	switch_button = _button("看看春天", Rect2(150, 302, 156, 24), _switch_season)
	music_button = _button("试听春醒谣", Rect2(334, 302, 156, 24), _play_music)
	_button("打开卷轴匣 · 开始 / 继续", Rect2(194, 331, 252, 24), func(): get_tree().change_scene_to_file("res://scenes/card_table.tscn"))

func _switch_season() -> void:
	AudioService.unlock()
	spring = not spring
	AudioService.play_sfx("sfx.ice_crack" if spring else "sfx.card_drop")
	_update_season()

func _update_season() -> void:
	season_label.text = "回春" if spring else "长冬"
	quote_label.text = "托比：嗯……老伙计，春天到了。" if spring else "托比：……嗯？雪停了？"
	switch_button.text = "再看看冬天" if spring else "看看春天"
	var winter_style := winter_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var spring_style := spring_panel.get_theme_stylebox("panel") as StyleBoxFlat
	winter_style.border_color = Color("8fb4d6") if spring else GOLD
	spring_style.border_color = GOLD if spring else Color("4f8f4f")
	winter_style.set_border_width_all(1 if spring else 3)
	spring_style.set_border_width_all(3 if spring else 1)

func _play_music() -> void:
	AudioService.unlock()
	AudioService.play_sfx("sfx.card_drop")
	AudioService.play_music("music.test")
	music_started = true
	music_button.text = "再听一遍"

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_switch_season()
		get_viewport().set_input_as_handled()

func _capture_sequence() -> void:
	var destination := ProjectSettings.globalize_path("res://../artifacts/screenshots")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shots-dir="):
			destination = argument.trim_prefix("--shots-dir=")
	DirAccess.make_dir_recursive_absolute(destination)
	await RenderingServer.frame_post_draw
	await _capture(destination.path_join("d0-title-winter.png"))
	_switch_season()
	await RenderingServer.frame_post_draw
	await _capture(destination.path_join("d0-title-spring.png"))
	print("D0 screenshots: " + destination)
	AudioService.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()

func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	var error := image.save_png(path)
	if error != OK:
		push_error("Screenshot failed: " + str(error))
