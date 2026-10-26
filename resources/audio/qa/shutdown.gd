extends SceneTree
## Exercise the same root-window signal emitted by OS close, while all voice types run.
var failures := 0
func expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	await process_frame
	var audio = root.get_node("AudioService")
	audio.unlock()
	audio.set_restored_count(5)
	audio.play_music("music.day")
	await create_timer(0.1).timeout
	for i in 12:
		audio.play_sfx("sfx.ice_crack")
	audio.play_music("music.night")
	audio.play_music("music.day")
	audio.set_restored_count(2)
	await create_timer(0.05).timeout
	expect(audio._music[audio._music_slot].playing, "music active before OS close")
	expect(not auto_accept_quit, "close request allows bounded cleanup")
	paused = true
	Engine.time_scale = 0.0
	root.close_requested.emit()
	root.close_requested.emit() # Repeated requests must not schedule multiple exits.
	expect(audio._shutdown_started and not audio.enabled, "shutdown gates new playback")
	audio.unlock()
	audio.play_music("music.title")
	audio.play_sound("sfx.card_drop")
	audio.set_restored_count(5)
	expect(not audio.enabled, "late input cannot unlock during close")
	expect(audio._pending_id.is_empty(), "late music is not queued during close")
	expect(audio._music_tween == null and audio._layer_tween == null, "tween references released")
	for player in audio._music + audio._sfx + audio._ambient:
		expect(not player.playing and player.stream == null, "all voice streams cleared")
	await create_timer(0.15, true, false, true).timeout
	expect(audio._shutdown_started, "cleanup remains guarded while paused at zero timescale")
	print("Audio OS-close regression: ", failures, " failures; waiting for bounded service quit")
	if failures:
		quit(1)
	# Successful exit must come from AudioService, not this test.
