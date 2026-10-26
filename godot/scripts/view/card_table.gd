extends "res://scripts/view/table_ui.gd"
const Rules = preload("res://scripts/core/day_rules.gd")
const Loader = preload("res://scripts/content/data_loader.gd")
const Token = preload("res://scripts/view/resident_token.gd")
const ReturnZone = preload("res://scripts/view/return_zone.gd")
const Card = preload("res://scripts/view/location_card.gd")
var defs: Dictionary = {}
var state: Dictionary = {}
var screen: Control
var modal: Control
var preview_box: Control
var selected := ""
var replacing := ""
var hovered := ""
var locked := false
var short_night := false
var night_events: Array = []
var night_index := 0
var night_result: Dictionary = {}
var status := "小烬：把人物拖到地点，先看看，再决定。"
var cards: Dictionary = {}
var mode := "case"
var save_enabled := true

func _ready() -> void:
	setup_theme()
	defs = Loader.load_defs()
	show_case()

func clear_screen() -> void:
	if is_instance_valid(screen):
		remove_child(screen)
		screen.queue_free()
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
	preview_box = null
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	panel(screen, Rect2(0, 0, 640, 360), INK, INK)

func show_case() -> void:
	mode = "case"
	clear_screen()
	label(screen, "卷轴匣 · 一副山谷", Rect2(80, 45, 480, 32), GOLD)
	label(screen, "第一卷　河湾\n让老水磨重新转起来。\n\n第二卷　磨坊坡 · 尚未开启", Rect2(80, 100, 480, 110))
	button(screen, "展开第一卷", Rect2(80, 240, 150, 30), show_intro)
	button(screen, "继续 · 清晨存档", Rect2(250, 240, 190, 30), continue_game)
	button(screen, "返回标题", Rect2(460, 240, 100, 30), func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	label(screen, "D1 灰盒 · 图形与演出将在后续制作", Rect2(80, 300, 500, 20), MUTED)

func show_intro() -> void:
	mode = "intro"
	clear_screen()
	label(screen, "第一卷 · 河湾", Rect2(80, 45, 480, 26), GOLD)
	label(screen, story_text("story.intro"), Rect2(80, 90, 480, 190), PAPER, true)
	button(screen, "把牌摆开", Rect2(240, 302, 160, 28), start_game)

func start_game() -> void:
	if not defs.has("residents"):
		status = "内容未准备好，无法开始。"
		show_notice(status)
		return
	state = Rules.new_game(defs)
	_save_dawn()
	render_table()

func continue_game() -> void:
	state = SaveService.load_game(defs)
	if state.is_empty():
		show_notice(SaveService.last_error if not SaveService.last_error.is_empty() else "还没有清晨存档。")
		return
	if state.get("chapter_complete", false) and not state.get("ending_seen", false):
		show_ending()
	else:
		render_table()

func _save_dawn() -> void:
	if save_enabled and SaveService.write_dawn(state, {"short_night": short_night}) != OK:
		status = "清晨存档未写入，请不要退出。"

func record(collection: String, id: String) -> Dictionary:
	for item: Dictionary in defs.get(collection, []):
		if item.get("id") == id:
			return item
	return {}

func display_name(id: String) -> String:
	if state.has("locations") and state.locations.has(id) and state.locations[id].state in ["fog", "hidden"]:
		return "雾中的牌"
	for collection: String in ["residents", "locations", "events", "visitors", "combos", "spells"]:
		var item := record(collection, id)
		if not item.is_empty():
			return item.get("name", item.get("label", id))
	return id

func render_table() -> void:
	mode = "table"
	clear_screen()
	cards.clear()
	# Twelve true slots at 72x88; no overlapping oversized placeholder cards.
	button(screen, "山谷长卷 · 点击展开　　D1 灰盒", Rect2(6, 4, 628, 26), show_panorama)
	var all_locations: Array = defs.get("locations", [])
	for loc: Dictionary in all_locations:
		var mutable: Dictionary = state.locations[loc.id]
		var slot: Array = loc.slot
		var x := 8 + int(slot[1]) * 76
		var y := 60 + int(slot[0]) * 96
		if mutable.state == "hidden":
			panel(screen, Rect2(x, y, 72, 88), Color("24242d"), Color("383744"))
			continue
		var card := Card.new()
		card.board = self
		card.location_id = loc.id
		card.position = Vector2(x, y)
		card.size = Vector2(72, 88)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = ("雾中的牌" if mutable.state == "fog" else loc.name) + "\n" + state_word(mutable.state) + ("\n暂时被淹" if mutable.get("blocked_until_day", 0) >= state.day else "")
		card.add_theme_color_override("font_color", PAPER)
		var style := StyleBoxFlat.new()
		style.bg_color = {"fog": Color("373348"), "frozen": Color("42617b"), "thawed": Color("343946"), "restored": Color("294b37")}.get(mutable.state, INK)
		style.border_color = MUTED
		style.set_border_width_all(1)
		card.add_theme_stylebox_override("normal", style)
		card.pressed.connect(choose_location.bind(loc.id))
		card.mouse_entered.connect(show_preview.bind(loc.id))
		screen.add_child(card)
		cards[loc.id] = card
		if loc.id == "loc.pines":
			var picture := TextureRect.new()
			picture.texture = AssetCatalog.texture("locart.pines.spring" if mutable.state == "restored" else "locart.pines.winter")
			picture.position = Vector2(x + 4, y + 2)
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.size = Vector2(64, 24)
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			screen.add_child(picture)
			picture.size = Vector2(32, 24)
			picture.position.x = x + 20
		if not mutable.progress.is_empty():
			var values: Array = []
			for key: String in mutable.progress:
				values.append(str(mutable.progress[key]))
			label(screen, "进度 " + "/".join(values), Rect2(x + 3, y + 61, 68, 14), GOLD)
		var local: Array = []
		for assignment: Dictionary in state.assignments:
			if assignment.location_id == loc.id:
				local.append(assignment)
		for index in local.size():
			var assignment: Dictionary = local[index]
			make_token(assignment.resident_id, assignment.id, Rect2(x + index * 23, y + 72, 24, 16), true)
	label(screen, "第 %d 天　木 %s　石 %s　暖意 %s" % [state.day, resource_text("wood"), resource_text("stone"), resource_text("warmth")], Rect2(8, 34, 450, 22))
	build_sidebar()
	var hand := ReturnZone.new()
	hand.board = self
	hand.position = Vector2(4, 258)
	hand.size = Vector2(464, 50)
	screen.add_child(hand)
	var index := 0
	for resident: Dictionary in defs.get("residents", []):
		if not resident.get("playable", true):
			continue
		var current: Dictionary = state.residents[resident.id]
		if current.status != "awake":
			if state.day == 1 and resident.id in ["res.toby", "res.mira"]:
				button(screen, "焐醒" + resident.name, Rect2(8 + index * 78, 263, 74, 40), awaken_tutorial.bind(resident.id))
				index += 1
			continue
		var assignment_id := ""
		for assignment: Dictionary in state.assignments:
			if assignment.resident_id == resident.id:
				assignment_id = assignment.id
		var assigned_count := 0
		for assignment: Dictionary in state.assignments:
			if assignment.resident_id == resident.id:
				assigned_count += 1
		if state.day_modifiers.get("two_actions_resident", "") == resident.id and assigned_count < 2:
			assignment_id = ""
		make_token(resident.id, assignment_id, Rect2(8 + index * 78, 263, 74, 40))
		index += 1
	button(screen, "冬眠诀", Rect2(400, 263, 62, 40), show_spells)
	button(screen, "入夜", Rect2(478, 263, 70, 40), begin_night)
	button(screen, "暂停", Rect2(554, 263, 78, 40), show_pause)
	label(screen, status, Rect2(8, 311, 624, 38), GOLD, true)
	update_highlights()

func state_word(value: String) -> String:
	return {"fog": "探路翻开", "frozen": "霜封", "thawed": "解冻", "restored": "回春"}.get(value, value)

func resource_text(resource: String) -> String:
	var reserved := 0
	for assignment: Dictionary in state.assignments:
		reserved += int(assignment.get("escrow", {}).get(resource, 0))
	return "%d→%d" % [state.resources[resource] + reserved, state.resources[resource]] if reserved > 0 else str(int(state.resources[resource]))

func build_sidebar() -> void:
	panel(screen, Rect2(470, 34, 164, 222))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(476, 38)
	scroll.size = Vector2(154, 212)
	screen.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 140
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "让老水磨转起来"
	column.add_child(heading)
	for goal: Dictionary in defs.get("goals", []):
		var row := Button.new()
		row.text = ("✓ " if state.goal_steps.get(goal.id, false) else "□ ") + goal.label
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(140, 28)
		row.tooltip_text = goal.get("hint", "")
		row.pressed.connect(func(): show_notice(goal.get("hint", goal.label)))
		row.mouse_entered.connect(highlight_related.bind(goal.get("related_locations", [])))
		column.add_child(row)
	for active: Dictionary in state.active_events:
		var event := record("events", active.id)
		if event.is_empty():
			event = record("visitors", active.id)
		var row := Button.new()
		row.text = "%s · %d天\n%s\n成：%s\n逾：%s" % [event.get("name", active.id), active.remaining, event.get("requirement_text", ""), event.get("done_text", ""), event.get("expire_text", "")]
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size = Vector2(140, 90)
		row.pressed.connect(func(): show_notice(row.text))
		row.mouse_entered.connect(highlight_related.bind(event.get("related_locations", [])))
		column.add_child(row)

func make_token(id: String, assignment_id: String, rect: Rect2, compact: bool = false) -> void:
	var token := Token.new()
	token.board = self
	token.resident_id = id
	token.assignment_id = assignment_id
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("4a5f7a") if style_name == "hover" else Color("293448")
		style.border_color = GOLD if style_name == "focus" else MUTED
		style.set_border_width_all(1)
		style.set_content_margin_all(0)
		token.add_theme_stylebox_override(style_name, style)
	token.text = display_name(id).left(1) if compact else display_name(id) + ("\n已分派" if not assignment_id.is_empty() else "\n拖到地点")
	token.position = rect.position
	token.size = rect.size
	token.pressed.connect(select_resident.bind(id, assignment_id))
	screen.add_child(token)
	token.size = rect.size

func select_resident(id: String, assignment_id: String = "") -> void:
	if locked:
		return
	selected = id
	replacing = assignment_id
	AudioService.unlock()
	AudioService.play_sfx("sfx.card_drop")
	update_highlights()

func can_place(id: String, loc: String, old: String = "") -> bool:
	if locked:
		return false
	var preview: Dictionary = Rules.preview(state, id, loc, old)
	for use: Dictionary in preview.get("uses", []):
		if use.get("enabled", false):
			return true
	return false

func update_highlights() -> void:
	for id: String in cards:
		cards[id].modulate = Color.WHITE if selected.is_empty() or can_place(selected, id, replacing) else Color(0.5, 0.5, 0.5)

func highlight_related(ids: Array) -> void:
	if not selected.is_empty():
		return
	for id: String in cards:
		cards[id].modulate = Color.WHITE if id in ids else Color(0.6, 0.6, 0.6)

func show_preview(loc: String) -> void:
	if selected.is_empty() or locked:
		return
	hovered = loc
	var preview: Dictionary = Rules.preview(state, selected, loc, replacing)
	var lines := display_name(selected) + " → " + display_name(loc)
	for use: Dictionary in preview.get("uses", []):
		lines += "\n" + use_text(use)
	if is_instance_valid(preview_box):
		preview_box.queue_free()
	preview_box = panel(screen, Rect2(20, 165, 430, 90), INK, GOLD)
	label(preview_box, lines, Rect2(8, 6, 412, 78), PAPER, true)

func amounts(values: Dictionary) -> String:
	var chunks: PackedStringArray = []
	for resource: String in ["wood", "stone", "warmth"]:
		if values.get(resource, 0) != 0:
			chunks.append("%s%d" % [{"wood": "木", "stone": "石", "warmth": "暖意"}[resource], values[resource]])
	return " ".join(chunks)

func use_text(use: Dictionary) -> String:
	var text: String = use.get("label", use.id)
	if not use.get("cost", {}).is_empty():
		text += "　付 " + amounts(use.cost)
	if not use.get("gain", {}).is_empty():
		text += "　得 " + amounts(use.gain)
	if use.get("combo_hint", false):
		text += "　✦ 新鲜事"
	if not use.get("cost", {}).is_empty() and not use.get("remaining", {}).is_empty():
		text += "　剩 " + amounts(use.remaining)
	if not use.get("enabled", false):
		text += "　" + reason(use.get("blocked_reason", "requirements_unmet"))
	return text

func reason(code: String) -> String:
	return {"insufficient_resource": "资源不够", "action_limit": "今天已分派", "wrong_resident": "需要别的伙伴", "requirements_unmet": "条件未满足", "location_flooded": "暂时被淹", "fog_occupied": "已有伙伴探路", "location_full": "地点已满", "progress_complete": "已经完成", "resident_frozen": "还未醒来", "same_location": "不能重复同地"}.get(code, code)

func choose_location(loc: String) -> void:
	if locked or selected.is_empty():
		return
	var preview: Dictionary = Rules.preview(state, selected, loc, replacing)
	open_modal("选择用法 · " + display_name(loc))
	var y := 80
	for use: Dictionary in preview.get("uses", []):
		var option := button(modal, use_text(use), Rect2(50, y, 540, 34), confirm_use.bind(loc, use.id, int(preview.revision)))
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.disabled = not use.get("enabled", false)
		y += 38
	button(modal, "取消 · 不扣资源", Rect2(220, 294, 200, 28), close_modal)

func confirm_use(loc: String, use_id: String, revision: int) -> void:
	if revision != int(state.revision):
		show_notice("状态已变化，请重新选择。")
		return
	var result: Dictionary = Rules.assign(state, selected, loc, use_id, replacing)
	status = display_name(selected) + "：好，晚上见。" if result.ok else reason(result.reason_code)
	selected = ""
	replacing = ""
	AudioService.play_sfx("sfx.card_drop")
	render_table()

func cancel_assignment(id: String) -> void:
	if locked or id.is_empty():
		return
	var result: Dictionary = Rules.unassign(state, id)
	status = "已撤销，预扣资源全数退回。" if result.ok else reason(result.reason_code)
	selected = ""
	replacing = ""
	render_table()

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and not data.get("assignment", "").is_empty()
func _drop_data(_position: Vector2, data: Variant) -> void:
	cancel_assignment(data.assignment)

func awaken_tutorial(id: String) -> void:
	var result: Dictionary = Rules.tutorial_awaken(state, id)
	status = display_name(id) + "醒来了！今天的教学不消耗暖意。" if result.ok else reason(result.reason_code)
	_save_dawn()
	render_table()

func open_modal(title: String) -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	panel(modal, Rect2(26, 32, 588, 302), INK, GOLD)
	label(modal, title, Rect2(50, 48, 540, 24), GOLD)
func close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
func show_notice(text: String) -> void:
	open_modal("小烬说")
	label(modal, text, Rect2(50, 90, 540, 180), PAPER, true)
	button(modal, "知道了", Rect2(240, 294, 160, 28), close_modal)

func show_pause() -> void:
	if locked:
		return
	open_modal("暂停 · 退出后回到本日清晨")
	button(modal, "继续", Rect2(200, 90, 240, 28), close_modal)
	button(modal, "夜间：" + ("简短" if short_night else "正常"), Rect2(200, 132, 240, 28), func(): short_night = not short_night; show_pause())
	button(modal, "主音量开关", Rect2(200, 174, 240, 28), func(): AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0)))
	button(modal, "全屏开关", Rect2(200, 216, 240, 28), func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	button(modal, "回到卷轴匣", Rect2(200, 270, 240, 28), show_case)

func show_spells() -> void:
	open_modal("冬眠诀 · 当天生效，一次使用")
	var y := 88
	for id: String in state.spell_inventory:
		var spell := record("spells", id)
		if spell.get("effect") == "two_actions":
			for resident: Dictionary in defs.get("residents", []):
				if resident.get("playable", true) and state.residents[resident.id].status == "awake":
					button(modal, display_name(id) + " → " + resident.name, Rect2(80, y, 480, 26), cast_spell.bind(id, resident.id))
					y += 28
		else:
			button(modal, display_name(id), Rect2(80, y, 480, 26), cast_spell.bind(id, ""))
			y += 28
	button(modal, "取消", Rect2(240, 298, 160, 26), close_modal)
func cast_spell(id: String, target: String) -> void:
	var result: Dictionary = Rules.use_spell(state, id, target)
	status = "冬眠诀已用，今天生效。" if result.ok else reason(result.reason_code)
	render_table()

func begin_night() -> void:
	if locked:
		return
	if state.day == 1 and (state.residents["res.toby"].status != "awake" or state.residents["res.mira"].status != "awake"):
		show_notice("先点击人物牌，免费焐醒托比和米拉。
这是第一天的教学，不消耗暖意或行动。")
		return
	locked = true
	selected = ""
	night_result = Rules.end_day(state)
	if not night_result.ok:
		locked = false
		show_notice(reason(night_result.reason_code))
		return
	night_events = night_result.get("events", [])
	night_index = 0
	_save_dawn()
	play_next_event()

func play_next_event() -> void:
	if night_index >= night_events.size():
		show_summary()
		return
	var event: Dictionary = night_events[night_index]
	night_index += 1
	open_modal("夜里 · %d / %d" % [night_index, night_events.size()])
	label(modal, event_text(event), Rect2(60, 104, 520, 150), PAPER, true)
	button(modal, "下一条", Rect2(100, 288, 180, 30), play_next_event)
	button(modal, "跳过演出 → 小结", Rect2(310, 288, 230, 30), show_summary)
	if short_night:
		var expected := night_index
		await get_tree().create_timer(0.12).timeout
		if locked and night_index == expected and night_index <= night_events.size():
			play_next_event()

func story_text(id: String) -> String:
	var story := record("pages", id)
	var lines: PackedStringArray = []
	for page: Dictionary in story.get("pages", []):
		lines.append(page.get("text", ""))
	return "\n\n".join(lines) if not lines.is_empty() else "柏翁的笔记还留在桌上。"

func event_text(event: Dictionary) -> String:
	var payload: Dictionary = event.get("payload", {})
	var kind: String = event.get("type", "")
	if kind == "gain":
		return "收获：" + amounts({payload.get("res", ""): payload.get("n", 0)})
	if kind == "resolve":
		return display_name(payload.get("resident_id", "")) + "在" + display_name(payload.get("location_id", "")) + "忙了一天。"
	if kind == "combo":
		var combo := record("combos", payload.get("id", ""))
		var line: Variant = combo.get("line", {})
		return "新鲜事 ✦\n" + (line.get("text", "") if line is Dictionary else str(line))
	if kind in ["reveal", "flip", "thaw", "restore"]:
		return display_name(payload.get("loc", "")) + {"reveal": "出现在桌上。", "flip": "从雾里显出了轮廓。", "thaw": "的霜化开了。", "restore": "回春了，长卷又绿了一段。"}[kind]
	if kind == "awaken":
		return display_name(payload.get("resident", "")) + "醒来了。明天一起出发。"
	if kind == "story":
		return story_text(payload.get("id", ""))
	if kind.begins_with("event_"):
		var event_def := record("events", payload.get("id", ""))
		if event_def.is_empty():
			event_def = record("visitors", payload.get("id", ""))
		return event_def.get("name", "事件") + "\n" + event_def.get({"event_done": "done_text", "event_expire": "expire_text"}.get(kind, "requirement_text"), "暂时停下倒计时。")
	return {"story": "柏翁的笔记：春天来了，把牌一张张摆开。", "night_empty": "今晚没有分派。休息也没关系。", "summary": "一天过去了，新的清晨就在前面。", "dawn": "晨光照进山谷。", "chapter_complete": "水轮转起来了！", "progress": "大家的工作又向前一步。", "goal_step": "水磨的一步完成了。", "flood": "水涨起来了。过几天就会退去。", "flood_end": "水退了，河滩露了出来。"}.get(kind, "山谷里又有了一点变化。")

func show_summary() -> void:
	night_index = night_events.size() + 1
	open_modal("一日小结 · 第 %d 天清晨" % state.day)
	var texts: PackedStringArray = []
	for event: Dictionary in night_events:
		if event.get("type") in ["combo", "awaken", "restore", "event_done", "event_expire", "goal_step"]:
			texts.append(event_text(event).replace("\n", " "))
	label(modal, "木 %d　石 %d　暖意 %d\n\n" % [state.resources.wood, state.resources.stone, state.resources.warmth] + "\n".join(texts).left(300), Rect2(50, 85, 540, 190), PAPER, true)
	button(modal, "继续", Rect2(240, 294, 160, 28), finish_night)
func finish_night() -> void:
	locked = false
	if state.get("chapter_complete", false) and not state.get("ending_seen", false):
		show_ending()
	else:
		render_table()
func show_ending() -> void:
	mode = "ending"
	clear_screen()
	label(screen, "第一卷 · 河湾　完", Rect2(70, 40, 500, 30), GOLD)
	label(screen, "水轮吱呀一声开始转，冰碴从水槽里冲出来。\n\n谷叔揉着眼睛，小粟抱住他的腿：\n“爹，你胡子上有冰。”\n\n小烬：老头子，你看见没？\n桌上半页笔记写着：对岸的灯，替我——\n\n第二卷 · 磨坊坡　未完待续", Rect2(70, 85, 500, 200), PAPER, true)
	button(screen, "继续在山谷里待着", Rect2(140, 300, 220, 30), freeplay)
	button(screen, "回卷轴匣", Rect2(390, 300, 120, 30), func(): freeplay(); show_case())
func freeplay() -> void:
	state.ending_seen = true
	state.phase = "day"
	state.dawn_snapshot = SaveService._serializable(state)
	_save_dawn()
	render_table()
func show_panorama() -> void:
	open_modal("山谷长卷 · 真实回春成果（灰盒）")
	var index := 0
	for loc: Dictionary in defs.get("locations", []):
		var restored: bool = state.locations[loc.id].state == "restored"
		var x := 50 + (index % 6) * 90
		var y := 100 + (index / 6) * 76
		panel(modal, Rect2(x, y, 84, 64), Color("294b37") if restored else Color("42617b"))
		label(modal, ("未发现" if state.locations[loc.id].state == "hidden" else loc.name) + "\n" + ("春" if restored else "冬"), Rect2(x + 4, y + 8, 80, 48))
		index += 1
	button(modal, "回到牌桌", Rect2(240, 294, 160, 28), close_modal)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not locked:
		selected = ""
		replacing = ""
		close_modal()
		update_highlights()
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(modal) and not locked:
				close_modal()
			elif mode == "table":
				show_pause()
		elif event.keycode == KEY_N and mode == "table" and not is_instance_valid(modal):
			begin_night()
		elif event.keycode == KEY_BACKSPACE and not replacing.is_empty():
			cancel_assignment(replacing)
