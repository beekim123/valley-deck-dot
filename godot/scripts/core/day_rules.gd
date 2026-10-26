extends RefCounted
## Transactional, deterministic public command surface; no scene dependencies.
const Data = preload("res://scripts/core/rule_data.gd")
const Cycle = preload("res://scripts/core/day_cycle.gd")

static func new_game(defs: Dictionary, seed: int = 1) -> Dictionary:
	if not Data.validate_defs(defs): return {}
	var b: Dictionary = defs.balance
	var s := {"defs": defs, "version": 1, "content_version": b.get("content_version", "content/1"), "seed": seed, "rng_state": seed,
		"revision": 0, "day": 1, "phase": "day", "resources": b.initial_resources.duplicate(true),
		"locations": {}, "residents": {}, "assignments": [], "paid_once_keys": [], "triggered_combos": [],
		"flags": {}, "active_events": [], "queued_events": [], "event_history": {}, "schedule_done": [],
		"spell_inventory": [], "day_modifiers": {"two_actions_resident": "", "extra_flip": false},
		"goal_steps": {}, "chapter_complete": false, "ending_seen": false, "visitors_seen": [],
		"idle_streak": 0, "idle_reminder_sent": false, "last_day_events": [], "dawn_snapshot": {}, "resolved_uses": []}
	for d in Data.records(defs, "locations"):
		s.locations[d.id] = {"state": d.start, "progress": {}, "revealed_day": 0 if d.start == "hidden" else 1,
			"thawed_day": 1 if d.start == "thawed" else 0, "restored_day": 0, "blocked_until_day": 0}
	for d in Data.records(defs, "residents"):
		s.residents[d.id] = {"status": d.initial_status, "awakened_day": 1 if d.initial_status == "awake" else 0}
	for d in Data.records(defs, "goals"): s.goal_steps[d.id] = false
	var events := []
	if not Cycle.dawn(s, events): return {}
	s.last_day_events = events
	s.dawn_snapshot = Data.snapshot(s)
	return s

static func result(s: Dictionary, ok: bool, reason: String = "", events: Array = []) -> Dictionary:
	return {"ok": ok, "reason_code": reason, "reason_args": {}, "events": events, "revision": s.revision}

static func commit(s: Dictionary, work: Dictionary, events: Array) -> Dictionary:
	work.revision = s.revision + 1
	s.clear()
	s.merge(work)
	return result(s, true, "", events)

static func who_matches(s: Dictionary, who, resident: String) -> bool:
	if who is String: return who == "any"
	if who.has("resident"): return who.resident == resident
	return who.get("tag", "") in Data.record(s.defs, "residents", resident).get("tags", [])

static func combo_candidates(s: Dictionary, resident: String, loc: String, use_id: String = "") -> Array:
	var out := []
	for c in Data.records(s.defs, "combos"):
		if c.loc != loc or resident not in c.who or c.id in s.triggered_combos: continue
		if c.has("use_id") and use_id != "" and c.use_id != use_id: continue
		if not Data.requirements(s, c.get("requires", [])): continue
		var ready := true
		for id in c.who:
			if s.residents[id].status != "awake": ready = false
		if ready: out.append(c)
	out.sort_custom(func(a, b):
		if a.who.size() != b.who.size(): return a.who.size() > b.who.size()
		if a.get("priority", 0) != b.get("priority", 0): return a.get("priority", 0) > b.get("priority", 0)
		return a.id < b.id)
	return out

static func available_uses(s: Dictionary, resident: String, loc: String) -> Array:
	if not s.locations.has(loc): return []
	var ld := Data.record(s.defs, "locations", loc)
	var status: String = s.locations[loc].state
	if status == "fog": return [{"id": "explore", "label": "探路", "who": "any", "requires": [], "ops": []}]
	if status == "frozen":
		var operations := []
		for res in ld.get("thaw_cost", {}): operations.append({"op": "spend", "res": res, "n": ld.thaw_cost[res]})
		operations.append({"op": "thaw", "loc": loc})
		return [{"id": "thaw", "label": "焐", "who": {"resident": s.defs.balance.thaw_resident}, "requires": [], "ops": operations}]
	if status == "hidden": return []
	var out: Array = ld.get("uses", []).duplicate(true)
	var has_use := false
	for u in out:
		if who_matches(s, u.who, resident) and Data.requirements(s, u.get("requires", [])): has_use = true
	if not has_use:
		for c in combo_candidates(s, resident, loc):
			if c.who.size() == 1 and not c.has("use_id"):
				out.append({"id": "combo:" + c.id, "label": "看看这里 ✦", "who": {"resident": resident}, "requires": [], "ops": []})
	return out

