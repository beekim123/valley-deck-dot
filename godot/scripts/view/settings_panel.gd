extends "res://scripts/view/table_ui.gd"
const PATH := "user://settings.json"
const DEFAULTS := {"master": 0.8, "music": 0.8, "sfx": 0.8, "text_speed": 25, "short_night": false, "window_scale": 2, "fullscreen": false}
var values: Dictionary = {}
var on_changed: Callable
static func read_values() -> Dictionary:
	var values := DEFAULTS.duplicate()
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file != null:
		var envelope: Variant = JSON.parse_string(file.get_as_text())
		if envelope is Dictionary and envelope.get("settings") is Dictionary:
			for key: String in DEFAULTS:
				if envelope.settings.has(key): values[key] = envelope.settings[key]
	for key: String in ["master", "music", "sfx"]:
		if not (values[key] is float or values[key] is int): values[key] = DEFAULTS[key]
		values[key] = clampf(float(values[key]), 0, 1)
	if values.text_speed is int or values.text_speed is float: values.text_speed = int(values.text_speed)
	if values.text_speed not in [0, 15, 25]: values.text_speed = 25
	if not (values.window_scale is int or values.window_scale is float): values.window_scale = 2
	values.window_scale = clampi(int(values.window_scale), 1, 3)
	if not values.short_night is bool: values.short_night = false
	if not values.fullscreen is bool: values.fullscreen = false
	return values
func open(current: Dictionary, callback: Callable) -> void:
	values = read_values() if current.is_empty() else current.duplicate()
	on_changed = callback
	setup_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply_values()
	render()
func apply_values() -> void:
	apply_configuration(values)
static func apply_configuration(values: Dictionary) -> void:
	AudioService.set_volumes(clampf(float(values.master), 0, 1), clampf(float(values.music), 0, 1), clampf(float(values.sfx), 0, 1))
	if DisplayServer.get_name() != "headless":
		var window := (Engine.get_main_loop() as SceneTree).root
		window.mode = Window.MODE_FULLSCREEN if values.fullscreen else Window.MODE_WINDOWED
		if not values.fullscreen:
			values.window_scale = clampi(int(values.window_scale), 1, maximum_window_scale())
			window.size = Vector2i(640, 360) * int(values.window_scale)
			window.move_to_center()
static func maximum_window_scale() -> int:
	if DisplayServer.get_name() == "headless": return 3
	var usable := DisplayServer.screen_get_usable_rect().size - Vector2i(0, 32)
	return clampi(mini(usable.x / 640, usable.y / 360), 1, 3)
func save() -> void:
	apply_values()
	SaveService.write_snapshot({}, values, PATH)
	if on_changed.is_valid(): on_changed.call(values.duplicate())
func render() -> void:
	for child in get_children(): child.queue_free()
	panel(self, Rect2(90, 24, 460, 312))
	label(self, "设置 · 随时慢下来", Rect2(112, 38, 400, 24), GOLD)
	var index := 0
	for key: String in ["master", "music", "sfx"]:
		label(self, {"master": "主音量", "music": "音乐", "sfx": "音效"}[key], Rect2(116, 74 + index * 30, 96, 24))
		var slider := HSlider.new()
		slider.position = Vector2(220, 76 + index * 30)
		slider.size = Vector2(260, 20)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = float(values[key])
		for style_name: String in ["slider", "grabber_area", "grabber_area_highlight"]:
			slider.add_theme_stylebox_override(style_name, skin("ui.panel.wood"))
		for icon_name: String in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(icon_name, AssetCatalog.texture("icon.warmth"))
		slider.value_changed.connect(func(value: float): values[key] = value; save())
		add_child(slider)
		index += 1
	button(self, "文字速度：" + ("立即" if int(values.text_speed) == 0 else ("慢" if int(values.text_speed) == 15 else "正常")), Rect2(112, 170, 196, 28), func(): values.text_speed = {25: 15, 15: 0, 0: 25}.get(int(values.text_speed), 25); save(); render())
	button(self, "夜间：" + ("简短" if values.short_night else "正常"), Rect2(326, 170, 196, 28), func(): values.short_night = not values.short_night; save(); render())
	button(self, "窗口：%d 倍" % int(values.window_scale), Rect2(112, 210, 196, 28), func(): values.window_scale = int(values.window_scale) % maximum_window_scale() + 1; save(); render())
	button(self, "全屏：" + ("开" if values.fullscreen else "关"), Rect2(326, 210, 196, 28), func(): values.fullscreen = not values.fullscreen; save(); render())
	button(self, "返回", Rect2(240, 280, 160, 28), queue_free)
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
