extends "res://scripts/view/table_ui.gd"
## Cosmetic only: never charges warmth or changes resident state.
signal completed
signal blocked(reason: String)
const Story = preload("res://scripts/story/story_player.gd")
const Data = preload("res://scripts/core/rule_data.gd")
static var seen: Dictionary = {}
var active := false
var stage := -1
var blocked_reason := ""
var _elapsed := 0.0
var _resident := ""
var _state: Dictionary
var _done := Callable()
var _card: TextureRect
var _portrait: TextureRect
var _warm: TextureRect
var _ice: TextureRect
var _first: Label
var _status: Label
var _child: Control
var _can_accelerate := false
var _finished_animation := false

func play_awaken(resident_id: String, state: Dictionary, on_done: Callable = Callable()) -> void:
	setup_theme()
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resident = resident_id
	_state = state
	_done = on_done
	active = true
	stage = -1
	_elapsed = 0.0
	_finished_animation = false
	_child = null
	blocked_reason = ""
	_can_accelerate = seen.has(resident_id)
	show()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	panel(self, Rect2(0, 0, 640, 360), Color("1e1a24"))
	for id: String in ["big." + resident_id.trim_prefix("res."), "big." + resident_id.trim_prefix("res.") + ".memory", "fx.ice_crack", "fx.ice_shatter", "card.loc_frame.frozen", "card.loc_frame.thawed"]:
		if not AssetCatalog.has_art(id):
			blocked_reason = "缺少正式唤醒素材：" + id
			label(self, blocked_reason, Rect2(100, 130, 440, 70), PAPER, true)
			blocked.emit(blocked_reason)
			return
	if int(AssetCatalog.metadata("fx.ice_crack").get("frames", 0)) < 3 or int(AssetCatalog.metadata("fx.ice_shatter").get("frames", 0)) < 6:
		blocked_reason = "唤醒特效帧数不足：需要3帧冰裂与6帧碎冰。"
		label(self, blocked_reason, Rect2(100, 130, 440, 70), PAPER, true)
		blocked.emit(blocked_reason)
		return
	label(self, "阿暖把手按上霜牌，小烬的火苗沿着手臂流过去。", Rect2(100, 30, 440, 24), PAPER)
	_card = _picture("card.loc_frame.frozen", Vector2(284, 98))
	_portrait = _picture("big." + resident_id.trim_prefix("res.") + ".memory", Vector2(272, 94))
	_warm = _picture("big." + resident_id.trim_prefix("res."), Vector2(272, 94))
	_warm.modulate.a = 0.0
	_ice = _picture("fx.ice_crack", Vector2(284, 98))
	_ice.hide()
	_first = label(self, "", Rect2(140, 220, 360, 46), GOLD, true)
	_status = label(self, "冰正在融化……" if not _can_accelerate else "点击可加速", Rect2(240, 304, 200, 24), MUTED)

func _picture(id: String, at: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = AssetCatalog.texture(id)
	node.position = at
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func _process(delta: float) -> void:
	if not active or not blocked_reason.is_empty() or _finished_animation: return
	_elapsed += delta
	var next_stage := mini(stage + 1, mini(5, int(_elapsed / 0.55)))
	if next_stage != stage:
		stage = next_stage
		if stage in [1, 2, 3]:
			_ice.show()
			_ice.texture = AssetCatalog.texture("fx.ice_crack", mini(stage - 1, int(AssetCatalog.metadata("fx.ice_crack").get("frames", 1)) - 1))
			if AssetCatalog.has_audio("sfx.ice_crack"): AudioService.play_sfx("sfx.ice_crack")
		if stage == 4:
			_card.texture = AssetCatalog.texture("card.loc_frame.thawed")
			_ice.texture = AssetCatalog.texture("fx.ice_shatter")

			if AssetCatalog.has_audio("sfx.ice_shatter"): AudioService.play_sfx("sfx.ice_shatter")
		if stage == 5:
			_ice.hide()
			_finish_animation()
	if stage == 0:
		var offset := roundi(126 * (1.0 - clampf(_elapsed / 0.55, 0.0, 1.0)))
		_card.position.y = 98 + offset
		_portrait.position.y = 94 + offset
		_warm.position.y = 94 + offset
		_ice.position.y = 98 + offset
	elif stage < 4:
		_card.position.y = 98
		_portrait.position.y = 94
		_warm.position.y = 94
		_ice.position.y = 98
	if stage == 4:
		_ice.texture = AssetCatalog.texture("fx.ice_shatter", mini(5, int(clampf((_elapsed - 2.2) / 0.55, 0.0, 1.0) * 6)))
		_ice.modulate.a = 1.0 - clampf((_elapsed - 2.2) / 0.55, 0.0, 1.0)
		_warm.modulate.a = clampf((_elapsed - 2.2) / 0.55, 0.0, 1.0)
		_warm.position.y = 94 - roundi(sin(clampf((_elapsed - 2.2) / 0.55, 0.0, 1.0) * PI) * 8.0)

func _finish_animation() -> void:
	_finished_animation = true
	seen[_resident] = true
	_portrait.hide()
	_warm.modulate.a = 1.0
	_warm.position.y = 94
	var first_lines := {"res.toby":"……嗯？雪停了？", "res.mira":"兔子呢？！", "res.mei":"我的姜茶呢？凉了十年了吧。", "res.beavers":"……最后一根呢？？？", "res.mill_family":"水……水来了？"}
	_first.text = str(first_lines.get(_resident, "醒了。"))
	_status.text = "醒来了。"
	var tone := "talk." + _resident.trim_prefix("res.")
	if AssetCatalog.has_audio(tone): AudioService.play_sfx(tone)
	if not _memory_pages().is_empty():
		button(self, "看看回忆", Rect2(174, 272, 130, 28), _memory)
	button(self, "回到牌桌", Rect2(326, 272, 130, 28), _finish)

func _memory_pages() -> Array:
	var record := Data.record(_state.get("defs", {}), "pages", "story.wake." + _resident.trim_prefix("res."))
	var result: Array = []
	for page: Dictionary in record.get("pages", []):
		if page.get("layout", "") == "memory" or page.has("when"):
			if not page.has("when") or Data.condition(_state, page.when): result.append(page)
	return result

func _memory() -> void:
	if _child != null: return
	var memory := _memory_pages()
	if memory.is_empty():
		_finish()
		return
	_child = Story.new()
	add_child(_child)
	_child.blocked.connect(func(reason: String): blocked.emit(reason))
	_child.play({"id":"awaken.memory", "pages":memory}, _state, _finish)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _can_accelerate and not _finished_animation: _elapsed = maxf(_elapsed, 2.75)
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if active and _child == null and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		if _finished_animation and _child == null: _memory()
		elif _can_accelerate: _elapsed = maxf(_elapsed, 2.75)
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if not active: return
	active = false
	hide()
	completed.emit()
	var callback := _done
	_done = Callable()
	if callback.is_valid(): callback.call()
