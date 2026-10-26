extends RefCounted
## Pure content predicates, operation interpreter, and canonical state utilities.
static func records(defs: Dictionary, key: String) -> Array:
	var value = defs.get(key, [])
	return value.values() if value is Dictionary else value

static func record(defs: Dictionary, key: String, id: String) -> Dictionary:
	for item in records(defs, key):
		if item.id == id: return item
	return {}

static func clone(s: Dictionary) -> Dictionary:
	var result := {}
	for key in s:
		if key == "defs": result[key] = s[key]
		else: result[key] = s[key].duplicate(true) if s[key] is Dictionary or s[key] is Array else s[key]
	return result

static func snapshot(s: Dictionary) -> Dictionary:
	var result := clone(s)
	result.erase("defs")
	result.erase("dawn_snapshot")
	return result

static func canonical(value):
	if value is Dictionary:
		var out := {}
		var keys = value.keys()
		keys.sort()
		for key in keys: out[key] = canonical(value[key])
		return out
	if value is Array:
		var out := []
		for v in value: out.append(canonical(v))
		return out
	return value

static func state_hash(s: Dictionary) -> String:
	return JSON.stringify(canonical(snapshot(s))).sha256_text()

static func emit(s: Dictionary, events: Array, type: String, payload: Dictionary = {}) -> void:
	events.append({"seq": events.size(), "day": s.day, "type": type, "payload": payload.duplicate(true)})

static func condition(s: Dictionary, c: Dictionary) -> bool:
	if c.has("all"):
		for child in c.all:
			if not condition(s, child): return false
		return true
	if c.has("any"):
		for child in c.any:
			if condition(s, child): return true
		return false
	if c.has("not"): return not condition(s, c["not"])
	if c.has("flag"): return s.flags.get(c.flag, false) == c.value
	if c.has("awake"): return s.residents.get(c.awake, {}).get("status", "") == "awake"
	if c.has("location_state"): return s.locations.get(c.location_state, {}).get("state", "") == c.value
	if c.has("progress_at_least"): return s.locations.get(c.loc, {}).get("progress", {}).get(c.progress_at_least, 0) >= c.n
	if c.has("goal_done"): return s.goal_steps.get(c.goal_done, false)
	if c.has("combo_done"): return c.combo_done in s.triggered_combos
	if c.has("event_active"):
		for event in s.active_events:
			if event.id == c.event_active: return true
		return false
	if c.has("assigned"):
		for assignment in s.assignments:
			if assignment.resident_id == c.assigned and assignment.location_id == c.loc: return true
		return false
	if c.has("use_resolved"):
		for use in s.get("resolved_uses", []):
			if use.use_id == c.use_resolved and use.location_id == c.loc and (not c.has("resident") or use.resident_id == c.resident): return true
		return false
	if c.has("day_at_least"): return s.day >= c.day_at_least
	if c.has("days_since"):
		var day := 0
		match c.days_since:
			"awaken": day = s.residents.get(c.target, {}).get("awakened_day", 0)
			"thaw": day = s.locations.get(c.target, {}).get("thawed_day", 0)
			"reveal": day = s.locations.get(c.target, {}).get("revealed_day", 0)
		return day > 0 and s.day - day >= c.n
	return false

static func requirements(s: Dictionary, list: Array) -> bool:
	for c in list:
		if not condition(s, c): return false
	return true

static func locations(s: Dictionary) -> Array:
	var list := records(s.defs, "locations").duplicate()
	list.sort_custom(func(a, b): return a.slot[0] * 100 + a.slot[1] < b.slot[0] * 100 + b.slot[1])
	return list

