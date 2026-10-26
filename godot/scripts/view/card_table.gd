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
var night_initial_locations: Dictionary = {}
var status := "小烬：把人物拖到地点，先看看，再决定。"
var cards: Dictionary = {}
var mode := "case"
var save_enabled := true
const Panorama = preload("res://scripts/view/panorama.gd")
const Settings = preload("res://scripts/view/settings_panel.gd")
const StoryPlayer = preload("res://scripts/story/story_player.gd")
const AwakenDirector = preload("res://scripts/story/awaken_director.gd")
const BanterDirector = preload("res://scripts/story/banter_director.gd")
var settings: Dictionary = {}
var panorama: Control
var story_player: Control
var banter: Node
var keyboard_location := 0
var night_picture: TextureRect
var night_actor: TextureRect
var night_actor_art := ""
var night_art := ""
var night_clock := 0.0
var night_auto := false
var night_duration := 2.2
var night_generation := 0
var deco_counts: Dictionary = {}
var ember_sulk_day := -1
var deco_nodes: Dictionary = {}
var idle_clock := 0.0
var deco_poke_until: Dictionary = {}
var pending_restores: Array[String] = []
var banter_day := -1

func _ready() -> void:
	setup_theme()
	defs = Loader.load_defs()
	settings = Settings.read_values()
	Settings.apply_configuration(settings)
	short_night = bool(settings.short_night)
	banter = BanterDirector.new()
	add_child(banter)
	banter.bubble_requested.connect(_bubble)
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
	picture(screen, "board.table", Vector2.ZERO)

