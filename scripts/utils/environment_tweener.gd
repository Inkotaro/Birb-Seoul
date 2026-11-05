# EnvironmentTweener.gd
# Reusable: blends a WorldEnvironment toward any other Environment resource.
# Usage:  $EnvironmentTweener.tween_to(my_environment, 3.0)
class_name EnvironmentTweener
extends Node

signal finished

@export var world_environment: WorldEnvironment
@export var default_duration := 3.0
@export var default_trans := Tween.TRANS_SINE
@export var default_ease := Tween.EASE_IN_OUT
## Progress (0..1) at which non-blendable things (enums, panorama skies) get swapped.
@export_range(0.0, 1.0) var snap_point := 0.5

# Properties that are smoothly blended (floats, colors, vectors). Add more if you need them.
const LERP_PROPS: Array[StringName] = [
	&"background_color", &"background_energy_multiplier",
	&"ambient_light_color", &"ambient_light_sky_contribution", &"ambient_light_energy",
	&"fog_light_color", &"fog_light_energy", &"fog_sun_scatter", &"fog_density",
	&"fog_aerial_perspective", &"fog_sky_affect", &"fog_height", &"fog_height_density",
	&"fog_depth_curve", &"fog_depth_begin", &"fog_depth_end",
	&"volumetric_fog_density", &"volumetric_fog_albedo", &"volumetric_fog_emission",
	&"volumetric_fog_emission_energy", &"volumetric_fog_anisotropy", &"volumetric_fog_length",
	&"tonemap_exposure", &"tonemap_white",
	&"glow_intensity", &"glow_strength", &"glow_bloom", &"glow_hdr_threshold",
	&"adjustment_brightness", &"adjustment_contrast", &"adjustment_saturation",
	&"sky_rotation",
]

# Enums / modes: can't be blended, applied at snap_point.
const SNAP_PROPS: Array[StringName] = [
	&"background_mode", &"ambient_light_source", &"reflected_light_source",
	&"tonemap_mode", &"glow_blend_mode", &"fog_mode",
]

# On/off flags -> the "amount" property that is faded so toggling looks smooth.
const TOGGLES := {
	&"fog_enabled": &"fog_density",
	&"volumetric_fog_enabled": &"volumetric_fog_density",
	&"glow_enabled": &"glow_intensity",
}

# ProceduralSkyMaterial properties that get blended.
const SKY_PROPS: Array[StringName] = [
	&"sky_top_color", &"sky_horizon_color", &"sky_curve", &"sky_energy_multiplier",
	&"ground_bottom_color", &"ground_horizon_color", &"ground_curve",
	&"ground_energy_multiplier", &"sun_angle_max", &"sun_curve",
]

var _env: Environment            # runtime copy, so your saved .tres is never modified
var _target: Environment
var _tween: Tween
var _from := {}
var _to := {}
var _disable_at_end: Array[StringName] = []
var _sky_mat: ProceduralSkyMaterial
var _sky_from := {}
var _sky_to := {}
var _swap_sky: Sky
var _snapped := false


func _ensure_init() -> void:
	if _env != null:
		return
	if world_environment == null:
		push_error("EnvironmentTweener: assign a WorldEnvironment.")
		return
	var src := world_environment.environment
	_env = src.duplicate(true) if src else Environment.new()
	world_environment.environment = _env


## Blend to `target`. duration < 0 uses default_duration, 0 applies instantly.
func tween_to(target: Environment, duration := -1.0) -> Tween:
	_ensure_init()
	if _env == null or target == null:
		return null
	if _tween:
		_tween.kill()
	if duration < 0.0:
		duration = default_duration

	_target = target
	_snapped = false
	_from.clear()
	_to.clear()
	_disable_at_end.clear()

	for p in LERP_PROPS:
		var a = _env.get(p)
		var b = target.get(p)
		if a == null or b == null:
			continue
		_from[p] = a
		_to[p] = b

	# Fade features in/out instead of popping them on/off
	for flag in TOGGLES:
		var was = _env.get(flag)
		var will = target.get(flag)
		if was == null or will == null:
			continue
		var amount: StringName = TOGGLES[flag]
		if not was and will:
			_env.set(flag, true)
			_from[amount] = 0.0
		elif was and not will:
			_to[amount] = 0.0
			_disable_at_end.append(flag)

	_prepare_sky(target)

	if duration <= 0.0:
		_apply(1.0)
		_finish()
		return null

	_tween = create_tween().set_trans(default_trans).set_ease(default_ease)
	_tween.tween_method(_apply, 0.0, 1.0, duration)
	_tween.tween_callback(_finish)
	return _tween


func set_instant(target: Environment) -> void:
	tween_to(target, 0.0)


func _prepare_sky(target: Environment) -> void:
	_sky_mat = null
	_swap_sky = null
	_sky_from.clear()
	_sky_to.clear()

	var cur = _env.sky.sky_material if _env.sky else null
	var tgt = target.sky.sky_material if target.sky else null

	if cur is ProceduralSkyMaterial and tgt is ProceduralSkyMaterial:
		_sky_mat = cur
		for p in SKY_PROPS:
			_sky_from[p] = cur.get(p)
			_sky_to[p] = tgt.get(p)
	elif target.sky:
		# Panorama / Physical / different types can't be blended -> swap at snap_point
		_swap_sky = target.sky.duplicate(true)


func _apply(t: float) -> void:
	for p in _from:
		_env.set(p, lerp(_from[p], _to[p], t))

	if _sky_mat:
		for p in _sky_from:
			_sky_mat.set(p, lerp(_sky_from[p], _sky_to[p], t))

	if not _snapped and t >= snap_point:
		_snapped = true
		for p in SNAP_PROPS:
			var v = _target.get(p)
			if v != null:
				_env.set(p, v)
		if _swap_sky:
			_env.sky = _swap_sky


func _finish() -> void:
	_apply(1.0)
	for flag in _disable_at_end:
		_env.set(flag, false)
	finished.emit()