static func ops(s: Dictionary, operations: Array, events: Array, prepaid: bool = false) -> bool:
	var newly_paid := []
	for op in operations:
		match op.op:
			"gain":
				var n := int(op.n) + (int(op.get("bonus", 0)) if s.flags.get(op.get("bonus_flag", ""), false) else 0)
				if n < 0 or not s.resources.has(op.res): return false
				s.resources[op.res] += n
				emit(s, events, "gain", {"res": op.res, "n": n})
			"spend":
				if int(op.n) < 0 or not s.resources.has(op.res): return false
				if op.get("once_key", "") in s.paid_once_keys: continue
				if not prepaid:
					if s.resources[op.res] < op.n: return false
					s.resources[op.res] -= int(op.n)
				if op.has("once_key") and op.once_key not in newly_paid: newly_paid.append(op.once_key)
			"reveal", "thaw", "restore":
				if not s.locations.has(op.loc): return false
				var loc: Dictionary = s.locations[op.loc]
				var def := record(s.defs, "locations", op.loc)
				if op.op == "reveal" and loc.state == "hidden":
					loc.state = def.get("reveal_entry_state", "fog")
					loc.revealed_day = s.day
					emit(s, events, "reveal", {"loc": op.loc})
				elif op.op == "thaw" and loc.state == "frozen":
					loc.state = "thawed"
					loc.thawed_day = s.day
					emit(s, events, "thaw", {"loc": op.loc})
					for id in def.get("awaken", []):
						if not ops(s, [{"op": "awaken", "resident": id}], events): return false
				elif op.op == "restore" and loc.state == "thawed":
					loc.state = "restored"
					loc.restored_day = s.day
					emit(s, events, "restore", {"loc": op.loc})
			"awaken":
				if not s.residents.has(op.resident): return false
				if s.residents[op.resident].status == "frozen":
					s.residents[op.resident].status = "awake"
					s.residents[op.resident].awakened_day = s.day
					emit(s, events, "awaken", {"resident": op.resident})
					var bonus: Dictionary = s.defs.balance.get("awaken_bonus", {})
					if not bonus.is_empty() and op.resident == bonus.resident and s.flags.get(bonus.flag, false):
						if not ops(s, [{"op": "gain", "res": bonus.res, "n": bonus.n}], events): return false
			"progress":
				if not s.locations.has(op.loc) or op.n < 0 or op.max < 0: return false
				var progress: Dictionary = s.locations[op.loc].progress
				progress[op.key] = mini(int(op.max), int(progress.get(op.key, 0)) + int(op.n))
				emit(s, events, "progress", {"loc": op.loc, "key": op.key, "n": progress[op.key], "max": op.max})
			"set_flag": s.flags[op.key] = op.value
			"grant_spell":
				if record(s.defs, "spells", op.id).is_empty(): return false
				s.spell_inventory.append(op.id)
			"story": emit(s, events, "story", {"id": op.id})
			"flood":
				if op.days < 0: return false
				for id in op.locations:
					if not s.locations.has(id): return false
					s.locations[id].blocked_until_day = maxi(s.locations[id].blocked_until_day, s.day + int(op.days))
				emit(s, events, "flood", {"locations": op.locations, "days": op.days})
			"goal_step":
				if not s.goal_steps.has(op.id): return false
				if not s.goal_steps[op.id]:
					s.goal_steps[op.id] = true
					emit(s, events, "goal_step", {"id": op.id})
			_: return false
	for key in newly_paid: s.paid_once_keys.append(key)
	return true

static func valid_condition(c) -> bool:
	if not c is Dictionary: return false
	if c.has("all") or c.has("any"):
		var children = c.get("all", c.get("any", []))
		if not children is Array: return false
		for child in children:
			if not valid_condition(child): return false
		return c.size() == 1
	if c.has("not"): return c.size() == 1 and valid_condition(c["not"])
	var leaves := ["flag", "awake", "location_state", "progress_at_least", "goal_done", "combo_done", "event_active", "assigned", "use_resolved", "day_at_least", "days_since"]
	var matches := 0
	for key in leaves:
		if c.has(key): matches += 1
	if matches != 1: return false
	var allowed := []
	for key in leaves:
		if c.has(key): allowed.append(key)
	if c.has("flag") or c.has("location_state"): allowed.append("value")
	if c.has("progress_at_least"): allowed.append_array(["loc", "n"])
	if c.has("assigned") or c.has("use_resolved"): allowed.append("loc")
	if c.has("use_resolved"): allowed.append("resident")
	if c.has("days_since"): allowed.append_array(["target", "n"])
	for key in c:
		if key not in allowed: return false
	if c.has("flag") or c.has("location_state"): return c.has("value")
	if c.has("progress_at_least"): return c.has("loc") and c.has("n") and valid_count(c.n)
	if c.has("assigned") or c.has("use_resolved"): return c.has("loc")
	if c.has("day_at_least"): return valid_count(c.day_at_least)
	if c.has("days_since"): return c.days_since in ["awaken", "thaw", "reveal"] and c.has("target") and c.has("n") and valid_count(c.n)
	return true

static func valid_count(n) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and n >= 0 and float(n) == floor(float(n))

static func valid_ops(operations) -> bool:
	if not operations is Array: return false
	for op in operations:
		if not op is Dictionary or not op.has("op"): return false
		match op.op:
			"gain", "spend":
				if not op.has("res") or op.res not in ["wood", "stone", "warmth"] or not op.has("n") or not valid_count(op.n): return false
				if op.has("bonus") and not valid_count(op.bonus): return false
			"reveal", "thaw", "restore":
				if not op.has("loc"): return false
			"awaken":
				if not op.has("resident"): return false
			"progress":
				for field in ["loc", "key", "n", "max"]:
					if not op.has(field): return false
				if not valid_count(op.n) or not valid_count(op.max): return false
			"set_flag":
				if not op.has("key") or not op.has("value"): return false
			"grant_spell", "story", "goal_step":
				if not op.has("id"): return false
			"flood":
				if not op.has("locations") or not op.locations is Array or not op.has("days") or not valid_count(op.days): return false
			_: return false
	return true

