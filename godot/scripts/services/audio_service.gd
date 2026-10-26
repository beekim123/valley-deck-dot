extends Node
## D0: click-gated bounded SFX pool and two music slots; layering follows in D2.
const MAX_SFX := 6
var enabled := false
var _sfx: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _music_slot := 0
var _music_tween: Tween

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

func _player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player

func unlock() -> void:
	enabled = true

func play_sfx(id: String) -> void:
	if not enabled:
		return
	var stream := AssetCatalog.sound(id)
	if stream == null:
		return
	var player := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % MAX_SFX
	player.stream = stream
	player.play()

func play_music(id: String) -> void:
	if not enabled:
		return
	var stream := AssetCatalog.sound(id)
	if stream == null:
		return
	if _music_tween != null:
		_music_tween.kill()
	var old := _music[_music_slot]
	_music_slot = 1 - _music_slot
	var next := _music[_music_slot]
	next.stream = stream
	next.volume_db = -60.0
	next.play()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(old, "volume_db", -60.0, 0.6)
	_music_tween.tween_property(next, "volume_db", 0.0, 0.6)
	_music_tween.chain().tween_callback(old.stop)

func set_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))

func stop_all() -> void:
	if _music_tween != null:
		_music_tween.kill()
	for player: AudioStreamPlayer in _sfx + _music:
		player.stop()
		player.stream = null

func _exit_tree() -> void:
	stop_all()
