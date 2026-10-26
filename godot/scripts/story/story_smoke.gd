extends SceneTree



const Rules = preload("res://scripts/core/day_rules.gd")
const Loader = preload("res://scripts/content/data_loader.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state := Rules.new_game(Loader.load_defs())
	var awaken = load("res://scripts/story/awaken_director.gd").new()
	check(awaken is Control, "awaken script compiles")
	awaken.free()
	var player = load("res://scripts/story/story_player.gd").new()
	root.add_child(player)
	# This fixture deliberately has no art. Production pages preflight all layers.
	var fixture := {"id":"fixture", "pages":[{"speaker":"narrator","text":"一页", "layers":[]},{"speaker":"narrator","text":"花", "layers":[], "when":{"flag":"mira_flower", "value":true}}]}
	player.play(fixture, state)
	check(player.pages.size() == 1, "conditional page hidden")
	player.advance()
	check(player.active, "first advance reveals text")
	player.advance()
	check(not player.active, "second advance completes")
	state.flags.mira_flower = true
	player.play(fixture, state)
	check(player.pages.size() == 2, "conditional page included")
	player.skip()
	check(not player.active, "skip closes modal")
	player.play({"pages":[{"text":"missing", "layers":[{"asset":"missing.required"}]}]}, state)
	check(not player.blocked_reason.is_empty() and player.active, "missing art blocks completion")
	player.skip()
	check(player.active, "blocked art cannot silently skip")
	# Validate every synchronized production sequence and atlas loop.
	for record: Dictionary in state.defs.pages:
		player.play(record, state)
		check(player.blocked_reason.is_empty(), "production sequence: " + str(record.id))
		if player.blocked_reason.is_empty():
			while player.active:
				player._process(3.0)
				player.advance()
	player.queue_free()
	awaken = load("res://scripts/story/awaken_director.gd").new()
	root.add_child(awaken)
	var calls := [0]
	awaken.play_awaken("res.mei", state, func(): calls[0] += 1)
	check(awaken.blocked_reason.is_empty(), "production awaken assets ready")
	if awaken.blocked_reason.is_empty():
		awaken._process(0.001)
		for i in 5: awaken._process(0.55)
		check(awaken._finished_animation, "three cracks and color restore complete")
		check(awaken._first.text.contains("姜茶"), "Mei first line follows frozen moment")
		awaken._memory()
		check(awaken._child.pages.size() == 2, "optional memory retains conditional flower page")
		awaken._child.skip()
		awaken._finish()
		check(calls[0] == 1, "completion callback once")
	awaken.queue_free()
	var banter = load("res://scripts/story/banter_director.gd").new()
	root.add_child(banter)
	state.defs = state.defs.duplicate(true)
	state.defs.banter = [{"id":"test","event":"drag_hover","speaker":"res.toby","when":{"all":[]},"lines":["嗯……"],"once":false,"chance":1,"priority":1,"match_resident":"res.toby","match_location":"loc.pines"}]
	banter.hover("res.toby", "loc.pines", state)
	banter._process(0.39)
	check(banter._seen.is_empty(), "hover waits 0.4 seconds")
	banter._process(0.02)
	check(banter._seen.has("test"), "hover triggers after dwell")
	check(banter.trigger("drag_hover", {"resident_id":"res.toby","location_id":"loc.pines"},state).is_empty(), "global cooldown")
	banter.clear_hover()
	banter._process(5.0)
	banter.hover("res.toby", "loc.pines", state)
	banter._process(0.5)
	check(banter._cycles.test == 1, "hover pair once per day")
	state.day += 1
	banter.hover("res.toby", "loc.pines", state)
	banter._process(0.5)
	check(banter._last > 5.0, "next day hover eligible")
	banter.mute_for_day("res.toby", state.day)
	check(not banter._voices.has("res.toby"), "mute stops pending talk tones")
	banter._process(5.0)
	check(banter.trigger("drag_hover", {"resident_id":"res.toby","location_id":"loc.pines"},state).is_empty(), "mute suppresses rest of day")
	state.day += 1
	check(not banter.trigger("drag_hover", {"resident_id":"res.toby","location_id":"loc.pines"},state).is_empty(), "mute expires next day")
	banter.queue_free()
	print("Story presentation smoke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
