extends "res://scripts/view/table_ui.gd"
## UI-owned modal. Content and predicates stay outside presentation state.
signal completed
signal blocked(reason: String)
const Data = preload("res://scripts/core/rule_data.gd")
var pages: Array = []
var page_index := 0
var active := false
var text_speed := 25.0
var blocked_reason := ""
var _done := Callable()
var _layers: Array = []
var _elapsed := 0.0
var _body: Control
var _caption: Label
var _tone_elapsed := 0.0
var _speaker := ""

func play(sequence: Variant, state: Dictionary, on_done: Callable = Callable()) -> void:
	setup_theme()
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_done = on_done
	pages.clear()
	blocked_reason = ""
	page_index = 0
	var record: Dictionary = sequence if sequence is Dictionary else Data.record(state.get("defs", {}), "pages", str(sequence))
	if record.is_empty():
		active = true
		show()
		_block("找不到剧情序列：" + str(sequence))
		return
	for page: Dictionary in record.get("pages", []):
		if not page.has("when") or Data.condition(state, page.when):
			pages.append(page)
	active = true
	show()
	if pages.is_empty():
		_finish()
		return
	for page: Dictionary in pages:
		if str(page.get("text", "")).length() > 50:
			_block("剧情文字超出50字：" + str(record.get("id", "")))
			return
		for layer: Dictionary in page.get("layers", []):
			if not AssetCatalog.has_art(str(layer.asset)):
				_block("缺少正式剧情素材：" + str(layer.asset))
				return
			if int(layer.get("frames", 1)) > int(AssetCatalog.metadata(str(layer.asset)).get("frames", 1)):
				_block("剧情素材帧数不足：" + str(layer.asset))
				return
	_show_page()

func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_layers.clear()

func _block(reason: String) -> void:
	blocked_reason = reason
	_clear()
	panel(self, Rect2(0, 0, 640, 360), Color("1e1a24"))
	label(self, "演出暂不可用\n" + reason + "\n请完成素材构建与同步后重试。", Rect2(100, 110, 440, 100), PAPER, true)
	blocked.emit(reason)

func _show_page() -> void:
	_clear()
	_elapsed = 0.0
	_tone_elapsed = 0.0
	var page: Dictionary = pages[page_index]
	var note: bool = page.get("layout", "") == "note"
	panel(self, Rect2(0, 0, 640, 360), Color("1e1a24"))
	panel(self, Rect2(156, 34, 328, 208 if note else 188), Color("493c3c"), GOLD)
	_body = Control.new()
	_body.position = Vector2(160, 38)
	_body.size = Vector2(320, 200 if note else 180)
	_body.clip_contents = true
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	for layer: Dictionary in page.get("layers", []):
		var texture := TextureRect.new()
		texture.texture = AssetCatalog.texture(str(layer.asset), 0)
		texture.position = Vector2(int(layer.get("x", 0)), int(layer.get("y", 0)))
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(texture)
		_layers.append({"node": texture, "data": layer, "origin": texture.position})
	_speaker = str(page.get("speaker", "narrator"))
	var names := {"narrator":"", "bo":"柏翁的笔记", "ember":"小烬", "peddler":"货郎", "res.anuan":"阿暖", "res.toby":"托比", "res.mira":"米拉", "res.mei":"老梅", "res.beavers":"大板牙", "res.mill_family":"磨坊一家"}
	if note:
		label(self, "柏翁的笔记", Rect2(326, 50, 142, 20), INK)
		_caption = label(self, str(page.text), Rect2(326, 80, 142, 150), INK, true)
	else:
		label(self, str(names.get(_speaker, _speaker)), Rect2(160, 232, 320, 20), GOLD)
		_caption = label(self, str(page.text), Rect2(160, 254, 320, 38), PAPER, true)
	_caption.visible_characters = 0
	label(self, "%d / %d  · 点击 / 空格 / 回车翻页" % [page_index + 1, pages.size()], Rect2(160, 308, 320, 20), MUTED)
	button(self, "跳过", Rect2(548, 14, 72, 28), skip)
	if AssetCatalog.has_audio("sfx.page_turn"):
		AudioService.play_sfx("sfx.page_turn")

func _process(delta: float) -> void:
	if not active or not blocked_reason.is_empty() or _caption == null:
		return
	_elapsed += delta
	var count := mini(str(pages[page_index].text).length(), int(_elapsed * text_speed) if text_speed > 0.0 else str(pages[page_index].text).length())
	if count > _caption.visible_characters:
		_caption.visible_characters = count
		_tone_elapsed += delta
		var tone := "talk." + _speaker.trim_prefix("res.")
		if _tone_elapsed >= 0.08 and _speaker not in ["narrator", "bo"] and AssetCatalog.has_audio(tone):
			AudioService.play_sfx(tone)
			_tone_elapsed = 0.0
	for entry: Dictionary in _layers:
		var layer: Dictionary = entry.data
		var frames := int(layer.get("frames", 1))
		entry.node.texture = AssetCatalog.texture(str(layer.asset), int(_elapsed * float(layer.get("fps", 2.0))) % maxi(frames, 1))
		var pan: Array = layer.get("pan", [0, 0])
		var amount := minf(_elapsed / 8.0, 1.0)
		entry.node.position = entry.origin + Vector2(roundi(int(pan[0]) * amount), roundi(int(pan[1]) * amount))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		advance()
		get_viewport().set_input_as_handled()

func advance() -> void:
	if not active or not blocked_reason.is_empty(): return
	if _caption.visible_characters < str(pages[page_index].text).length():
		_elapsed = maxf(_elapsed, float(str(pages[page_index].text).length()) / maxf(text_speed, 1.0))
		_caption.visible_characters = str(pages[page_index].text).length()
		return
	page_index += 1
	if page_index >= pages.size(): _finish()
	else: _show_page()

func skip() -> void:
	if active and blocked_reason.is_empty(): _finish()

func _finish() -> void:
	active = false
	hide()
	completed.emit()
	var callback := _done
	_done = Callable()
	if callback.is_valid(): callback.call()