func show_case() -> void:
	mode = "case"
	locked = false
	clear_story()
	clear_screen()
	picture(screen, "still.hut", Vector2.ZERO, 2)
	panel(screen, Rect2(60, 40, 520, 268))
	label(screen, "柏翁的卷轴匣", Rect2(88, 58, 464, 32), GOLD)
	label(screen, "第一卷　河湾
让老水磨重新转起来。", Rect2(88, 106, 464, 52))
	label(screen, "第二卷　磨坊坡 · 尚未开启
纸条上只留下半句话：对岸的灯，替我——", Rect2(88, 168, 464, 48), MUTED)
	button(screen, "展开第一卷", Rect2(88, 244, 140, 32), show_intro)
	button(screen, "继续清晨存档", Rect2(240, 244, 158, 32), continue_game)
	button(screen, "返回标题", Rect2(410, 244, 140, 32), func(): get_tree().change_scene_to_file("res://scenes/title.tscn"))
	AudioService.play_music("music.title")

func show_intro() -> void:
	mode = "intro"
	clear_screen()
	play_story("story.intro", start_game)

func clear_story() -> void:
	if is_instance_valid(story_player):
		story_player.queue_free()
	story_player = null
func play_story(id: String, callback: Callable) -> void:
	clear_story()
	story_player = StoryPlayer.new()
	add_child(story_player)
	story_player.text_speed = int(settings.get("text_speed", 25))
	story_player.play(id, state if not state.is_empty() else {"defs": defs}, func(): clear_story(); callback.call())

func start_game() -> void:
	clear_story()
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
	if save_enabled and SaveService.write_dawn(state, settings) != OK:
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
	panorama = Panorama.new()
	panorama.position = Vector2(0, 0)
	panorama.size = Vector2(640, 80)
	screen.add_child(panorama)
	panorama.configure(state)
	panorama.opened.connect(show_panorama)
	panorama.walker_clicked.connect(func(id: String): status = display_name(id) + "：春天的路，慢慢走。"; _bubble(id, "春天的路，慢慢走。"))
	for id: String in pending_restores: panorama.restore_segment(id)
	pending_restores.clear()
	AudioService.set_restored_count(restored_count())
	AudioService.play_music("music.day")
	var all_locations: Array = defs.get("locations", [])
	for loc: Dictionary in all_locations:
		var mutable: Dictionary = state.locations[loc.id]
		var slot: Array = loc.slot
		var x := 8 + int(slot[1]) * 76
		var y := 104 + int(slot[0]) * 90
		if mutable.state == "hidden":
			picture(screen, "card.loc_frame.fog", Vector2(x, y)).modulate = Color(0.5, 0.5, 0.5)
			continue
		var card := Card.new()
		card.board = self
		card.location_id = loc.id
		card.position = Vector2(x, y)
		card.size = Vector2(72, 88)
		card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.text = ""
		for style_name: String in ["normal", "hover", "pressed", "focus"]:
			var frame := StyleBoxTexture.new()
			frame.texture = AssetCatalog.texture("card.loc_frame." + str(mutable.state))
			card.add_theme_stylebox_override(style_name, frame)
		card.pressed.connect(choose_location.bind(loc.id))
		card.mouse_entered.connect(show_preview.bind(loc.id))
		card.mouse_exited.connect(func(): banter.clear_hover())
		screen.add_child(card)
		cards[loc.id] = card
		if mutable.state != "fog":
			picture(card, "locart." + str(loc.id).trim_prefix("loc.") + (".spring" if mutable.state == "restored" else ".winter"), Vector2(4, 4))
			if mutable.state == "frozen":
				picture(card, "card.loc_frame.frozen", Vector2.ZERO)
		label(card, "雾中的牌" if mutable.state == "fog" else loc.name, Rect2(4, 51, 64, 16), PAPER if mutable.state == "fog" else INK)
		var state_label := state_word(mutable.state)
		if mutable.state == "frozen":
			var thaw_preview: Dictionary = Rules.preview(state, defs.balance.thaw_resident, loc.id)
			if not thaw_preview.uses.is_empty(): state_label += " " + amounts(thaw_preview.uses[0].cost)
		label(card, state_label, Rect2(4, 66, 64, 18), PAPER if mutable.state == "fog" else INK)
		if not mutable.progress.is_empty():
			panel(screen, Rect2(x + 2, y + 2, 68, 20))
			label(screen, progress_text(mutable.progress), Rect2(x + 5, y + 4, 62, 16), GOLD)
		var local: Array = []
		for assignment: Dictionary in state.assignments:
			if assignment.location_id == loc.id:
				local.append(assignment)
		for index in local.size():
			var assignment: Dictionary = local[index]
			make_token(assignment.resident_id, assignment.id, Rect2(x + index * 23, y + 34, 24, 16), true)
	panel(screen, Rect2(4, 80, 632, 23))
	label(screen, "第 %d 天　木 %s　石 %s　暖意 %s" % [state.day, resource_text("wood"), resource_text("stone"), resource_text("warmth")], Rect2(8, 82, 450, 20))
	build_sidebar()
	var hand := ReturnZone.new()
	hand.board = self
	hand.position = Vector2(4, 284)
	hand.size = Vector2(464, 44)
	screen.add_child(hand)
	var index := 0
	for resident: Dictionary in defs.get("residents", []):
		if not resident.get("playable", true):
			continue
		var current: Dictionary = state.residents[resident.id]
		if current.status != "awake":
			if state.day == 1 and resident.id in ["res.toby", "res.mira"]:
				button(screen, "焐醒" + resident.name, Rect2(8 + index * 78, 286, 74, 40), awaken_tutorial.bind(resident.id))
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
		make_token(resident.id, assignment_id, Rect2(8 + index * 78, 286, 74, 40))
		index += 1
	button(screen, "冬眠诀", Rect2(400, 286, 62, 40), show_spells)
	button(screen, "入夜", Rect2(478, 286, 70, 40), begin_night)
	button(screen, "暂停", Rect2(554, 286, 78, 40), show_pause)
	label(screen, status, Rect2(42, 332, 440, 26), GOLD, true)
	build_decorations()
	update_highlights()
	if banter_day != int(state.day):
		banter_day = int(state.day)
		banter.trigger("day_start", {"day": state.day}, state)

func progress_text(progress: Dictionary) -> String:
	var values: PackedStringArray = []
	for key: String in progress:
		var cap := int(defs.balance.get("progress_caps", {}).get(key, 0))
		if cap <= 0:
			push_error("Missing positive progress display cap: " + key)
			return "进度资料缺失"
		values.append("%d/%d" % [int(progress[key]), cap])
	return "进度 " + " ".join(values)

func state_word(value: String) -> String:
	return {"fog": "探路翻开", "frozen": "霜封", "thawed": "解冻", "restored": "回春"}.get(value, value)

func resource_text(resource: String) -> String:
	var reserved := 0
	for assignment: Dictionary in state.assignments:
		reserved += int(assignment.get("escrow", {}).get(resource, 0))
	return "%d→%d" % [state.resources[resource] + reserved, state.resources[resource]] if reserved > 0 else str(int(state.resources[resource]))

func build_sidebar() -> void:
	panel(screen, Rect2(470, 104, 164, 178))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(476, 108)
	scroll.size = Vector2(154, 170)
	screen.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 140
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "让老水磨转起来"
	column.add_child(heading)
	for goal: Dictionary in defs.get("goals", []):
		var row := Button.new()
		for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			row.add_theme_stylebox_override(style_name, skin("ui.panel.wood"))
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
		for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			row.add_theme_stylebox_override(style_name, skin("ui.panel.wood"))
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
	if compact:
		for assignment: Dictionary in state.assignments:
			if assignment.id == assignment_id: token.target_location = str(assignment.location_id)
	for style_name: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBox = skin("ui.panel.wood")
		style.set_content_margin_all(0)
		if not compact:
			style = StyleBoxTexture.new()
			style.texture = AssetCatalog.texture("card.res_frame")
		token.add_theme_stylebox_override(style_name, style)
	token.text = ""
	token.tooltip_text = display_name(id) + (" · 右键撤销" if compact else "")
	token.position = rect.position
	token.size = rect.size
	token.pressed.connect(select_resident.bind(id, assignment_id))
	screen.add_child(token)
	token.size = rect.size
	if compact:
		var crop := AtlasTexture.new()
		crop.atlas = AssetCatalog.texture("portrait." + id.trim_prefix("res."))
		crop.region = Rect2(8, 8, 24, 16)
		var face := TextureRect.new()
		face.texture = crop
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		token.add_child(face)
	else:
		picture(token, "portrait." + id.trim_prefix("res."), Vector2.ZERO)
		label(token, "海狸" if id == "res.beavers" else display_name(id), Rect2(40, 4, 34, 16), INK)
		label(token, "已派" if not assignment_id.is_empty() else "待命", Rect2(40, 22, 34, 14), INK)
		if not assignment_id.is_empty(): token.modulate = Color(0.75, 0.75, 0.75)

func select_resident(id: String, assignment_id: String = "") -> void:
	if locked:
		return
	selected = id
	replacing = assignment_id
	AudioService.unlock()
	AudioService.play_sfx("sfx.card_pick")
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
	banter.hover(selected, loc, state)
	var preview: Dictionary = Rules.preview(state, selected, loc, replacing)
	var lines := display_name(selected) + " → " + display_name(loc)
	for use: Dictionary in preview.get("uses", []):
		lines += "\n" + use_text(use)
	if is_instance_valid(preview_box):
		preview_box.queue_free()
	preview_box = panel(screen, Rect2(470, 104, 164, 178), INK, GOLD)
	label(preview_box, lines, Rect2(6, 6, 152, 166), PAPER, true)

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
	for outcome: Dictionary in use.get("outcomes", []):
		text += "\n" + outcome_text(outcome)
	if not use.get("enabled", false):
		text += "\n不可用：" + reason(use.get("blocked_reason", "requirements_unmet"))
		var args: Dictionary = use.get("reason_args", {})
		if args.has("have") and args.has("need"):
			text += "（%d/%d）" % [args.have, args.need]
	return text

func outcome_text(outcome: Dictionary) -> String:
	var payload: Dictionary = outcome.get("payload", {})
	match outcome.get("type", ""):
		"thaw": return "融开" + display_name(payload.loc) + "的霜"
		"awaken": return "唤醒" + display_name(payload.resident)
		"flip": return "翻开这张雾牌"
		"reveal": return "发现一张新地点"
		"progress": return "%s %d→%d/%d" % [{"wheel": "水轮", "dam": "筑坝", "haul": "清理"}.get(payload.key, "进度"), payload.before, payload.after, payload.max]
		"goal_step": return "目标：" + record("goals", payload.id).get("label", "完成一步")
		"restore": return display_name(payload.loc) + "回春"
		"grant_spell": return "获得" + display_name(payload.id)
		"story": return "读一段往事"
	return ""

func reason(code: String) -> String:
	return {"insufficient_resource": "资源不够", "action_limit": "今天已分派", "wrong_resident": "需要别的伙伴", "requirements_unmet": "条件未满足", "location_flooded": "暂时被淹", "fog_occupied": "已有伙伴探路", "location_full": "地点已满", "progress_complete": "已经完成", "resident_frozen": "还未醒来", "same_location": "不能重复同地"}.get(code, code)

func choose_location(loc: String) -> void:
	if locked or selected.is_empty():
		return
	var preview: Dictionary = Rules.preview(state, selected, loc, replacing)
	open_modal("选择用法 · " + display_name(loc))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(50, 78)
	scroll.size = Vector2(540, 208)
	modal.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 524
	scroll.add_child(column)
	var first_option: Button
	for use: Dictionary in preview.get("uses", []):
		var option := button(column, use_text(use), Rect2(0, 0, 524, 34), confirm_use.bind(loc, use.id, int(preview.revision)))
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.custom_minimum_size = Vector2(524, 34)
		option.disabled = not use.get("enabled", false)
		if not option.disabled and first_option == null: first_option = option
	var cancel := button(modal, "取消 · 不扣资源", Rect2(220, 294, 200, 28), close_modal)
	if first_option != null: first_option.grab_focus()
	else: cancel.grab_focus()

func confirm_use(loc: String, use_id: String, revision: int) -> void:
	if revision != int(state.revision):
		show_notice("状态已变化，请重新选择。")
		return
	var assigned_resident := selected
	var result: Dictionary = Rules.assign(state, selected, loc, use_id, replacing)
	status = display_name(selected) + "：好，晚上见。" if result.ok else reason(result.reason_code)
	selected = ""
	replacing = ""
	AudioService.play_sfx("sfx.card_drop" if result.ok else "sfx.ui_deny")
	render_table()
	if result.ok: banter.trigger("assign", {"resident_id": assigned_resident, "location_id": loc, "use_id": use_id}, state)

func cancel_assignment(id: String) -> void:
	if locked or id.is_empty():
		return
	var result: Dictionary = Rules.unassign(state, id)
	AudioService.play_sfx("sfx.card_return" if result.ok else "sfx.ui_deny")
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
	status = display_name(id) + "醒来了！教学免费，不耗暖意。" if result.ok else reason(result.reason_code)
	_save_dawn()
	render_table()
	if result.ok: play_awaken(id, func(): pass)

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
func clear_preview() -> void:
	banter.clear_hover()
	if is_instance_valid(preview_box):
		preview_box.queue_free()
	preview_box = null

func close_modal() -> void:
	clear_preview()
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
func show_notice(text: String) -> void:
	open_modal("小烬说")
	label(modal, text, Rect2(50, 90, 540, 180), PAPER, true)
	button(modal, "知道了", Rect2(240, 294, 160, 28), close_modal)

func show_pause() -> void:
	if locked: return
	open_modal("暂停 · 退出后回到本日清晨")
	button(modal, "继续", Rect2(200, 110, 240, 32), close_modal)
	button(modal, "设置", Rect2(200, 164, 240, 32), show_settings)
	button(modal, "回到卷轴匣", Rect2(200, 224, 240, 32), show_case)
func show_settings() -> void:
	var view := Settings.new()
	view.name = "SettingsPanel"
	add_child(view)
	view.open(settings, func(values: Dictionary): settings = values; short_night = bool(settings.short_night); _save_dawn())

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
	night_initial_locations = state.locations.duplicate(true)
	night_result = Rules.end_day(state)
	if not night_result.ok:
		locked = false
		show_notice(reason(night_result.reason_code))
		return
	AudioService.play_music("music.night")
	night_events = night_result.get("events", [])
	night_index = 0
	_save_dawn()
	play_next_event()

func play_next_event() -> void:
	night_auto = false
	night_art = ""
	night_picture = null
	night_actor = null
	night_actor_art = ""
	night_generation += 1
	if night_index >= night_events.size():
		show_summary()
		return
	var event: Dictionary = night_events[night_index]
	night_index += 1
	var payload: Dictionary = event.get("payload", {})
	var kind := str(event.get("type", ""))
	banter.trigger(kind, payload, state)
	if kind == "restore":
		pending_restores.append(str(payload.get("loc", "")))
		if is_instance_valid(panorama):
			panorama.snapshot.locations[payload.loc].state = "restored"
			panorama.restore_segment(str(payload.loc))
	if kind == "story":
		close_modal()
		play_story(str(payload.id), play_next_event)
		return
	if kind == "awaken":
		close_modal()
		play_awaken(str(payload.resident), play_next_event)
		return
	open_modal("夜里 · %d / %d" % [night_index, night_events.size()])
	night_clock = 0
	night_auto = true
	night_duration = 0.6 if short_night else 1.8
	if kind == "resolve":
		var suffix := str(payload.location_id).trim_prefix("loc.")
		var cue: String = {"chop": "sfx.chop", "stones": "sfx.stone_clink", "haul": "sfx.stone_clink", "chisel": "sfx.stone_clink", "gnaw": "sfx.beaver_gnaw", "build_dam": "sfx.beaver_gnaw", "repair_wheel": "sfx.hammer", "reinforce": "sfx.hammer", "fire": "sfx.fire_crackle", "brew": "sfx.fire_crackle", "driftwood": "sfx.splash"}.get(str(payload.use_id), "")
		if not cue.is_empty(): AudioService.play_sfx(cue)
		picture(modal, "portrait." + str(payload.resident_id).trim_prefix("res."), Vector2(80, 124), 2)
		label(modal, display_name(str(payload.resident_id)), Rect2(80, 208, 96, 20), GOLD)
		night_art = "locart." + suffix + ".anim." + str(payload.use_id)
		if str(payload.use_id) in ["explore", "thaw"]:
			night_art = ""
			mount_reveal(suffix, "flip" if str(payload.use_id) == "explore" else "thaw")
		else:
			if night_initial_locations.get(str(payload.location_id), {}).get("state", "thawed") != "restored": night_art += ".winter"
			night_picture = picture(modal, night_art, Vector2(192, 82), 4)
			night_actor_art = "walker." + str(payload.resident_id).trim_prefix("res.")
			night_actor = picture(modal, night_actor_art, Vector2(296, 162), 4, 4)
		night_clock = 0.0
		night_auto = true
		night_duration = 0.8 if short_night else 2.4
		label(modal, event_text(event), Rect2(60, 264, 520, 20), GOLD)
	elif kind in ["restore", "flip", "thaw"]:
		mount_reveal(str(payload.loc).trim_prefix("loc."), kind)
		label(modal, event_text(event), Rect2(60, 264, 520, 20), GOLD)
	else:
		label(modal, event_text(event), Rect2(60, 104, 520, 150), PAPER, true)
		if kind == "gain":
			var art := "icon." + str(payload.get("res", "warmth"))
			AudioService.play_sfx("sfx.gain_" + str(payload.get("res", "warmth")))
			var icon := picture(modal, art, Vector2(306, 200), 2)
			night_art = art
			night_picture = icon
			var tween := create_tween()
			tween.tween_method(func(value: Vector2): if is_instance_valid(icon): icon.position = value.round(), Vector2(306, 200), Vector2(80, 80), 0.6)
	button(modal, "下一条 / 按住加速", Rect2(80, 294, 220, 28), play_next_event)
	button(modal, "跳过演出 → 小结", Rect2(330, 294, 230, 28), show_summary)

func mount_reveal(suffix: String, kind: String) -> void:
	var reveal := preload("res://scripts/view/card_reveal.gd").new()
	reveal.name = "CardReveal"
	reveal.art = suffix
	reveal.kind = kind
	if kind == "flip": AudioService.play_sfx("sfx.card_flip")
	elif kind == "thaw": AudioService.play_sfx("sfx.ice_crack")
	reveal.position = Vector2(192, 82)
	reveal.size = Vector2(256, 192)
	reveal.duration = 0.6 if short_night else 2.0
	night_duration = reveal.duration + 0.2
	modal.add_child(reveal)

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
	night_auto = false
	night_art = ""
	night_picture = null
	night_actor = null
	night_actor_art = ""
	night_generation += 1
	clear_story()
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
	AudioService.play_music("music.ending")
	play_story("story.ending", ending_pan)
func ending_pan() -> void:
	clear_screen()
	panorama = Panorama.new()
	panorama.position = Vector2(0, 60)
	panorama.size = Vector2(640, 160)
	screen.add_child(panorama)
	panorama.configure(state, 2)
	panorama.ending_pan = true
	panel(screen, Rect2(60, 16, 520, 36))
	label(screen, "第一卷 · 河湾　完", Rect2(70, 24, 500, 30), GOLD)
	panel(screen, Rect2(60, 238, 520, 36))
	label(screen, "对岸的灯，替我——　　第二卷 · 磨坊坡　未完待续", Rect2(70, 246, 500, 24))
	button(screen, "继续在山谷里待着", Rect2(140, 300, 220, 30), freeplay)
	button(screen, "回卷轴匣", Rect2(390, 300, 120, 30), func(): freeplay(); show_case())
func freeplay() -> void:
	clear_story()
	state.ending_seen = true
	state.phase = "day"
	state.dawn_snapshot = SaveService._serializable(state)
	_save_dawn()
	render_table()
func show_panorama() -> void:
	open_modal("山谷长卷 · 拖动 / 滚轮 / 方向键左右看")
	var full := Panorama.new()
	full.name = "FullPanorama"
	full.position = Vector2(0, 90)
	full.size = Vector2(640, 160)
	modal.add_child(full)
	full.configure(state, 2)
	full.walker_clicked.connect(func(id: String): _bubble(id, "春天的路，慢慢走。"))
	button(modal, "←", Rect2(60, 294, 64, 28), func(): full.pan(-128))
	button(modal, "回到牌桌", Rect2(240, 294, 160, 28), close_modal)
	button(modal, "→", Rect2(516, 294, 64, 28), func(): full.pan(128))

func _input(event: InputEvent) -> void:
	if event is InputEventMouse or event is InputEventKey: idle_clock = 0
	if is_instance_valid(story_player) or has_node("SettingsPanel"): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not locked:
		selected = ""
		replacing = ""
		clear_preview()
		close_modal()
		update_highlights()
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_9 and mode == "table" and not locked and not is_instance_valid(modal):
			var available: Array = []
			for resident: Dictionary in defs.residents:
				if resident.get("playable", true) and state.residents[resident.id].status == "awake": available.append(resident.id)
			var index := int(event.keycode - KEY_1)
			if index < available.size():
				var old := ""
				for assignment: Dictionary in state.assignments:
					if assignment.resident_id == available[index]: old = assignment.id
				select_resident(available[index], old)
				keyboard_location = 0
				if not cards.is_empty(): cards[cards.keys()[0]].grab_focus()
				get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and mode == "table":
			if is_instance_valid(modal) and modal.has_node("FullPanorama"):
				modal.get_node("FullPanorama").pan(-128 if event.keycode in [KEY_LEFT, KEY_UP] else 128)
			elif not is_instance_valid(modal) and not cards.is_empty() and not selected.is_empty():
				keyboard_location = posmod(keyboard_location + (-1 if event.keycode in [KEY_LEFT, KEY_UP] else 1), cards.size())
				var loc: String = cards.keys()[keyboard_location]
				cards[loc].grab_focus()
				show_preview(loc)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_V and mode == "table" and not locked: show_panorama()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and locked:
			if night_index > night_events.size(): finish_night()
			else: play_next_event()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if is_instance_valid(modal) and not locked:
				close_modal()
			elif mode == "table":
				show_pause()
		elif event.keycode == KEY_N and mode == "table" and not is_instance_valid(modal):
			begin_night()
		elif event.keycode == KEY_BACKSPACE and not replacing.is_empty():
			cancel_assignment(replacing)

func restored_count() -> int:
	var count := 0
	for loc: Dictionary in state.get("locations", {}).values():
		if loc.state == "restored": count += 1
	return count

func play_awaken(id: String, callback: Callable) -> void:
	clear_story()
	story_player = AwakenDirector.new()
	add_child(story_player)
	story_player.play_awaken(id, state, func(): clear_story(); callback.call())

func _bubble(speaker: String, text: String) -> void:
	if int(state.get("day", 0)) == ember_sulk_day and speaker in ["ember", "res.ember"]: return
	status = ("小烬" if speaker in ["ember", "res.ember"] else display_name(speaker)) + "：" + text
	if mode == "table" and is_instance_valid(screen):
		var old := screen.get_node_or_null("BanterBubble")
		if old != null: old.queue_free()
		var bubble := panel(screen, Rect2(38, 328, 444, 30))
		bubble.name = "BanterBubble"
		label(bubble, status, Rect2(6, 3, 432, 24), GOLD, true)
		var timer := Timer.new()
		timer.one_shot = true
		bubble.add_child(timer)
		timer.timeout.connect(bubble.queue_free)
		timer.start(2.5 + text.length() * 0.08)

func build_decorations() -> void:
	deco_nodes.clear()
	var objects := {"ember": Vector2(10, 327), "teacup": Vector2(490, 328), "pipe": Vector2(528, 332), "clock": Vector2(438, 242)}
	for id: String in objects:
		var art := "char.ember" if id == "ember" else "deco." + id
		var node := picture(screen, art, objects[id])
		node.mouse_filter = Control.MOUSE_FILTER_STOP
		node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: poke(id))
		deco_nodes[id] = node
	# Window's four authored seasonal stages, clipped rather than downscaled.
	var window := picture(screen, "deco.window", Vector2(392, 194), 1, mini(3, restored_count() / 3))
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: poke("window"))
	deco_nodes["window"] = window
