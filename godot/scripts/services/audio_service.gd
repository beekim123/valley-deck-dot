extends Node
## Native synchronized day stems share a playback clock; no seeking/polling approximation.
const MAX_SFX := 6
var enabled := false
var _sfx: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _ambient: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _music_slot := 0
var _music_tween: Tween
var _layer_tween: Tween
var _current_id := ""
var _pending_id := ""
var _restored_count := 0
var _day_stream: AudioStreamSynchronized

func _ready() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	for i in MAX_SFX:
		_sfx.append(_player("SFX"))
	for i in 2:
		_music.append(_player("Music"))
	# Nested ambient voices preserve the original bounded direct-child pool contract.
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		_music[0].add_child(player)
		_ambient.append(player)

func _player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		unlock()

func unlock() -> void:
	if enabled:
		return
	enabled = true
	if not _pending_id.is_empty():
		play_music(_pending_id)

func play_sound(id: String) -> void:
	play_sfx(id)

func play_sfx(id: String) -> void:
	if not enabled:
		return
	var stream := AssetCatalog.sound(id)
	if stream == null:
		return
	var player := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % MAX_SFX
	player.stop()
	player.stream = stream
	player.play()

func play_music(id: String) -> void:
	var canonical := "music.day" if id.begins_with("music.day") else id
	_pending_id = canonical
	if not enabled or canonical == _current_id:
		return
	var stream: AudioStream
	if canonical == "music.day":
		var synchronized := AudioStreamSynchronized.new()
		synchronized.stream_count = 3
		for i in 3:
			var stem := AssetCatalog.sound("music.day.l%d" % (i + 1))
			if stem == null:
				return
			synchronized.set_sync_stream(i, stem)
			synchronized.set_sync_stream_volume(i, _layer_db(i))
		_day_stream = synchronized
		stream = synchronized
	else:
		stream = AssetCatalog.sound(canonical)
	if stream == null:
		return
	_current_id = canonical
	if _layer_tween != null:
		_layer_tween.kill()
	if _music_tween != null:
		_music_tween.kill()
	var old := _music[_music_slot]
	_music_slot = 1 - _music_slot
	var next := _music[_music_slot]
	next.stop()
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(old, "volume_db", -60.0, 0.6)
	_music_tween.tween_property(next, "volume_db", 0.0, 0.6)
	_music_tween.chain().tween_callback(old.stop)
	_update_ambience()

func _layer_db(index: int) -> float:
	return 0.0 if index == 0 or (index == 1 and _restored_count >= 2) or (index == 2 and _restored_count >= 5) else -60.0

func set_restored_count(count: int) -> void:
	_restored_count = maxi(0, count)
	if _layer_tween != null:
		_layer_tween.kill()
	if _day_stream != null:
		_layer_tween = create_tween().set_parallel(true)
		for i in 3:
			_layer_tween.tween_method(_set_layer_gain.bind(i), _day_stream.get_sync_stream_volume(i), _layer_db(i), 1.0)
	_update_ambience()

func _set_layer_gain(db: float, index: int) -> void:
	if _day_stream != null:
		_day_stream.set_sync_stream_volume(index, db)

func _update_ambience() -> void:
	if not enabled or _ambient.is_empty():
		return
	for i in 2:
		var should_play := _current_id == "music.day" and (i == 0 or _restored_count >= 5)
		var player := _ambient[i]
		if should_play and not player.playing:
			player.stream = AssetCatalog.sound("amb.wind" if i == 0 else "amb.birds")
			player.volume_db = -18.0 if i == 0 else -22.0
			if player.stream != null:
				player.play()
		elif not should_play:
			player.stop()

func set_volumes(master: float, music: float, sfx: float) -> void:
	set_volume("Master", master)
	set_volume("Music", music)
	set_volume("SFX", sfx)

func set_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		var value := clampf(linear, 0.0, 1.0)
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.00001)))

func stop_all() -> void:
	if _music_tween != null:
		_music_tween.kill()
	if _layer_tween != null:
		_layer_tween.kill()
	for player: AudioStreamPlayer in _sfx + _music + _ambient:
		player.stop()
		player.stream = null
	_current_id = ""
	_pending_id = ""
	_day_stream = null

func _exit_tree() -> void:
	stop_all()