static func valid_record(value) -> bool:
	if value is Array:
		for child in value:
			if not valid_record(child): return false
	elif value is Dictionary:
		for key in value:
			if key in ["ops", "done_ops", "expire_ops"]:
				if not valid_ops(value[key]): return false
			elif key in ["restore_when", "complete_when", "trigger", "when"]:
				if not valid_condition(value[key]): return false
			elif key == "requires":
				if not value[key] is Array: return false
				for c in value[key]:
					if not valid_condition(c): return false
			elif not valid_record(value[key]): return false
	return true

static func validate_defs(defs: Dictionary) -> bool:
	var all_ids := {}
	for key in ["locations", "residents", "combos", "events", "visitors", "spells", "goals", "schedule"]:
		if not defs.has(key) or not (defs[key] is Array or defs[key] is Dictionary): return false
		var ids := {}
		all_ids[key] = ids
		for row in records(defs, key):
			if not row is Dictionary or not row.has("id") or ids.has(row.id) or not valid_record(row): return false
			ids[row.id] = true
			var required := {"locations": ["name", "start", "slot", "uses"], "residents": ["name", "tags", "initial_status", "home", "playable"], "combos": ["loc", "who", "requires", "ops", "priority"], "events": ["name", "trigger", "duration", "related_locations", "complete_when", "done_ops", "expire_ops"], "visitors": ["name", "trigger", "duration", "related_locations", "complete_when", "done_ops", "expire_ops"], "spells": ["name", "effect"], "goals": ["label", "when", "hint", "related_locations"], "schedule": ["day", "ops"]}
			for field in required[key]:
				if not row.has(field): return false
			if not row.id is String: return false
			if key == "locations":
				if row.start not in ["hidden", "fog", "frozen", "thawed"] or not row.slot is Array or row.slot.size() != 2 or not row.uses is Array: return false
				if not valid_count(row.slot[0]) or not valid_count(row.slot[1]): return false
			if key == "residents":
				if not row.tags is Array or row.initial_status not in ["awake", "frozen"] or not row.playable is bool: return false
			if key == "combos":
				if not row.who is Array or row.who.size() not in [1, 2]: return false
			if key in ["events", "visitors"]:
				if not valid_count(row.duration) or row.duration == 0 or not row.related_locations is Array: return false
			if key == "schedule" and not valid_count(row.day): return false
			if key == "spells" and row.effect not in ["two_actions", "extra_flip"]: return false
			if key == "locations":
				var uses := {}
				for u in row.get("uses", []):
					if not u is Dictionary: return false
					for field in ["id", "label", "who", "ops"]:
						if not u.has(field): return false
					if uses.has(u.id): return false
					if not (u.who is String or u.who is Dictionary): return false
					if u.who is String and u.who != "any": return false
					if u.who is Dictionary and not (u.who.has("resident") or u.who.has("tag")): return false
					uses[u.id] = true
				for res in row.get("thaw_cost", {}):
					if res not in ["wood", "stone", "warmth"] or not valid_count(row.thaw_cost[res]): return false
	for key in all_ids:
		if not valid_references(defs[key], all_ids): return false
	if not defs.get("balance", {}) is Dictionary: return false
	var b: Dictionary = defs.get("balance", {})
	for key in ["initial_resources", "location_capacity", "event_capacity", "idle_reminder_threshold", "thaw_resident", "tutorial_residents", "fallback_story"]:
		if not b.has(key): return false
	if not b.initial_resources is Dictionary or not b.tutorial_residents is Array: return false
	if not all_ids.residents.has(b.thaw_resident): return false
	for resident in b.tutorial_residents:
		if not all_ids.residents.has(resident): return false
	if b.has("flood_reveal_location") and not all_ids.locations.has(b.flood_reveal_location): return false
	for key in ["explorer_bonus", "awaken_bonus"]:
		if not b.has(key): continue
		if not b[key] is Dictionary: return false
		for field in ["resident", "flag", "res", "n"]:
			if not b[key].has(field): return false
		if not all_ids.residents.has(b[key].resident) or b[key].res not in ["wood", "stone", "warmth"] or not valid_count(b[key].n): return false
	for field in ["location_capacity", "event_capacity", "idle_reminder_threshold"]:
		if not valid_count(b[field]) or b[field] == 0: return false
	for res in ["wood", "stone", "warmth"]:
		if not b.initial_resources.has(res) or not valid_count(b.initial_resources[res]): return false
	return true

static func valid_references(value, ids: Dictionary, field: String = "") -> bool:
	if value is Array:
		for child in value:
			if not valid_references(child, ids, field): return false
	elif value is Dictionary:
		for key in value:
			if not valid_references(value[key], ids, key): return false
	elif value is String:
		var map := {"loc": "locations", "location_state": "locations", "related_locations": "locations", "locations": "locations", "home": "locations", "resident": "residents", "awake": "residents", "awaken": "residents", "assigned": "residents", "goal_done": "goals", "combo_done": "combos"}
		if map.has(field) and not ids[map[field]].has(value): return false
		if field == "event_active" and not ids.events.has(value) and not ids.visitors.has(value): return false
	return true
