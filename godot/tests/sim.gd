extends SceneTree
## `-- --quick` is smoke-only; normal mode is the full, hard acceptance gate.
const Rules = preload("res://scripts/core/day_rules.gd")
const Data = preload("res://scripts/core/rule_data.gd")
const Loader = preload("res://scripts/content/data_loader.gd")
const Bots = preload("res://scripts/core/bots.gd")
var output_dir := ""
var defs: Dictionary
var implementation_hashes: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _write(name: String, value: Variant) -> void:
	var file := FileAccess.open(output_dir.path_join(name), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write simulation evidence: " + name)
		quit(2)
		return
	file.store_string(JSON.stringify(Data.canonical(value), "\t") + "\n")

func _invariants(state: Dictionary) -> Array:
	var errors: Array = []
	for resource in ["wood", "stone", "warmth"]:
		if state.resources.get(resource, -1) < 0: errors.append("negative_resource:" + resource)
	if state.active_events.size() > 3: errors.append("event_capacity")
	var ids := {}
	var persons := {}
	var places := {}
	for assignment in state.assignments:
		if ids.has(assignment.id): errors.append("duplicate_assignment")
		ids[assignment.id] = true
		persons[assignment.resident_id] = int(persons.get(assignment.resident_id, 0)) + 1
		places[assignment.location_id] = int(places.get(assignment.location_id, 0)) + 1
		for resource in assignment.escrow:
			if assignment.escrow[resource] < 0: errors.append("negative_escrow")
	for resident in persons:
		var limit := 2 if state.day_modifiers.get("two_actions_resident", "") == resident else 1
		if persons[resident] > limit: errors.append("action_limit:" + resident)
	for loc in places:
		var limit := 1 if state.locations[loc].state == "fog" else 3
		if places[loc] > limit: errors.append("location_capacity:" + loc)
	return errors

func _minimum(minimum: Dictionary, resources: Dictionary) -> void:
	for key in minimum: minimum[key] = mini(minimum[key], int(resources[key]))

func _novelty(events: Array, day: int, notes_seen: Dictionary, progress_seen: Dictionary) -> Dictionary:
	var kinds: Array = []
	var fallback_story := 0
	var fallback_visitors := 0
	for event in events:
		if int(event.day) != day: continue
		var type: String = event.type
		var payload: Dictionary = event.get("payload", {})
		if type in ["flip", "combo", "event_new", "awaken", "restore", "goal_step"]:
			if not type in kinds: kinds.append(type)
		if type == "progress":
			var key: String = str(payload.get("loc", "")) + ":" + str(payload.get("key", ""))
			var value: int = int(payload.get("n", 0))
			if payload.get("key", "") in ["wheel", "dam"] and value > int(progress_seen.get(key, 0)):
				if not "goal_progress" in kinds: kinds.append("goal_progress")
			progress_seen[key] = value
		if type == "event_new" and str(payload.get("id", "")).begins_with("vis."):
			fallback_visitors += 1
		if type == "story":
			var id: String = payload.get("id", "")
			# Only first-time notebook pages count; ordinary/repeated story isn't novelty.
			if (id.begins_with("note.") or id.contains("note1") or id.contains("note2") or id.contains("note3")) and not notes_seen.has(id):
				notes_seen[id] = true
				if not "note" in kinds: kinds.append("note")
			if payload.get("fallback", false) or id.contains("fallback") or id.contains("reminiscence") or id.contains("memory"):
				fallback_story += 1
	return {"new": not kinds.is_empty(), "kinds": kinds, "fallback_story": fallback_story, "fallback_visitors": fallback_visitors}

func _trial(strategy: String, seed_value: int, limit: int, recover_day: int = 0, initial_state: Dictionary = {}) -> Dictionary:
	var state: Dictionary = Rules.new_game(defs, seed_value) if initial_state.is_empty() else Data.clone(initial_state)
	state.defs = defs
	var bot := Bots.context(strategy, seed_value)
	var rows: Array = []
	var errors: Array = _invariants(state)
	var minimum: Dictionary = state.resources.duplicate()
	var white_days := 0
	var notes_seen := {}
	var progress_seen := {}
	for loc in state.locations:
		for key in state.locations[loc].progress:
			progress_seen[loc + ":" + key] = state.locations[loc].progress[key]
	var counts := {"event_new": 0, "event_done": 0, "event_expire": 0, "event_paused": 0, "fallback_story": 0, "fallback_visitors": 0}
	var prior_goals: Dictionary = state.goal_steps.duplicate()
	var prior_combos: Array = []
	while state.day <= limit and not state.chapter_complete and errors.is_empty():
		var day: int = state.day
		if recover_day > 0 and day == recover_day:
			bot = Bots.context("goal", seed_value)
		var dawn_events: Array = state.get("last_day_events", []).duplicate(true)
		var played := Bots.play_day(state, bot)
		errors.append_array(played.errors)
		errors.append_array(_invariants(state))
		for command in played.commands:
			if command.has("resources_after"): _minimum(minimum, command.resources_after)
		if strategy == "lazy" and state.assignments.size() > 1: errors.append("lazy_more_than_one_action")
		var result: Dictionary = Rules.end_day(state)
		if not result.ok: errors.append({"end_day": result}); break
		errors.append_array(_invariants(state))
		_minimum(minimum, state.resources)
		for id in prior_goals:
			if prior_goals[id] and not state.goal_steps[id]: errors.append("goal_regressed:" + id)
		for id in prior_combos:
			if not id in state.triggered_combos: errors.append("combo_regressed:" + id)
		prior_goals = state.goal_steps.duplicate()
		prior_combos = state.triggered_combos.duplicate()
		var today_events: Array = played.events.duplicate(true)
		# last_day_events includes current dawn from previous end_day; don't count
		# tomorrow's dawn against today's novelty.
		for event in dawn_events:
			if int(event.day) == day: today_events.append(event)
		for event in result.events:
			if int(event.day) == day: today_events.append(event)
		var novelty := _novelty(today_events, day, notes_seen, progress_seen)
		if not novelty.new: white_days += 1
		for event in today_events:
			if counts.has(event.type): counts[event.type] += 1
		counts.fallback_story += novelty.fallback_story
		counts.fallback_visitors += novelty.fallback_visitors
		rows.append({"day": day, "policy": bot.strategy, "commands": played.commands, "resources": state.resources.duplicate(), "resource_minimum": minimum.duplicate(), "goals": state.goal_steps.duplicate(), "combos": state.triggered_combos.duplicate(), "events": today_events, "novelty": novelty, "hash": Data.state_hash(state)})
	var report := {"strategy": strategy, "seed": seed_value, "limit": limit, "recovery_switch_day": recover_day, "complete": state.chapter_complete, "days": rows.size(), "white_days": white_days, "white_fraction": float(white_days) / maxi(1, rows.size()), "combo_count": state.triggered_combos.size(), "combo_fraction": float(state.triggered_combos.size()) / maxi(1, Data.records(defs, "combos").size()), "resource_minimum": minimum, "event_counts": counts, "event_history": state.event_history.duplicate(true), "errors": errors, "final_hash": Data.state_hash(state), "days_detail": rows}
	if not state.chapter_complete or not errors.is_empty(): report.failure_state = Data.snapshot(state)
	return report

func _aggregate(runs: Array) -> Dictionary:
	var complete := 0
	var white := 0
	var days := 0
	var combo_sum := 0.0
	var minimum := {"wood": 2147483647, "stone": 2147483647, "warmth": 2147483647}
	var failures: Array = []
	var duration: Array = []
	var storm_done := 0
	var storm_seen := 0
	var safety_failures: Array = []
	for run in runs:
		if run.complete: complete += 1
		else: failures.append(run.seed)
		if not run.errors.is_empty(): safety_failures.append(run.seed)
		white += int(run.white_days)
		days += int(run.days)
		combo_sum += run.combo_fraction
		duration.append(run.days)
		_minimum(minimum, run.resource_minimum)
		if run.event_history.has("ev.storm"):
			storm_seen += 1
			if run.event_history["ev.storm"].status == "completed": storm_done += 1
	return {"runs": runs.size(), "completed": complete, "incomplete_seeds": failures, "safety_failure_seeds": safety_failures, "days": duration, "white_fraction": float(white) / maxi(1, days), "mean_combo_fraction": combo_sum / maxi(1, runs.size()), "resource_minimum": minimum, "storm_completed": storm_done, "storm_resolved": storm_seen, "storm_completion_fraction": float(storm_done) / maxi(1, storm_seen)}

func _run() -> void:
	defs = Loader.load_defs()
	for source in ["res://scripts/core/bots.gd", "res://tests/sim.gd", "res://scripts/core/day_rules.gd", "res://scripts/core/day_cycle.gd", "res://scripts/core/rule_data.gd"]:
		implementation_hashes[source] = FileAccess.get_file_as_string(source).sha256_text()
	if Data.records(defs, "goals").size() != 4 or Data.records(defs, "combos").size() != 17:
		push_error("Full D1 data required; sync actual content before simulation")
		quit(2)
		return
	if "--exploratory" in OS.get_cmdline_user_args() or "--long-random" in OS.get_cmdline_user_args():
		_run_experiment("--exploratory" in OS.get_cmdline_user_args())
		return
	var quick := "--quick" in OS.get_cmdline_user_args()
	output_dir = ProjectSettings.globalize_path("res://../.local/sim/" + ("quick" if quick else "full"))
	DirAccess.make_dir_recursive_absolute(output_dir)
	var all_runs := {}
	var aggregates := {}
	var failed: Array = []
	for strategy in ["goal", "lazy", "random", "recovery"]:
		var count := (3 if quick else 200) if strategy == "random" else (1 if quick else (20 if strategy == "recovery" else 12))
		var runs: Array = []
		for seed_value in range(1, count + 1):
			var policy: String = "random" if strategy == "recovery" else strategy
			var run := _trial(policy, seed_value, 80 if strategy == "recovery" else 60, 21 if strategy == "recovery" else 0)
			runs.append(run)
			_write("%s-%03d.json" % [strategy, seed_value], run)
		all_runs[strategy] = runs
		aggregates[strategy] = _aggregate(runs)
		print("SIM %s: %s" % [strategy, JSON.stringify(aggregates[strategy])])
		if not aggregates[strategy].safety_failure_seeds.is_empty(): failed.append(strategy + ": safety invariant")
		if aggregates[strategy].completed != count: failed.append(strategy + ": incomplete seed(s)")
	var failure_recoveries: Array = []
	for failed_run in all_runs.random:
		if failed_run.complete: continue
		var recovered := _trial("goal", failed_run.seed, 120, 0, failed_run.failure_state)
		recovered.recovery_origin = "pure random day-60 final state; explicit goal rescue, excluded from random metric"
		failure_recoveries.append(recovered)
		_write("failure-recovery-%03d.json" % failed_run.seed, recovered)
	aggregates.failure_recovery = _aggregate(failure_recoveries)
	print("SIM failure_recovery: " + JSON.stringify(aggregates.failure_recovery))
	if aggregates.failure_recovery.completed != failure_recoveries.size() or not aggregates.failure_recovery.safety_failure_seeds.is_empty(): failed.append("failure recovery: unreachable or unsafe sampled state")
	# Re-run a whole seed independently; evidence includes every command and event.
	for strategy in ["goal", "lazy", "random"]:
		var replay := _trial(strategy, 1, 60)
		if JSON.stringify(Data.canonical(replay)) != JSON.stringify(Data.canonical(all_runs[strategy][0])):
			failed.append(strategy + ": non-deterministic replay")
	for days in aggregates.goal.days:
		if days < 10 or days > 14: failed.append("goal: expected 10–14 days"); break
	for days in aggregates.lazy.days:
		if days > 40: failed.append("lazy: expected <=40 days"); break
	if aggregates.goal.white_fraction > 0.0: failed.append("goal: nonzero no-novelty days")
	if aggregates.random.white_fraction > 0.10: failed.append("random: no-novelty >10%")
	if aggregates.random.mean_combo_fraction < 0.60: failed.append("random: combo coverage <60%")
	if aggregates.goal.storm_completion_fraction < 0.30 or aggregates.goal.storm_completion_fraction > 0.60: failed.append("goal family: storm completion outside 30–60%")
	var summary := {"format": "valley-simulation/1", "implementation_sha256": implementation_hashes, "mode": "quick_smoke_not_acceptance" if quick else "full_acceptance", "content_sha256": JSON.stringify(Data.canonical(defs)).sha256_text(), "godot": Engine.get_version_info().string, "seed_schedule": "contiguous integers starting at 1 for each strategy", "random_distribution": "Park–Miller seed; Fisher–Yates resident order; uniform legal (location,use) plus one rest per awake resident; no spell use; no takeover", "goal_preferences": "seed % 3: neutral / riverbank +45 / herb garden +45", "recovery": "separate runs: random days 1–20, explicit goal strategy days 21–80; never counted as pure random", "novelty": "flip/combo/event_new/awaken/restore/goal_step/positive wheel or dam progress/first notebook; current-day dawn attributed to that day; generic stories do not count", "results": aggregates, "failures": failed, "passed": failed.is_empty() and not quick}
	_write("summary.json", summary)
	print("SIM report: " + output_dir.path_join("summary.json"))
	print("SIM " + ("QUICK SMOKE (not acceptance)" if quick else "FULL ACCEPTANCE") + ": " + ("PASS" if failed.is_empty() else "FAIL " + JSON.stringify(failed)))
	quit(0 if failed.is_empty() else 1)

func _run_experiment(exploratory: bool) -> void:
	var label := "exploratory" if exploratory else "long-random"
	var policy := "exploratory_random" if exploratory else "random"
	var limit := 60 if exploratory else 180
	output_dir = ProjectSettings.globalize_path("res://../.local/sim/" + label)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var runs: Array = []
	for seed_value in range(1, 201):
		var run := _trial(policy, seed_value, limit)
		runs.append(run)
		_write("%s-%03d.json" % [label, seed_value], run)
	var result := _aggregate(runs)
	var replay := _trial(policy, 1, limit)
	var deterministic: bool = JSON.stringify(Data.canonical(replay)) == JSON.stringify(Data.canonical(runs[0]))
	var report := {"format": "valley-simulation/1", "mode": "experiment_not_original_acceptance", "experiment": label, "limit": limit, "content_sha256": JSON.stringify(Data.canonical(defs)).sha256_text(), "implementation_sha256": implementation_hashes, "seeds": "integers 1–200", "policy": "constant from day1: all legal actions weight1; visible usable combo_hint+8; explore/thaw+8; public repair_wheel/warm_family/build_dam+20; rest weight1; no late takeover; no spells" if exploratory else "unchanged uniform random; only observation window extended to180days", "deterministic_replay": deterministic, "novelty": "includes actual positive wheel/dam progress; capped zero delta and repeated fallback excluded", "results": result, "original_acceptance_passed": false}
	_write("summary.json", report)
	print("SIM EXPERIMENT " + label + " (NOT original acceptance): " + JSON.stringify(result))
	print("SIM report: " + output_dir.path_join("summary.json"))
	# Only safety/replay is gated here; distribution and time horizon differ.
	quit(0 if deterministic and result.safety_failure_seeds.is_empty() else 1)