static func refund_remove(s: Dictionary, id: String) -> bool:
	for i in range(s.assignments.size()):
		var a: Dictionary = s.assignments[i]
		if a.id == id:
			for res in a.escrow: s.resources[res] += a.escrow[res]
			s.assignments.remove_at(i)
			return true
	return false

static func base_reason(s: Dictionary, resident: String, loc: String) -> String:
	if s.phase != "day": return "wrong_phase"
	if not s.residents.has(resident) or not s.locations.has(loc): return "unknown_id"
	if s.residents[resident].status != "awake" or not Data.record(s.defs, "residents", resident).get("playable", true): return "resident_frozen"
	var place: Dictionary = s.locations[loc]
	if place.state == "hidden": return "location_hidden"
	if place.blocked_until_day >= s.day: return "location_flooded"
	var actions := 0
	var occupants := 0
	for a in s.assignments:
		if a.resident_id == resident:
			actions += 1
			if a.location_id == loc: return "same_location"
		if a.location_id == loc: occupants += 1
	if actions >= (2 if s.day_modifiers.two_actions_resident == resident else 1): return "action_limit"
	if place.state == "fog" and occupants > 0: return "fog_occupied"
	if occupants >= int(s.defs.balance.location_capacity): return "location_full"
	return ""

static func public_outcomes(s: Dictionary, loc: String, u: Dictionary) -> Array:
	# Only ordinary, already-known use operations are public. Never inspect combo ops.
	if u.id == "explore": return [{"type": "flip", "payload": {"loc": loc, "unknown": true}}]
	var outcomes := []
	for op in u.ops:
		match op.op:
			"thaw":
				outcomes.append({"type": "thaw", "payload": {"loc": op.loc}})
				for resident in Data.record(s.defs, "locations", op.loc).get("awaken", []):
					if s.residents[resident].status == "frozen": outcomes.append({"type": "awaken", "payload": {"resident": resident}})
			"awaken":
				if s.residents[op.resident].status == "frozen": outcomes.append({"type": "awaken", "payload": {"resident": op.resident}})
			"progress":
				var before: int = s.locations[op.loc].progress.get(op.key, 0)
				var after := mini(int(op.max), before + int(op.n))
				outcomes.append({"type": "progress", "payload": {"loc": op.loc, "key": op.key, "n": after - before, "max": int(op.max), "before": before, "after": after, "completes": before < op.max and after == op.max}})
			"restore": outcomes.append({"type": "restore", "payload": {"loc": op.loc}})
			"reveal": outcomes.append({"type": "reveal", "payload": {"unknown": true}})
			"goal_step": outcomes.append({"type": "goal_step", "payload": {"id": op.id}})
			"story": outcomes.append({"type": "story", "payload": {"id": op.id}})
			"grant_spell": outcomes.append({"type": "grant_spell", "payload": {"id": op.id}})
	# Predict independent goal steps from this ordinary use alone, never other bookings
	# or surprise operations. This is a disposable state; preview remains read-only.
	if u.ops.any(func(op): return op.op in ["thaw", "awaken", "progress", "set_flag", "goal_step", "restore"]):
		var predicted := Data.clone(s)
		if Data.ops(predicted, u.ops, [], true):
			for goal in Data.records(s.defs, "goals"):
				if not s.goal_steps.get(goal.id, false) and Data.condition(predicted, goal.when):
					var already := outcomes.any(func(o): return o.type == "goal_step" and o.payload.id == goal.id)
					if not already: outcomes.append({"type": "goal_step", "payload": {"id": goal.id}})
	return outcomes

