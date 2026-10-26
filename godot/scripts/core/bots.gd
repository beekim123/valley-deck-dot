extends RefCounted
## Test players, never game rules. PRNG belongs to the bot, not the game state.
const Rules = preload("res://scripts/core/day_rules.gd")
const Data = preload("res://scripts/core/rule_data.gd")

static func context(strategy: String, seed_value: int = 1) -> Dictionary:
	return {"strategy": strategy, "rng": 1 + posmod(seed_value - 1, 2147483646), "cursor": 0}

static func _draw(bot: Dictionary, count: int) -> int:
	# Park–Miller; integer arithmetic is stable across Godot platforms.
	bot.rng = (int(bot.rng) * 48271) % 2147483647
	return int(bot.rng) % count

static func residents(state: Dictionary) -> Array:
	var ids: Array = []
	for item in Data.records(state.defs, "residents"):
		if item.get("playable", true) and state.residents[item.id].status == "awake":
			ids.append(item.id)
	ids.sort()
	return ids

static func choices(state: Dictionary, resident_id: String) -> Array:
	var result: Array = []
	for location in Data.locations(state):
		var preview: Dictionary = Rules.preview(state, resident_id, location.id)
		for use in preview.get("uses", []):
			if use.get("enabled", false):
				result.append({"resident_id": resident_id, "location_id": location.id, "use_id": use.id, "preview": use})
	return result

static func _score(state: Dictionary, choice: Dictionary, bot: Dictionary) -> int:
	var loc: String = choice.location_id
	var use: String = choice.use_id
	var resident: String = choice.resident_id
	var score := 0
	var local_state: Dictionary = state.locations[loc]
	if local_state.state == "fog": score += 100
	if local_state.state == "frozen":
		score += 110
		if loc == "loc.herb_garden": score += 30
		if loc == "loc.misty_bank": score += 25
		if bot.strategy == "lazy" and loc == "loc.old_bridge": score -= 100
	var def := Data.record(state.defs, "locations", loc)
	for action in def.get("uses", []):
		if action.id != use: continue
		for op in action.get("ops", []):
			match op.op:
				"progress":
					if int(state.locations[op.loc].progress.get(op.key, 0)) < int(op.max): score += 120
				"awaken": score += 140
				"gain":
					var target := 5 if op.res == "wood" else (3 if op.res == "stone" else 7)
					score += int(op.n) * (15 if state.resources[op.res] < target else 1)
				"spend": score -= int(op.n)
	# Novelty-first goal player: it still pursues the goal, but tries visible ✦.
	var reachable_hint: bool = choice.preview.get("combo_hint", false)
	if bot.strategy == "lazy":
		reachable_hint = false
		for combo in Data.records(state.defs, "combos"):
			if combo.who.size() == 1 and resident in combo.who and combo.loc == loc and not combo.id in state.triggered_combos and (not combo.has("use_id") or combo.use_id == use) and Data.requirements(state, combo.get("requires", [])):
				reachable_hint = true
	if reachable_hint and local_state.state in ["thawed", "restored"]: score += 90
	if resident == "res.mira" and loc == "loc.river_bend" and not "combo.mira_river_skip" in state.triggered_combos: score += 60
	if bot.strategy != "lazy" and loc == "loc.pines" and resident in ["res.toby", "res.mira"] and not "combo.toby_mira_pines" in state.triggered_combos:
		score += 105
	# Deterministic preference families, never hidden runtime randomness.
	if bot.get("preference", 0) == 1 and loc == "loc.misty_bank": score += 45
	if bot.get("preference", 0) == 2 and loc == "loc.herb_garden": score += 45
	return score

static func _best(state: Dictionary, options: Array, bot: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -100000
	for option in options:
		var score := _score(state, option, bot)
		if score > best_score:
			best = option
			best_score = score
	return best

static func _exploration_weight(state: Dictionary, choice: Dictionary) -> int:
	# A constant, declared curiosity policy. It retains every legal option + rest.
	# Uses public action roles and ✦, never hidden combo operations or deadlines.
	var weight := 1
	var status: String = state.locations[choice.location_id].state
	if choice.preview.get("combo_hint", false) and status in ["thawed", "restored"]: weight += 8
	if choice.use_id == "explore": weight += 8
	if choice.use_id == "thaw": weight += 8
	if choice.use_id in ["repair_wheel", "warm_family", "build_dam"]: weight += 20
	return weight

static func play_day(state: Dictionary, bot: Dictionary) -> Dictionary:
	var commands: Array = []
	var events: Array = []
	var errors: Array = []
	if state.day == 1:
		for id in ["res.toby", "res.mira"]:
			if state.residents.has(id) and state.residents[id].status == "frozen":
				var result: Dictionary = Rules.tutorial_awaken(state, id)
				commands.append({"op": "tutorial_awaken", "resident_id": id, "ok": result.ok})
				events.append_array(result.events)
				if not result.ok: errors.append(result)
	var awake := residents(state)
	if awake.is_empty(): return {"commands": commands, "errors": errors, "events": events}
	if bot.strategy == "lazy":
		# Round-robin over the fixed roster (not only the currently awake list).
		# A newly awakened resident joins without repeatedly resetting fairness.
		var roster: Array = []
		for record in Data.records(state.defs, "residents"):
			if record.get("playable", true): roster.append(record.id)
		roster.sort()
		for offset in range(roster.size()):
			var index: int = (int(bot.cursor) + offset) % roster.size()
			var resident: String = roster[index]
			if not resident in awake: continue
			var options := choices(state, resident)
			if options.is_empty(): continue
			bot.cursor = (index + 1) % roster.size()
			_apply(state, _best(state, options, bot), commands, errors)
			break
	elif bot.strategy in ["random", "exploratory_random"]:
		# Fisher–Yates order, then uniform over all legal (location,use) + REST.
		# No goal weighting, late takeover, forced action, or filtered resource use.
		for i in range(awake.size() - 1, 0, -1):
			var j := _draw(bot, i + 1)
			var swap = awake[i]
			awake[i] = awake[j]
			awake[j] = swap
		for resident in awake:
			var options := choices(state, resident)
			var index: int
			if bot.strategy == "exploratory_random":
				var total := 1 # REST always has positive probability.
				for option in options: total += _exploration_weight(state, option)
				var ticket := _draw(bot, total)
				index = options.size()
				for i in range(options.size()):
					ticket -= _exploration_weight(state, options[i])
					if ticket < 0:
						index = i
						break
			else: index = _draw(bot, options.size() + 1)
			if index == options.size(): commands.append({"op": "rest", "resident_id": resident})
			else: _apply(state, options[index], commands, errors)
	else:
		bot.preference = int(state.seed) % 3
		# Select globally so constrained specialist actions win over generic chores.
		for ignored in range(awake.size()):
			var options: Array = []
			for resident in awake: options.append_array(choices(state, resident))
			if options.is_empty(): break
			_apply(state, _best(state, options, bot), commands, errors)
	return {"commands": commands, "errors": errors, "events": events}

static func _apply(state: Dictionary, choice: Dictionary, commands: Array, errors: Array) -> void:
	if choice.is_empty(): return
	var result: Dictionary = Rules.assign(state, choice.resident_id, choice.location_id, choice.use_id)
	commands.append({"op": "assign", "resident_id": choice.resident_id, "location_id": choice.location_id, "use_id": choice.use_id, "ok": result.ok, "resources_after": state.resources.duplicate()})
	if not result.ok: errors.append(result)