func poke(id: String) -> void:
	deco_counts[id] = int(deco_counts.get(id, 0)) + 1
	deco_poke_until[id] = Time.get_ticks_msec() + 1200
	var count := int(deco_counts[id])
	var sound: String = {"teacup": "sfx.teacup", "pipe": "sfx.pipe_puff", "ember": "sfx.ember_huff", "window": "sfx.ui_click"}.get(id, "")
	if not sound.is_empty() and AssetCatalog.has_audio(sound): AudioService.play_sfx(sound)
	if id == "teacup": _bubble("ember", "别往我身上倒！" if count % 5 == 0 else "茶还热着呢。")
	elif id == "pipe": _bubble("ember", "烟圈怎么套我头上了！" if count % 3 == 0 else "噗，一个圈。")
	elif id == "ember":
		if count % 10 == 0:
			ember_sulk_day = int(state.day)
			banter.mute_for_day("ember", int(state.day))
		else: _bubble("ember", "干嘛！")
	elif id == "clock" and state.get("ending_seen", false):
		if AssetCatalog.has_audio("sfx.clock_tick"): AudioService.play_sfx("sfx.clock_tick")
	if deco_nodes.has(id):
		var node: TextureRect = deco_nodes[id]
		var origin := node.position
		var tween := create_tween()
		tween.tween_method(func(value: float): if is_instance_valid(node): node.position.y = roundf(value), origin.y, origin.y - 2, 0.12)
		tween.tween_method(func(value: float): if is_instance_valid(node): node.position.y = roundf(value), origin.y - 2, origin.y, 0.12)