static func compile(s: Dictionary, resident: String, loc: String, u: Dictionary) -> Dictionary:
	var out := {"id": u.id, "label": u.label, "enabled": true, "blocked_reason": "", "reason_args": {}, "cost": {}, "gain": {}, "remaining": s.resources.duplicate(true), "combo_hint": false, "priority": 0, "once_keys": [], "outcomes": public_outcomes(s, loc, u)}
	var reason := base_reason(s, resident, loc)
	if reason == "" and not who_matches(s, u.who, resident): reason = "wrong_resident"
	if reason == "" and not Data.requirements(s, u.get("requires", [])): reason = "requirements_unmet"
	for op in u.ops:
		if op.op == "spend":
			var key: String = op.get("once_key", "")
			if key != "" and key in s.paid_once_keys: continue
			var reserved := false
			for a in s.assignments:
				if key != "" and key in a.once_keys: reserved = true
			if reserved:
				if reason == "": reason = "requirements_unmet"
				continue
			out.cost[op.res] = out.cost.get(op.res, 0) + int(op.n)
			if key != "" and key not in out.once_keys: out.once_keys.append(key)
		elif op.op == "gain": out.gain[op.res] = out.gain.get(op.res, 0) + int(op.n) + (int(op.get("bonus", 0)) if s.flags.get(op.get("bonus_flag", ""), false) else 0)
		elif op.op == "progress" and u.get("progress_key", "") == op.key and s.locations[op.loc].progress.get(op.key, 0) >= op.max:
			if reason in ["", "requirements_unmet"]: reason = "progress_complete"
	for res in out.cost:
		out.remaining[res] -= out.cost[res]
		if out.remaining[res] < 0 and reason == "":
			reason = "insufficient_resource"
			out.reason_args = {"res": res, "have": s.resources[res], "need": out.cost[res]}
	out.combo_hint = not combo_candidates(s, resident, loc, u.id).is_empty() if s.residents.has(resident) and s.locations[loc].state in ["thawed", "restored"] else false
	out.priority = 2 if out.combo_hint else (1 if not u.who is String else 0)
	out.blocked_reason = reason
	out.enabled = reason == ""
	return out

static func preview(s: Dictionary, resident_id: String, location_id: String, replacing_assignment_id: String = "") -> Dictionary:
	var work := Data.clone(s)
	var invalid_replace := replacing_assignment_id != "" and not refund_remove(work, replacing_assignment_id)
	var out := {"revision": s.revision, "uses": [], "resources_before": work.resources.duplicate(true), "resources_after": work.resources.duplicate(true)}
	for u in available_uses(work, resident_id, location_id):
		var p := compile(work, resident_id, location_id, u)
		p.erase("once_keys")
		if invalid_replace:
			p.enabled = false
			p.blocked_reason = "unknown_id"
		out.uses.append(p)
	out.uses.sort_custom(func(a, b): return a.priority > b.priority if a.priority != b.priority else a.id < b.id)
	if not out.uses.is_empty(): out.resources_after = out.uses[0].remaining.duplicate(true)
	return out

static func assign(s: Dictionary, resident_id: String, location_id: String, use_id: String, replacing_assignment_id: String = "") -> Dictionary:
	var work := Data.clone(s)
	if replacing_assignment_id != "" and not refund_remove(work, replacing_assignment_id): return result(s, false, "unknown_id")
	for u in available_uses(work, resident_id, location_id):
		if u.id != use_id: continue
		var p := compile(work, resident_id, location_id, u)
		if not p.enabled:
			var failure := result(s, false, p.blocked_reason)
			failure.reason_args = p.reason_args
			return failure
		work.resources = p.remaining
		var id := "assignment.%d" % (s.revision + 1)
		var a := {"id": id, "resident_id": resident_id, "location_id": location_id, "use_id": use_id, "order": s.revision + 1, "escrow": p.cost, "once_keys": p.once_keys}
		work.assignments.append(a)
		var events := []
		Data.emit(work, events, "assign", a)
		var answer := commit(s, work, events)
		answer.assignment_id = id
		return answer
	return result(s, false, base_reason(work, resident_id, location_id) if base_reason(work, resident_id, location_id) != "" else "unknown_id")

