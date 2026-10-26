extends SceneTree
const Rules = preload("res://scripts/core/day_rules.gd")
const Data = preload("res://scripts/core/rule_data.gd")
const Cycle = preload("res://scripts/core/day_cycle.gd")
var failures := 0
var assertions := 0
var defs := {}

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh() -> Dictionary:
	var s := Rules.new_game(defs)
	Rules.tutorial_awaken(s, "res.toby")
	Rules.tutorial_awaken(s, "res.mira")
	return s

func use(s: Dictionary, who: String, loc: String, id: String) -> Dictionary:
	for p in Rules.preview(s, who, loc).uses:
		if p.id == id: return p
	return {}

func count(events: Array, type: String) -> int:
	return events.filter(func(e): return e.type == type).size()

func run() -> void:
	# Read the actual authoring data; sync-independent rule tests still use true content.
	for key in ["locations", "residents", "combos", "events", "visitors", "spells", "goals", "schedule", "balance"]:
		var doc = JSON.parse_string(FileAccess.get_file_as_string("res://../content/data/" + key + ".json"))
		defs[key] = doc[key]
	var tutorial := Rules.new_game(defs)
	var original := Data.state_hash(tutorial)
	expect(not Rules.end_day(tutorial).ok and original == Data.state_hash(tutorial), "tutorial cannot be bypassed into permanent frozen state")
	var invalid := defs.duplicate(true)
	invalid.locations[0].uses[0].ops[0].n = -1
	expect(Rules.new_game(invalid).is_empty(), "negative operations rejected")
	invalid = defs.duplicate(true)
	invalid.locations.append(invalid.locations[0].duplicate(true))
	expect(Rules.new_game(invalid).is_empty(), "duplicate ids rejected")
	invalid = defs.duplicate(true)
	invalid.goals[0].when = {"unknown_predicate": true}
	expect(Rules.new_game(invalid).is_empty(), "unknown conditions rejected")
	invalid = defs.duplicate(true)
	invalid.locations[0].erase("start")
	expect(Rules.new_game(invalid).is_empty(), "missing nested required data rejected safely")
	invalid = defs.duplicate(true)
	invalid.balance.initial_resources = []
	expect(Rules.new_game(invalid).is_empty(), "malformed resource map rejected safely")
	var s := fresh()
	expect(s.residents["res.toby"].status == "awake", "tutorial free awaken")
	expect(s.resources == defs.balance.initial_resources and s.assignments.is_empty(), "tutorial spends no resources/actions")
	expect(not Rules.tutorial_awaken(s, "res.toby").ok, "tutorial cannot repeat")
	# 1 fog single slot; preview purity and failed commands atomic.
	var a := Rules.assign(s, "res.toby", "loc.flower_slope", "explore")
	var hash := Data.state_hash(s)
	expect(not use(s, "res.mira", "loc.flower_slope", "explore").enabled, "fog capacity preview")
	expect(not Rules.assign(s, "res.mira", "loc.flower_slope", "explore").ok and hash == Data.state_hash(s), "fog rejection atomic; preview pure")
	Rules.unassign(s, a.assignment_id)
	expect(Rules.assign(s, "res.mira", "loc.flower_slope", "explore").ok, "fog released")
	# 2 anticipated gains cannot fund today's cost.
	s = fresh()
	s.resources.warmth = 2
	Rules.assign(s, "res.toby", "loc.hut", "fire")
	expect(not use(s, "res.anuan", "loc.mill", "thaw").enabled, "future gain cannot pay upfront")
	# 3 refund and failed atomic movement.
	s = fresh()
	a = Rules.assign(s, "res.anuan", "loc.hut", "fire")
	expect(s.resources.wood == 1, "escrow deducted")
	hash = Data.state_hash(s)
	expect(not Rules.assign(s, "res.anuan", "loc.mill", "thaw", a.assignment_id).ok and Data.state_hash(s) == hash, "failed move retains original")
	expect(Rules.unassign(s, a.assignment_id).ok and s.resources.wood == 2, "refund exact")
	expect(not Rules.unassign(s, a.assignment_id).ok and s.resources.wood == 2, "repeat undo no money")
	# 4 flood endpoint and pause; timeout completion priority.
	s = fresh()
	s.active_events = [{"id": "ev.peddler", "issued_day": 1, "remaining": 1}]
	s.locations["loc.river_bend"].blocked_until_day = 4
	s.locations["loc.old_bridge"].blocked_until_day = 4
	for d in range(3):
		var r := Rules.end_day(s)
		expect(r.ok and count(r.events, "event_paused") > 0, "three flooded nights pause %d" % d)
	expect(s.active_events.filter(func(e): return e.id == "ev.peddler")[0].remaining == 1, "paused timer unchanged")
	Rules.end_day(s)
	expect(s.day == 5 and s.locations["loc.river_bend"].blocked_until_day == 0 and s.locations["loc.flood_beach"].state == "thawed", "inclusive flood boundary and beach reveal")
	s = fresh()
	s.active_events = [{"id": "ev.peddler", "issued_day": 1, "remaining": 1}]
	Rules.assign(s, "res.toby", "loc.river_bend", "driftwood")
	Rules.end_day(s)
	expect(s.event_history["ev.peddler"].status == "completed", "last night completion wins")
	# 5 hidden person stays unavailable through fog until thaw.
	s = fresh()
	s.locations["loc.herb_garden"].state = "fog"
	expect(not Rules.assign(s, "res.mei", "loc.pines", "gather").ok, "hidden frozen resident unavailable")
	Rules.assign(s, "res.anuan", "loc.herb_garden", "explore")
	Rules.end_day(s)
	expect(s.locations["loc.herb_garden"].state == "frozen" and s.residents["res.mei"].status == "frozen", "explore reveals frozen resident")
	Rules.assign(s, "res.anuan", "loc.herb_garden", "thaw")
	var r := Rules.end_day(s)
	expect(s.residents["res.mei"].status == "awake" and count(r.events, "awaken") == 1, "thaw awakens exactly once next dawn")
	# 6 double before single combo, once only.
	s = fresh()
	Rules.assign(s, "res.toby", "loc.pines", "chop")
	Rules.assign(s, "res.mira", "loc.pines", "gather")
	r = Rules.end_day(s)
	var combo_events: Array = r.events.filter(func(e): return e.type == "combo")
	expect(combo_events[0].payload.id == "combo.toby_mira_pines", "double combo before single")
	expect(not use(s, "res.mira", "loc.pines", "gather").combo_hint, "old hint disappears")
	# 7 independent goal order + ending once.
	s = fresh()
	s.locations["loc.river_bend"].progress.dam = 2
	Rules.end_day(s)
	expect(s.goal_steps["goal.water"] and not s.goal_steps["goal.thaw_mill"], "water goal independent")
	s.locations["loc.mill"].state = "thawed"
	expect(not use(s, "res.anuan", "loc.mill", "warm_family").enabled, "family requires wheel and water")
	s.locations["loc.mill"].progress.wheel = 2
	Rules.end_day(s)
	s.resources.warmth = 3
	Rules.assign(s, "res.anuan", "loc.mill", "warm_family")
	r = Rules.end_day(s)
	expect(r.ending and s.chapter_complete, "all goals end chapter")
	expect(not Rules.end_day(s).ending, "ending emitted once free play continues")
	# 8 idle reminder third night only, reset streak on activity.
	s = fresh()
	var reminders := 0
	for d in range(4):
		r = Rules.end_day(s)
		for e in r.events:
			if e.type == "night_empty" and e.payload.reminder: reminders += 1
	expect(reminders == 1 and s.day == 5, "idle no failure; single reminder")
	Rules.assign(s, "res.anuan", "loc.pines", "gather")
	Rules.end_day(s)
	expect(s.idle_streak == 0, "action resets idle streak")
	# 9 two actions distinct locations only.
	s = fresh()
	s.spell_inventory.append("spell.two_actions")
	expect(Rules.use_spell(s, "spell.two_actions", "res.anuan").ok, "two actions spell")
	expect(Rules.assign(s, "res.anuan", "loc.pines", "gather").ok, "first spell action")
	expect(not Rules.assign(s, "res.anuan", "loc.pines", "gather").ok, "same location disallowed")
	expect(Rules.assign(s, "res.anuan", "loc.flower_slope", "explore").ok, "second distinct action")
	expect(not Rules.assign(s, "res.anuan", "loc.gravel", "explore").ok, "third action rejected")
	Rules.end_day(s)
	expect(s.day_modifiers.two_actions_resident == "", "spell resets at dawn")
	# 10 once-key reservation, cancellation, first execution and zero second fee.
	s = fresh()
	s.locations["loc.mill"].state = "thawed"
	s.resources = {"wood": 3, "stone": 2, "warmth": 0}
	a = Rules.assign(s, "res.toby", "loc.mill", "repair_wheel")
	expect(a.ok and s.resources.wood == 0 and s.resources.stone == 0, "full multi-resource fee escrow")
	Rules.unassign(s, a.assignment_id)
	expect(s.paid_once_keys.is_empty() and s.resources.stone == 2, "cancel does not pay once key")
	Rules.assign(s, "res.toby", "loc.mill", "repair_wheel")
	Rules.end_day(s)
	expect(s.paid_once_keys == ["mill.wheel_materials"] and s.resources.stone == 0, "once key paid exactly once")
	expect(use(s, "res.toby", "loc.mill", "repair_wheel").cost.is_empty(), "second repair free")
	Rules.assign(s, "res.toby", "loc.mill", "repair_wheel")
	Rules.end_day(s)
	expect(s.locations["loc.mill"].progress.wheel == 2 and not use(s, "res.toby", "loc.mill", "repair_wheel").enabled, "full progress disabled")
	# 11 extra flip skips booked fog; never recursively flips.
	s = fresh()
	s.locations["loc.herb_garden"].state = "fog"
	s.locations["loc.misty_bank"].state = "fog"
	s.spell_inventory.append("spell.extra_flip")
	Rules.use_spell(s, "spell.extra_flip")
	Rules.assign(s, "res.toby", "loc.flower_slope", "explore")
	Rules.assign(s, "res.mira", "loc.herb_garden", "explore")
	r = Rules.end_day(s)
	expect(count(r.events, "flip") == 4, "two explorations each flip at most one unreserved fog")
	var flipped := {}
	for e in r.events:
		if e.type == "flip": flipped[e.payload.loc] = true
	expect(flipped.size() == 4, "no fog double-flipped")
	# Deterministic true-data replay and idempotent dawn.
	var one := fresh()
	var two := fresh()
	for d in range(8):
		for state in [one, two]:
			Rules.assign(state, "res.toby", "loc.pines", "chop")
			Rules.end_day(state)
	expect(Data.state_hash(one) == Data.state_hash(two), "actual content deterministic replay")
	hash = Data.state_hash(one)
	Cycle.dawn(one, [])
	expect(hash == Data.state_hash(one), "dawn rewards idempotent")
	# Extra true-data protections: replacement, synthetic combo, OR pause, atomic night.
	s = fresh()
	a = Rules.assign(s, "res.anuan", "loc.hut", "fire")
	var moved := Rules.assign(s, "res.anuan", "loc.pines", "gather", a.assignment_id)
	expect(moved.ok and s.resources.wood == 2 and s.assignments.size() == 1, "successful move atomic refund")
	s = fresh()
	s.locations["loc.misty_bank"].state = "thawed"
	s.residents["res.beavers"].status = "awake"
	var synthetic := "combo:combo.mira_bank_kits"
	expect(use(s, "res.mira", "loc.misty_bank", synthetic).enabled, "combo-only stable synthetic use")
	Rules.assign(s, "res.mira", "loc.misty_bank", synthetic)
	expect(Rules.end_day(s).ok and s.locations["loc.river_bend"].progress.dam == 1, "synthetic action resolves actual combo")
	s = fresh()
	s.active_events = [{"id": "ev.peddler", "issued_day": 1, "remaining": 1}]
	s.locations["loc.old_bridge"].blocked_until_day = 4
	Rules.end_day(s)
	expect(s.event_history["ev.peddler"].status == "expired", "OR event not paused with one open location")
	s = fresh()
	var altered := defs.duplicate(true)
	s.defs = altered
	Rules.assign(s, "res.toby", "loc.pines", "chop")
	altered.locations[0].uses[0].ops.append({"op": "unknown_operation"})
	hash = Data.state_hash(s)
	expect(not Rules.end_day(s).ok and Data.state_hash(s) == hash, "invalid night operations rollback all gains")
	# Queue timers begin on issuance, never at trigger time.
	s = fresh()
	var queue_defs := defs.duplicate(true)
	queue_defs.events = []
	queue_defs.visitors = []
	for i in range(5):
		queue_defs.events.append({"id": "test.event%d" % i, "trigger": {"all": []}, "complete_when": {"any": []}, "duration": 2, "related_locations": [], "done_ops": [], "expire_ops": []})
	s.defs = queue_defs
	s.dawn_processed_day = 0
	s.active_events = []
	Cycle.dawn(s, [])
	expect(s.active_events.size() == 3 and s.queued_events.size() == 2, "event FIFO capped at three")
	Rules.end_day(s)
	expect(s.queued_events.size() == 2, "queued events do not lose duration")
	Rules.end_day(s)
	expect(s.active_events.size() == 2 and s.active_events[0].remaining == 2, "queued events start full timer on issue")
	# Public deterministic outcomes obey preview-first without exposing surprises.
	s = fresh()
	s.locations["loc.misty_bank"].state = "frozen"
	var bank_preview := use(s, "res.anuan", "loc.misty_bank", "thaw")
	expect(bank_preview.outcomes.any(func(o): return o.type == "awaken" and o.payload.resident == "res.beavers"), "bank thaw publicly previews beaver awakening")
	var fog_preview := use(s, "res.mira", "loc.flower_slope", "explore")
	expect(fog_preview.outcomes == [{"type": "flip", "payload": {"loc": "loc.flower_slope", "unknown": true}}], "fog preview promises flip without revealing destination content")
	s.locations["loc.misty_bank"].state = "thawed"
	s.residents["res.beavers"].status = "awake"
	var secret := use(s, "res.mira", "loc.misty_bank", "combo:combo.mira_bank_kits")
	expect(secret.combo_hint and secret.outcomes.is_empty() and secret.gain.is_empty(), "synthetic combo remains surprise hint without hidden progress")
	s.locations["loc.mill"].state = "thawed"
	s.locations["loc.mill"].progress.wheel = 1
	var progress_preview := use(s, "res.toby", "loc.mill", "repair_wheel")
	var progress_outcome: Dictionary = progress_preview.outcomes.filter(func(o): return o.type == "progress")[0].payload
	expect(progress_outcome.before == 1 and progress_outcome.after == 2 and progress_outcome.n == 1 and progress_outcome.completes, "progress preview makes completion explicit")
	expect(progress_preview.outcomes.any(func(o): return o.type == "goal_step" and o.payload.id == "goal.wheel"), "ordinary progress predicts public goal completion")
	content_fixtures()
	print("D1 rules: %d assertions, %d failures; replay %s" % [assertions, failures, Data.state_hash(two)])
	quit(0 if failures == 0 else 1)