func _process(delta: float) -> void:
	idle_clock += delta
	if mode == "table" and not locked and idle_clock > 30:
		idle_clock = 0
		banter.trigger("idle", {}, state)
	if locked and night_auto:
		night_clock += delta * (2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1)
	if is_instance_valid(night_picture) and not night_art.is_empty():
		var frames := int(AssetCatalog.metadata(night_art).get("frames", 1))
		night_picture.texture = AssetCatalog.texture(night_art, int(night_clock * 6) % frames)
	if is_instance_valid(night_actor) and not night_actor_art.is_empty():
		night_actor.texture = AssetCatalog.texture(night_actor_art, 4 + int(night_clock * 6) % 4)
	if night_auto and night_clock > night_duration:
		night_auto = false
		play_next_event()
	if mode == "table":
		for id: String in deco_nodes:
			var node: TextureRect = deco_nodes[id]
			if not is_instance_valid(node): continue
			var art := "char.ember" if id == "ember" else "deco." + id
			var frame := 0
			if id == "ember": frame = 10 + int(Time.get_ticks_msec() / 400) % 2 if ember_sulk_day == int(state.day) else (6 + int(Time.get_ticks_msec() / 100) % 4 if int(deco_poke_until.get(id, 0)) > Time.get_ticks_msec() else int(Time.get_ticks_msec() / 250) % 4)
			elif id == "clock": frame = int(Time.get_ticks_msec() / 800) % 2 if state.get("ending_seen", false) else 0
			elif id == "window": frame = mini(3, restored_count() / 3)
			else: frame = int(Time.get_ticks_msec() / 150) % 4 if int(deco_poke_until.get(id, 0)) > Time.get_ticks_msec() else 0
			if AssetCatalog.has_art(art): node.texture = AssetCatalog.texture(art, frame)