static func unassign(s: Dictionary, assignment_id: String) -> Dictionary:
	if s.phase != "day": return result(s, false, "wrong_phase")
	var work := Data.clone(s)
	if not refund_remove(work, assignment_id): return result(s, false, "unknown_id")
	var events := []
	Data.emit(work, events, "unassign", {"id": assignment_id})
	return commit(s, work, events)

static func tutorial_awaken(s: Dictionary, resident_id: String) -> Dictionary:
	if s.phase != "day" or s.day != 1: return result(s, false, "wrong_phase")
	if resident_id not in s.defs.balance.tutorial_residents or not s.residents.has(resident_id): return result(s, false, "unknown_id")
	if s.residents[resident_id].status != "frozen": return result(s, false, "requirements_unmet")
	var work := Data.clone(s)
	var events := []
	Data.ops(work, [{"op": "awaken", "resident": resident_id}], events)
	var answer := commit(s, work, events)
	# Tutorial is durable at the same dawn; player assignments are not.
	s.dawn_snapshot.residents[resident_id] = s.residents[resident_id].duplicate(true)
	s.dawn_snapshot.revision = s.revision
	return answer

static func use_spell(s: Dictionary, spell_id: String, target_resident_id: String = "") -> Dictionary:
	if s.phase != "day": return result(s, false, "wrong_phase")
	var spell := Data.record(s.defs, "spells", spell_id)
	if spell.is_empty() or spell_id not in s.spell_inventory: return result(s, false, "unknown_id")
	if spell.effect == "two_actions":
		if not s.residents.has(target_resident_id): return result(s, false, "unknown_id")
		if s.residents[target_resident_id].status != "awake" or not Data.record(s.defs, "residents", target_resident_id).playable: return result(s, false, "resident_frozen")
		if s.day_modifiers.two_actions_resident != "": return result(s, false, "requirements_unmet")
	elif spell.effect != "extra_flip": return result(s, false, "unknown_id")
	elif s.day_modifiers.extra_flip: return result(s, false, "requirements_unmet")
	var work := Data.clone(s)
	work.spell_inventory.erase(spell_id)
	if spell.effect == "two_actions": work.day_modifiers.two_actions_resident = target_resident_id
	else: work.day_modifiers.extra_flip = true
	var events := []
	Data.emit(work, events, "spell_used", {"id": spell_id, "resident": target_resident_id})
	return commit(s, work, events)

static func flip(s: Dictionary, loc: String, resident: String, events: Array) -> bool:
	if s.locations[loc].state != "fog": return true
	var def := Data.record(s.defs, "locations", loc)
	s.locations[loc].state = def.get("reveal_state", "thawed")
	if s.locations[loc].state == "thawed": s.locations[loc].thawed_day = s.day
	Data.emit(s, events, "flip", {"loc": loc})
	var bonus: Dictionary = s.defs.balance.get("explorer_bonus", {})
	if not bonus.is_empty() and resident == bonus.resident and s.flags.get(bonus.flag, false):
		return Data.ops(s, [{"op": "gain", "res": bonus.res, "n": bonus.n}], events)
	return true