func satisfy_fixture(s: Dictionary, c: Dictionary) -> void:
	if c.has("all"):
		for child in c.all: satisfy_fixture(s, child)
	elif c.has("any"): satisfy_fixture(s, c.any[0])
	elif c.has("assigned"): s.assignments.append({"resident_id": c.assigned, "location_id": c.loc})
	elif c.has("use_resolved"): s.resolved_uses.append({"use_id": c.use_resolved, "location_id": c.loc, "resident_id": c.resident})
	elif c.has("combo_done"): s.triggered_combos.append(c.combo_done)
	elif c.has("progress_at_least"): s.locations[c.loc].progress[c.progress_at_least] = c.n
	elif c.has("flag"): s.flags[c.flag] = c.value
	elif c.has("location_state"): s.locations[c.location_state].state = c.value

func content_fixtures() -> void:
	# Isolated prerequisite fixtures, NOT natural progression or reachability proof.
	# Preserved from independent audit so every content branch remains regression-tested.
	for combo in defs.combos:
		var s := fresh()
		for id in s.residents: s.residents[id].status = "awake"
		for id in s.locations: s.locations[id].state = "thawed"
		s.resources = {"wood": 99, "stone": 99, "warmth": 99}
		s.goal_steps["goal.wheel"] = true
		s.active_events = [{"id": "ev.dull_axe", "issued_day": 1, "remaining": 4}]
		for other in defs.combos:
			if other.id != combo.id: s.triggered_combos.append(other.id)
		for who in combo.who:
			var hash := Data.state_hash(s)
			var p := Rules.preview(s, who, combo.loc)
			expect(hash == Data.state_hash(s), combo.id + " preview pure")
			var assigned := false
			for u in p.uses:
				if u.enabled and (not combo.has("use_id") or combo.use_id == u.id):
					assigned = Rules.assign(s, who, combo.loc, u.id).ok
					break
			expect(assigned, combo.id + " has legal assignment")
		var r := Rules.end_day(s)
		expect(r.ok and combo.id in s.triggered_combos, combo.id + " resolves")
	for definition in defs.events + defs.visitors:
		for done in [false, true]:
			var s := fresh()
			s.active_events = [{"id": definition.id, "remaining": 1, "issued_day": 1}]
			if done: satisfy_fixture(s, definition.complete_when)
			expect(Cycle.settle(s, []), definition.id + " settlement succeeds")
			expect(s.event_history[definition.id].status == ("completed" if done else "expired"), definition.id + " correct outcome")
