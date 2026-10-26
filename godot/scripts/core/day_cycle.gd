extends RefCounted
## Pure deterministic night tail and complete, idempotent dawn boundary.
const Data = preload("res://scripts/core/rule_data.gd")

static func event_definition(s: Dictionary, id: String) -> Dictionary:
	var definition := Data.record(s.defs, "events", id)
	return Data.record(s.defs, "visitors", id) if definition.is_empty() else definition

static func _flood_snapshot(s: Dictionary) -> Dictionary:
	if s.has("_night_blocked"): return s._night_blocked.duplicate()
	var source: Dictionary = s.get("dawn_snapshot", {}).get("locations", s.locations)
	var blocked := {}
	for id in source:
		blocked[id] = int(source[id].get("blocked_until_day", 0)) >= int(s.day)
	return blocked

static func _paused(definition: Dictionary, blocked: Dictionary) -> bool:
	var related: Array = definition.get("related_locations", [])
	if related.is_empty(): return false
	var disjunction: bool = definition.get("pause_mode", "") == "all" if definition.has("pause_mode") else definition.get("complete_when", {}).has("any")
	for id in related:
		if disjunction and not blocked.get(id, false): return false
		if not disjunction and blocked.get(id, false): return true
	return disjunction

static func settle(s: Dictionary, events: Array) -> bool:
	var blocked := _flood_snapshot(s)
	var active: Array = s.active_events.duplicate(true)
	active.sort_custom(func(a, b): return a.id < b.id if a.issued_day == b.issued_day else a.issued_day < b.issued_day)
	var complete := []
	# Decide completion before applying any expiry effects.
	for event in active:
		var definition := event_definition(s, event.id)
		if definition.is_empty(): return false
		if Data.condition(s, definition.complete_when): complete.append(event.id)
	for event in active:
		if event.id not in complete: continue
		var definition := event_definition(s, event.id)
		if not Data.ops(s, definition.get("done_ops", []), events): return false
		s.event_history[event.id] = {"status": "completed", "day": s.day}
		Data.emit(s, events, "event_done", {"id": event.id})
	var retained := []
	var expired := []
	for event in active:
		if event.id in complete: continue
		var definition := event_definition(s, event.id)
		if _paused(definition, blocked):
			Data.emit(s, events, "event_paused", {"id": event.id, "remaining": event.remaining})
			retained.append(event)
		else:
			event.remaining = int(event.remaining) - 1
			if event.remaining <= 0: expired.append(event)
			else: retained.append(event)
	s.active_events = retained
	for event in expired:
		var definition := event_definition(s, event.id)
		if not Data.ops(s, definition.get("expire_ops", []), events): return false
		s.event_history[event.id] = {"status": "expired", "day": s.day}
		Data.emit(s, events, "event_expire", {"id": event.id})
	# Monotone fixed point: goals may unlock restoration and vice versa.
	var changed := true
	while changed:
		changed = false
		for location in Data.locations(s):
			if s.locations[location.id].state != "thawed" or not location.has("restore_when"): continue
			if Data.condition(s, location.restore_when):
				if not Data.ops(s, [{"op": "restore", "loc": location.id}], events): return false
				changed = true
		for goal in Data.records(s.defs, "goals"):
			if not s.goal_steps.get(goal.id, false) and Data.condition(s, goal.when):
				if not Data.ops(s, [{"op": "goal_step", "id": goal.id}], events): return false
				changed = true
	var all_complete: bool = not s.goal_steps.is_empty()
	for value in s.goal_steps.values(): all_complete = all_complete and bool(value)
	if all_complete and not s.chapter_complete:
		s.chapter_complete = true
		Data.emit(s, events, "chapter_complete", {})
	return true

static func _known_event(s: Dictionary, id: String) -> bool:
	if id in s.queued_events or s.event_history.has(id): return true
	for event in s.active_events:
		if event.id == id: return true
	return false

static func _deal(s: Dictionary, events: Array) -> bool:
	var capacity := int(s.defs.balance.event_capacity)
	while s.active_events.size() < capacity and not s.queued_events.is_empty():
		var id: String = s.queued_events.pop_front()
		var definition := event_definition(s, id)
		if definition.is_empty() or int(definition.duration) <= 0: return false
		var event := {"id": id, "issued_day": s.day, "remaining": int(definition.duration)}
		s.active_events.append(event)
		if not Data.record(s.defs, "visitors", id).is_empty() and id not in s.visitors_seen:
			s.visitors_seen.append(id)
		Data.emit(s, events, "event_new", event)
	s.active_events.sort_custom(func(a, b): return a.id < b.id if a.issued_day == b.issued_day else a.issued_day < b.issued_day)
	return true

