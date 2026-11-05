class_name ColorReturnGimmick
extends Node
## Starts the world in bright monochrome and brings vibrant color back when the
## dialogue fires `color_return` with small / half / full (or a number 0-1).

@export var world_environment: WorldEnvironment
## Optional. If empty, the runner is found through DialogueRunner.find().
@export var runner: DialogueRunner
@export var event_key: String = "color_return"

@export_group("Start (monochrome)")
@export var start_saturation: float = 0.0
@export var start_contrast: float = 1.05
@export var start_brightness: float = 1.0

@export_group("Presets")
@export var small_saturation: float = 0.4
@export var small_contrast: float = 1.05
@export var small_brightness: float = 1.0
@export var small_time: float = 2.0
@export var half_saturation: float = 0.8
@export var half_contrast: float = 1.08
@export var half_brightness: float = 1.02
@export var half_time: float = 4.0
## Above 1.0 = more saturated than the original scene (the "vibrant" payoff).
@export var full_saturation: float = 1.35
@export var full_contrast: float = 1.1
@export var full_brightness: float = 1.05
@export var full_time: float = 3.0

var _env: Environment
var _tween: Tween


func _ready() -> void:
	if world_environment == null or world_environment.environment == null:
		push_error("ColorReturnGimmick: assign a WorldEnvironment with an Environment")
		return
	# Duplicate so we never write into the shared resource file.
	_env = world_environment.environment.duplicate()
	world_environment.environment = _env

	_env.adjustment_enabled = true
	_env.adjustment_color_correction = null
	_env.adjustment_saturation = start_saturation
	_env.adjustment_contrast = start_contrast
	_env.adjustment_brightness = start_brightness

	# Wait a frame so the runner has joined its group, whatever the tree order.
	await get_tree().process_frame
	if runner == null:
		runner = DialogueRunner.find(self)
	if runner == null:
		push_error("ColorReturnGimmick: no DialogueRunner found")
		return
	runner.event_fired.connect(_on_event)


func _on_event(key: String, value: String) -> void:
	if key != event_key:
		return
	var sat := full_saturation
	var con := full_contrast
	var bri := full_brightness
	var time := full_time
	match value.strip_edges().to_lower():
		"small":
			sat = small_saturation
			con = small_contrast
			bri = small_brightness
			time = small_time
		"half":
			sat = half_saturation
			con = half_contrast
			bri = half_brightness
			time = half_time
		"full":
			pass
		_:
			if value.is_valid_float():
				# 0-1 blends between the monochrome start and the vibrant full look.
				var t := clampf(value.to_float(), 0.0, 1.0)
				sat = lerpf(start_saturation, full_saturation, t)
				con = lerpf(start_contrast, full_contrast, t)
				bri = lerpf(start_brightness, full_brightness, t)
			else:
				push_warning("ColorReturnGimmick: unknown value '%s'" % value)
				return
	set_look(sat, con, bri, time)


func set_look(saturation: float, contrast: float, brightness: float, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Never go backwards: color only grows.
	saturation = maxf(saturation, _env.adjustment_saturation)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_env, "adjustment_saturation", saturation, time)
	_tween.tween_property(_env, "adjustment_contrast", contrast, time)
	_tween.tween_property(_env, "adjustment_brightness", brightness, time)
