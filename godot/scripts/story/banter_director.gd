extends Node
## Presentation-only selection: deterministic cycling, no gameplay RNG consumption.
signal bubble_requested(speaker: String, text: String)
signal bubble_expired(speaker: String)
const Data = preload("res://scripts/core/rule_data.gd")
const COOLDOWN := 4.0
const HOVER_DELAY := 0.4
var _clock := 0.0
var _last := -100.0
var _speaker_until: Dictionary = {}
var _seen: Dictionary = {}
var _cycles: Dictionary = {}
var _hover_pairs: Dictionary = {}
var _hover_key := ""
var _hover_time := 0.0
var _hover_payload: Dictionary = {}
var _hover_state: Dictionary = {}
var _voices: Dictionary = {}
var muted_speakers: Dictionary = {}

func trigger(event: String, payload: Dictionary, state: Dictionary) -> Dictionary:
	if _clock - _last < COOLDOWN: return {}
	var candidates: Array = []
	for row: Dictionary in state.get("defs", {}).get("banter", []):
		if str(row.event) != event: continue
		if muted_speakers.get(str(row.speaker), -1) == int(state.get("day", 0)): continue
		if row.get("once", false) and _seen.has(row.id): continue
		if row.has("match_id") and str(payload.get("id", "")) != str(row.match_id): continue
		if row.has("match_resident") and str(payload.get("resident_id", payload.get("res", ""))) != str(row.match_resident): continue
		if row.has("match_location") and str(payload.get("location_id", payload.get("loc", ""))) != str(row.match_location): continue
		if not Data.condition(state, row.get("when", {"all": []})): continue
		if _clock < float(_speaker_until.get(str(row.speaker), -1.0)): continue
		# Stable chance sampling avoids changing the rule engine's RNG state.
		var roll := posmod((str(row.id) + ":" + str(state.get("day", 0)) + ":" + str(_cycles.get(row.id, 0))).hash(), 10000) / 10000.0
		if roll >= float(row.get("chance", 1.0)): continue
		candidates.append(row)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.priority) > int(b.priority))
	if candidates.is_empty(): return {}
	var selected: Dictionary = candidates[0]
	var lines: Array = selected.get("lines", [])
	if lines.is_empty(): return {}
	var index := int(_cycles.get(selected.id, 0)) % lines.size()
	var text := str(lines[index])
	if text.length() > 18:
		push_error("Banter exceeds 18 characters: " + str(selected.id))
		return {}
	var speaker := str(selected.speaker)
	var duration := 2.5 + text.length() * 0.08
	_last = _clock
	_seen[selected.id] = true
	_cycles[selected.id] = index + 1
	_speaker_until[speaker] = _clock + maxf(COOLDOWN, duration)
	_voices[speaker] = {"remaining": text.length(), "next": _clock, "expires": _clock + duration}
	bubble_requested.emit(speaker, text)
	return {"id": selected.id, "speaker": speaker, "text": text, "duration": duration}

func mute_for_day(speaker: String, day: int) -> void:
	muted_speakers[speaker] = day
	_voices.erase(speaker)
	bubble_expired.emit(speaker)

func hover(resident_id: String, location_id: String, state: Dictionary) -> void:
	var key := "%s|%s|%s" % [state.get("day", 0), resident_id, location_id]
	if key == _hover_key: return
	_hover_key = key
	_hover_time = 0.0
	_hover_state = state
	_hover_payload = {"resident_id": resident_id, "location_id": location_id}
	# Daily keys cannot collide; keep only this day's records.
	for previous: String in _hover_pairs.keys():
		if not previous.begins_with(str(state.get("day", 0)) + "|"): _hover_pairs.erase(previous)

func clear_hover() -> void:
	_hover_key = ""
	_hover_time = 0.0
	_hover_state = {}
	_hover_payload = {}

func _process(delta: float) -> void:
	_clock += delta
	if not _hover_key.is_empty() and not _hover_pairs.has(_hover_key):
		_hover_time += delta
		if _hover_time >= HOVER_DELAY:
			var result := trigger("drag_hover", _hover_payload, _hover_state)
			if not result.is_empty(): _hover_pairs[_hover_key] = true
	for speaker: String in _voices.keys():
		var voice: Dictionary = _voices[speaker]
		if _clock >= float(voice.expires):
			_voices.erase(speaker)
			bubble_expired.emit(speaker)
			continue
		if int(voice.remaining) > 0 and _clock >= float(voice.next):
			var tone := "talk." + speaker.trim_prefix("res.")
			if speaker not in ["narrator", "bo"] and AssetCatalog.has_audio(tone): AudioService.play_sfx(tone)
			voice.remaining = int(voice.remaining) - 1
			voice.next = _clock + 0.08
