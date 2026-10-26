extends SceneTree
## Run graphically after unified build+sync. -- --story-shots-dir=/absolute/path
const Loader = preload("res://scripts/content/data_loader.gd")
const Rules = preload("res://scripts/core/day_rules.gd")
var output := "user://story-shots"
func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--story-shots-dir="): output = arg.trim_prefix("--story-shots-dir=")
	call_deferred("run")
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	if error != OK:
		push_error("Story screenshot failed: " + str(error))
		quit(1)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var state := Rules.new_game(Loader.load_defs())
	state.flags.mira_flower = true
	var player = load("res://scripts/story/story_player.gd").new()
	root.add_child(player)
	player.text_speed = 0.0
	for sequence: String in ["story.intro", "story.note1", "story.note2", "story.note3", "story.wake.mei", "story.ending"]:
		player.play(sequence, state)
		if not player.blocked_reason.is_empty():
			push_error(player.blocked_reason)
			quit(1)
			return
		await process_frame
		await capture(sequence.replace(".", "-") + "-1")
		if sequence == "story.wake.mei":
			player.advance()
			await process_frame
			await capture("story-wake-mei-2")
			player.advance()
			await process_frame
			await capture("story-wake-mei-flower")
	player.queue_free()
	await process_frame
	var awaken = load("res://scripts/story/awaken_director.gd").new()
	root.add_child(awaken)
	awaken.play_awaken("res.mei", state)
	if not awaken.blocked_reason.is_empty():
		push_error(awaken.blocked_reason)
		quit(1)
		return
	await create_timer(1.75).timeout
	await capture("awaken-three-cracks")
	await create_timer(1.3).timeout
	await capture("awaken-first-line")
	awaken._memory()
	await create_timer(1.0).timeout
	await capture("awaken-optional-memory")
	awaken.queue_free()
	print("Story screenshots saved: " + output)
	quit()