static func end_day(s: Dictionary) -> Dictionary:
	if s.phase != "day": return result(s, false, "wrong_phase")
	if s.day == 1:
		for id in s.defs.balance.tutorial_residents:
			if s.residents[id].status != "awake": return result(s, false, "tutorial_incomplete")
	var work := Data.clone(s)
	var events := []
	var before_complete: bool = s.chapter_complete
	work.resolved_uses = []
	work._night_blocked = {}
	for id in s.locations: work._night_blocked[id] = s.locations[id].blocked_until_day >= s.day
	var ordered := Data.locations(s)
	# Freeze eligible combinations and uses before any nightly mutation.
	var combos := []
	for c in Data.records(s.defs, "combos"):
		if c.id in s.triggered_combos or not Data.requirements(s, c.get("requires", [])): continue
		if s.locations[c.loc].state not in ["thawed", "restored"]: continue
		var eligible := true
		for resident in c.who:
			var matched := false
			for a in s.assignments:
				if a.location_id == c.loc and a.resident_id == resident and (not c.has("use_id") or c.use_id == a.use_id): matched = true
			if not matched: eligible = false
		if eligible: combos.append(c)
	combos.sort_custom(func(a, b):
		if a.who.size() != b.who.size(): return a.who.size() > b.who.size()
		if a.get("priority", 0) != b.get("priority", 0): return a.get("priority", 0) > b.get("priority", 0)
		return a.id < b.id)
	var reserved_fog := []
	for a in s.assignments:
		if a.use_id == "explore": reserved_fog.append(a.location_id)
	for ld in ordered:
		for c in combos:
			if c.loc != ld.id: continue
			work.triggered_combos.append(c.id)
			Data.emit(work, events, "combo", {"id": c.id, "loc": c.loc})
			if not Data.ops(work, c.ops, events): return result(s, false, "invalid_content")
		for a in s.assignments:
			if a.location_id != ld.id: continue
			Data.emit(work, events, "resolve", {"resident_id": a.resident_id, "location_id": a.location_id, "use_id": a.use_id})
			if a.use_id == "explore":
				if not flip(work, ld.id, a.resident_id, events): return result(s, false, "invalid_content")
				if work.day_modifiers.extra_flip:
					var after := false
					for next in ordered:
						if next.id == ld.id:
							after = true
							continue
						if after and work.locations[next.id].state == "fog" and next.id not in reserved_fog:
							if not flip(work, next.id, a.resident_id, events): return result(s, false, "invalid_content")
							break
			else:
				var found := false
				for u in available_uses(s, a.resident_id, ld.id):
					if u.id != a.use_id: continue
					found = true
					var operations: Array = u.ops.duplicate(true)
					for c in combos:
						if c.loc == ld.id and a.resident_id in c.who and c.get("replace_use_gain", false) and (not c.has("use_id") or c.use_id == a.use_id):
							operations = operations.filter(func(op): return op.op != "gain")
					if not Data.ops(work, operations, events, true): return result(s, false, "invalid_content")
					break
				if not found: return result(s, false, "invalid_content")
			work.resolved_uses.append(a.duplicate(true))
	if s.assignments.is_empty():
		work.idle_streak += 1
		var reminder: bool = work.idle_streak >= int(s.defs.balance.idle_reminder_threshold) and not work.idle_reminder_sent
		if reminder: work.idle_reminder_sent = true
		Data.emit(work, events, "night_empty", {"reminder": reminder})
	else: work.idle_streak = 0
	if not Cycle.settle(work, events): return result(s, false, "invalid_content")
	work.erase("_night_blocked")
	var summary := {"day": s.day, "resources_before": s.resources.duplicate(true), "resources_after": work.resources.duplicate(true), "actions": s.assignments.size()}
	Data.emit(work, events, "summary", summary)
	work.assignments = []
	work.day_modifiers = {"two_actions_resident": "", "extra_flip": false}
	work.day += 1
	work.resolved_uses = []
	if not Cycle.dawn(work, events): return result(s, false, "invalid_content")
	work.last_day_events = events.duplicate(true)
	var answer := commit(s, work, events)
	s.dawn_snapshot = Data.snapshot(s)
	answer.summary = summary
	answer.ending = not before_complete and s.chapter_complete
	return answer

static func view_model(s: Dictionary) -> Dictionary:
	var out := Data.snapshot(s)
	out.location_list = []
	for d in Data.locations(s):
		var row: Dictionary = d.duplicate(true)
		row.merge(s.locations[d.id], true)
		out.location_list.append(row)
	out.resident_list = []
	for d in Data.records(s.defs, "residents"):
		var row: Dictionary = d.duplicate(true)
		row.merge(s.residents[d.id], true)
		out.resident_list.append(row)
	out.event_list = []
	for event in s.active_events:
		var d := Data.record(s.defs, "events", event.id)
		if d.is_empty(): d = Data.record(s.defs, "visitors", event.id)
		var row: Dictionary = d.duplicate(true)
		row.merge(event, true)
		out.event_list.append(row)
	out.goals = []
	for d in Data.records(s.defs, "goals"):
		var row: Dictionary = d.duplicate(true)
		row.done = s.goal_steps[d.id]
		out.goals.append(row)
	return out
