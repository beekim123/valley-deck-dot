extends SceneTree
## Integration checks: actual title, semantic resources, font glyphs and repeated UI actions.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	var title: Node = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var catalog := root.get_node("AssetCatalog")
	var audio := root.get_node("AudioService")
	expect(catalog.texture("locart.pines.winter").get_size() == Vector2(64, 48), "winter frame size")
	expect(catalog.texture("locart.pines.spring").get_size() == Vector2(64, 48), "spring frame size")
	expect(catalog.texture("portrait.toby").get_size() == Vector2(40, 40), "portrait frame size")
	var music: AudioStreamWAV = catalog.sound("music.test")
	expect(music.format == AudioStreamWAV.FORMAT_16_BITS, "music remains lossless PCM16")
	expect(music.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music loops forward")
	expect(music.loop_end == int(catalog.metadata("music.test").frames), "loop end follows manifest")
	expect(catalog.sound("sfx.card_drop").loop_mode == AudioStreamWAV.LOOP_DISABLED, "SFX does not loop")
	var font: Font = catalog.pixel_font()
	for character: String in "一副山谷托比春冬暖意":
		expect(font.has_char(character.unicode_at(0)), "Chinese glyph " + character)
	expect(not audio.enabled, "audio waits for first interaction")
	for i in 12:
		title.switch_button.pressed.emit()
	expect(not title.spring, "repeated toggles return to winter")
	expect(audio.enabled, "click unlocks audio")
	expect(audio.get_child_count() == 8, "SFX/music pool remains bounded")
	title.music_button.pressed.emit()
	await create_timer(0.7).timeout
	expect(title.music_started, "music preview button invokes service")
	expect(audio._music[audio._music_slot].playing, "music stream is playing")
	audio.stop_all()
	await create_timer(0.1).timeout
	title.queue_free()
	await process_frame
	print("D0 title integration: %d failures" % failures)
	quit(0 if failures == 0 else 1)
