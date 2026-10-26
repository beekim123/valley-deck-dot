extends SceneTree
var failures := 0
func expect(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	await process_frame
	var a = root.get_node("AudioService")
	expect(not a.enabled, "initial gate")
	a.play_music("music.title")
	expect(not a._music[1].playing, "preclick silent")
	a.unlock()
	await create_timer(0.7).timeout
	expect(a._music[a._music_slot].playing, "pending title starts")
	expect(a.get_child_count() == 8, "D0 direct pool stays 8")
	a.set_restored_count(0)
	a.play_music("music.day")
	await create_timer(0.7).timeout
	expect(a._day_stream.stream_count == 3, "three native sync streams")
	expect(a._music[a._music_slot].playing, "day playing")
	expect(a._day_stream.get_sync_stream_volume(1) == -60.0, "second layer initially muted")
	a.set_restored_count(2)
	await create_timer(1.1).timeout
	expect(a._day_stream.get_sync_stream_volume(1) == 0.0, "two restored activates strings")
	expect(a._day_stream.get_sync_stream_volume(2) == -60.0, "counterpoint still muted")
	a.set_restored_count(5)
	await create_timer(1.1).timeout
	expect(a._day_stream.get_sync_stream_volume(2) == 0.0, "five restored activates counterpoint")
	expect(a._ambient[1].playing, "birds start at five")
	var pos: float = a._music[a._music_slot].get_playback_position()
	a.play_music("music.day.l1")
	expect(a._music[a._music_slot].get_playback_position() >= pos, "same cue does not restart")
	a.set_restored_count(0)
	await create_timer(1.1).timeout
	expect(a._day_stream.get_sync_stream_volume(2) == -60.0, "decreasing restores fades down")
	expect(not a._ambient[1].playing, "birds stop below five")
	for i in 20:
		a.play_sound("sfx.card_drop")
	expect(a._sfx.size() == 6, "SFX bounded")
	a.set_volumes(0,0,0)
	for bus in ["Master","Music","SFX"]:
		expect(AudioServer.is_bus_mute(AudioServer.get_bus_index(bus)), "zero mutes " + bus)
	a.set_volumes(1,0.5,0.25)
	expect(not AudioServer.is_bus_mute(0), "nonzero unmutes")
	for id in ["music.night", "music.title", "music.memory", "music.ending"]:
		a.play_music(id)
		await create_timer(0.1).timeout
	await create_timer(0.7).timeout
	expect(a._music[a._music_slot].playing, "rapid switching leaves final cue playing")
	expect(not a._music[1-a._music_slot].playing, "old slot stopped after crossfade")
	a.stop_all()
	for p in a._music + a._sfx + a._ambient:
		expect(not p.playing and p.stream == null, "stop clears every voice")
	a.play_music("music.ending")
	await create_timer(0.7).timeout
	expect(a._music[a._music_slot].playing, "same cue restarts after stop_all")
	a.stop_all()
	await create_timer(0.15).timeout # Let the audio server release stopped playback references.
	print("Audio runtime: ", failures, " failures")
	quit(failures)
