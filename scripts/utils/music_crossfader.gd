# MusicCrossfader.gd
# Reusable music crossfader (creates its own two AudioStreamPlayers).
#
# Timed:    play_track(stream, fade_seconds, sync_position, pitch)
# Manual:   begin_blend(stream, pitch)  then call set_blend(0..1) every frame
#           (e.g. from player distance). At 1.0 the old track stops automatically.
class_name MusicCrossfader
extends Node

@export var bus: StringName = &"Master"
@export var default_fade := 2.0
@export var volume_db := 0.0
## Replays the track when it ends (use this if the stream's own loop flag is off).
@export var loop_tracks := true
@export_group("Manual blend")
## How quickly the blend follows set_blend() (higher = snappier, 0 = no smoothing).
@export var blend_smoothing := 4.0
## While blending, glide both tracks' pitch from the old pitch to the new one.
@export var blend_pitch := true

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: AudioStreamPlayer
var _incoming: AudioStreamPlayer
var _tween: Tween
var _current_pitch := 1.0

var _blending := false
var _blend := 0.0
var _blend_target := 0.0
var _from_pitch := 1.0
var _to_pitch := 1.0
var _split := -1.0            # >= 0: sequential (old fades out, THEN new fades in)
var _sync := false
var _incoming_started := false


func _ensure_init() -> void:
	if _a != null:
		return
	_a = _make_player()
	_b = _make_player()
	_current = _a


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.finished.connect(_on_finished.bind(p))
	return p


func _on_finished(p: AudioStreamPlayer) -> void:
	if loop_tracks and (p == _current or p == _incoming):
		p.play()


func is_blending() -> bool:
	return _blending


# ---------------------------------------------------------------- timed crossfade

## Crossfade over `fade` seconds. fade < 0 uses default_fade, 0 switches instantly.
## sync_position: start at the same time offset as the old track.
func play_track(stream: AudioStream, fade := -1.0, sync_position := false, pitch := 1.0) -> void:
	_ensure_init()
	if stream == null:
		return
	if _blending:
		finish_blend()
	if _current.stream == stream and _current.playing and is_equal_approx(_current_pitch, pitch):
		return
	if fade < 0.0:
		fade = default_fade

	var old := _current
	var incoming := _b if old == _a else _a
	var start_at := old.get_playback_position() if (sync_position and old.playing) else 0.0

	if _tween:
		_tween.kill()

	incoming.stream = stream
	incoming.pitch_scale = pitch
	incoming.volume_db = -80.0
	incoming.play(start_at)
	_current = incoming
	_current_pitch = pitch

	if fade <= 0.0:
		old.stop()
		incoming.volume_db = volume_db
		return

	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_volume.bind(incoming, true), 0.0, 1.0, fade)
	if old.playing:
		_tween.tween_method(_set_volume.bind(old, false), 0.0, 1.0, fade)
		_tween.chain().tween_callback(old.stop)


func stop(fade := -1.0) -> void:
	_ensure_init()
	if _blending:
		finish_blend()
	if fade < 0.0:
		fade = default_fade
	if _tween:
		_tween.kill()
	if fade <= 0.0 or not _current.playing:
		_current.stop()
		return
	_tween = create_tween()
	_tween.tween_method(_set_volume.bind(_current, false), 0.0, 1.0, fade)
	_tween.tween_callback(_current.stop)


func _set_volume(w: float, p: AudioStreamPlayer, fading_in: bool) -> void:
	_set_gain(p, w if fading_in else 1.0 - w)


# ---------------------------------------------------------------- manual blend

## Start the new track silently. Then drive it with set_blend(0..1).
func begin_blend(stream: AudioStream, pitch := 1.0, sync_position := false) -> void:
	_ensure_init()
	if stream == null:
		return
	if _blending:
		finish_blend()
	if not _current.playing:
		play_track(stream, 0.0, false, pitch)   # nothing to blend from
		return
	if _current.stream == stream and is_equal_approx(_current_pitch, pitch):
		return
	if _tween:
		_tween.kill()

	_incoming = _b if _current == _a else _a
	_incoming.stream = stream
	_incoming.pitch_scale = pitch
	_incoming.volume_db = -80.0
	_incoming.stop()              # starts only once it becomes audible (see _apply_blend)
	_incoming_started = false
	_sync = sync_position
	_split = -1.0

	_from_pitch = _current_pitch
	_to_pitch = pitch
	_blend = 0.0
	_blend_target = 0.0
	_blending = true
	_apply_blend()


## 0 = only the old track, 1 = only the new one. Safe to call every frame.
## split < 0: normal crossfade (both audible at once).
## split in 0..1: sequential. The old track reaches silence at weight == split,
## then the new track fades in from split to 1 (they never overlap).
func set_blend(weight: float, split := -1.0) -> void:
	if _blending:
		_blend_target = clampf(weight, 0.0, 1.0)
		_split = split


## Snap to the new track right now.
func finish_blend() -> void:
	if not _blending:
		return
	_blending = false
	if not _incoming_started:
		_incoming.play(_current.get_playback_position() if _sync else 0.0)
	_current.stop()
	_current = _incoming
	_incoming = null
	_current_pitch = _to_pitch
	_current.pitch_scale = _to_pitch
	_current.volume_db = volume_db


## Abort a manual blend and return to the old track.
func cancel_blend() -> void:
	if not _blending:
		return
	_blending = false
	_incoming.stop()
	_incoming = null
	_current.volume_db = volume_db
	_current.pitch_scale = _from_pitch


func _process(delta: float) -> void:
	if not _blending:
		return
	if blend_smoothing > 0.0:
		_blend = lerpf(_blend, _blend_target, 1.0 - exp(-blend_smoothing * delta))
	else:
		_blend = _blend_target
	_apply_blend()
	if _blend_target >= 1.0 and _blend >= 0.995:
		finish_blend()


func _apply_blend() -> void:
	var out_gain := 1.0 - _blend
	var in_gain := _blend
	if _split >= 0.0:
		out_gain = 1.0 - clampf(_blend / maxf(_split, 0.0001), 0.0, 1.0)
		in_gain = clampf((_blend - _split) / maxf(1.0 - _split, 0.0001), 0.0, 1.0)

	# Start the new track only when it becomes audible, so its intro isn't wasted
	if in_gain > 0.0 and not _incoming_started:
		_incoming_started = true
		_incoming.play(_current.get_playback_position() if _sync else 0.0)

	_set_gain(_current, out_gain)
	_set_gain(_incoming, in_gain)

	if blend_pitch and _split < 0.0:
		var p := maxf(lerpf(_from_pitch, _to_pitch, _blend), 0.01)
		_current.pitch_scale = p
		_incoming.pitch_scale = p
	else:
		_incoming.pitch_scale = _to_pitch


func _set_gain(p: AudioStreamPlayer, gain: float) -> void:
	p.volume_db = linear_to_db(maxf(gain, 0.0001)) + volume_db