static func _who_matches(s: Dictionary, who, resident: String) -> bool:
	if who is String: return who == "any"
	if who.has("resident"): return who.resident == resident
	if who.has("tag"): return who.tag in Data.record(s.defs, "residents", resident).get("tags", [])
	return false

static func _can_use(s: Dictionary, use: Dictionary, resident: String) -> bool:
	if not _who_matches(s, use.get("who", "any"), resident): return false
	if not Data.requirements(s, use.get("requires", [])): return false
	var cost := {}
	for op in use.get("ops", []):
		if op.op != "spend" or op.get("once_key", "") in s.paid_once_keys: continue
		cost[op.res] = cost.get(op.res, 0) + int(op.n)
	for resource in cost:
		if int(s.resources.get(resource, 0)) < int(cost[resource]): return false
	return true

static func _has_discovery(s: Dictionary) -> bool:
	for location in Data.locations(s):
		var current: Dictionary = s.locations[location.id]
		if current.state == "fog" and int(current.blocked_until_day) < int(s.day): return true
	for combo in Data.records(s.defs, "combos"):
		if combo.id in s.triggered_combos or not Data.requirements(s, combo.get("requires", [])): continue
		var current: Dictionary = s.locations[combo.loc]
		if current.state not in ["thawed", "restored"] or int(current.blocked_until_day) >= int(s.day): continue
		var possible := true
		for resident in combo.who:
			if s.residents[resident].status != "awake":
				possible = false
				break
			if combo.has("use_id"):
				var matching := false
				for use in Data.record(s.defs, "locations", combo.loc).uses:
					if use.id == combo.use_id and _can_use(s, use, resident): matching = true
				if not matching: possible = false
		if possible: return true
	return false

static func dawn(s: Dictionary, events: Array) -> bool:
	if int(s.get("dawn_processed_day", 0)) == int(s.day): return true
	var balance: Dictionary = s.defs.balance
	var recovered := []
	for location in Data.locations(s):
		var current: Dictionary = s.locations[location.id]
		if int(current.blocked_until_day) > 0 and int(current.blocked_until_day) < int(s.day):
			current.blocked_until_day = 0
			recovered.append(location.id)
	if not recovered.is_empty():
		Data.emit(s, events, "flood_end", {"locations": recovered})
		if balance.has("flood_end_flag"): s.flags[balance.flood_end_flag] = true
		if balance.has("flood_reveal_location"):
			if not Data.ops(s, [{"op": "reveal", "loc": balance.flood_reveal_location}], events): return false
	for location in Data.locations(s):
		if s.locations[location.id].state == "restored" and location.has("daily"):
			if not Data.ops(s, [{"op": "gain", "res": location.daily.res, "n": location.daily.n}], events): return false
	var schedule := Data.records(s.defs, "schedule").duplicate()
	schedule.sort_custom(func(a, b): return a.id < b.id if a.day == b.day else a.day < b.day)
	for entry in schedule:
		if int(entry.day) <= int(s.day) and entry.id not in s.schedule_done:
			if not Data.ops(s, entry.ops, events): return false
			s.schedule_done.append(entry.id)
	var definitions := Data.records(s.defs, "events").duplicate()
	definitions.sort_custom(func(a, b): return a.id < b.id)
	for definition in definitions:
		if not _known_event(s, definition.id) and Data.condition(s, definition.trigger):
			s.queued_events.append(definition.id)
	var deal_start := events.size()
	if not _deal(s, events): return false
	var new_event := events.size() > deal_start
	if not new_event and not _has_discovery(s):
		var visitors := Data.records(s.defs, "visitors").duplicate()
		visitors.sort_custom(func(a, b): return a.id < b.id)
		var available := ""
		for visitor in visitors:
			if visitor.id not in s.visitors_seen and not _known_event(s, visitor.id) and Data.condition(s, visitor.trigger):
				available = visitor.id
				break
		if not available.is_empty() and s.active_events.size() < int(balance.event_capacity):
			s.queued_events.append(available)
			if not _deal(s, events): return false
		else:
			Data.emit(s, events, "story", {"id": balance.fallback_story, "fallback": true})
	Data.emit(s, events, "dawn", {"day": s.day})
	s.dawn_processed_day = int(s.day)
	return true
