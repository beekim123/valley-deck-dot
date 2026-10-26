extends "res://scripts/view/table_ui.gd"
var play_button: Button
func _ready() -> void:
	setup_theme()
	var settings_class := preload("res://scripts/view/settings_panel.gd")
	settings_class.apply_configuration(settings_class.read_values())
	picture(self, "still.valley_gate", Vector2.ZERO, 2)
	panel(self, Rect2(142, 52, 356, 112), INK, GOLD)
	var heading := label(self, "一副山谷", Rect2(160, 64, 320, 40), GOLD)
	heading.add_theme_font_size_override("font_size", 24)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := label(self, "第一卷 · 河湾\n春天来了，把牌一张张焐暖。", Rect2(156, 110, 328, 44), PAPER)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_button = button(self, "打开卷轴匣 · 开始 / 继续", Rect2(194, 222, 252, 36), start)
	button(self, "设置", Rect2(254, 268, 132, 28), show_settings)
	label(self, "没有战斗，没有失败。山谷会等你。", Rect2(190, 320, 300, 20), PAPER)
	AudioService.play_music("music.title")
func start() -> void:
	AudioService.unlock()
	get_tree().change_scene_to_file("res://scenes/card_table.tscn")
func show_settings() -> void:
	var settings := preload("res://scripts/view/settings_panel.gd").new()
	settings.name = "SettingsPanel"
	add_child(settings)
	settings.open({}, Callable())
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not has_node("SettingsPanel"): start()
