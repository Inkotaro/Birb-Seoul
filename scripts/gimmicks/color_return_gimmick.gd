class_name ColorReturnGimmick
extends Node
## Starts the world as high-contrast sepia and brings normal color back when the
## dialogue fires `color_return` with small / half / full (or a number 0-1).

@export var world_environment: WorldEnvironment
## Optional. If empty, the runner is found through DialogueRunner.find().
@export var runner: DialogueRunner
@export var event_key: String = "color_return"

@export_group("Sepia Look")
@export var shadow_tint: Color = Color(0.08, 0.05, 0.03)
@export var mid_tint: Color = Color(0.55, 0.40, 0.27)
@export var highlight_tint: Color = Color(1.0, 0.90, 0.72)

@export_group("Start")
@export_range(0.0, 1.0) var start_sepia: float = 1.0
@export var start_saturation: float = 0.0
@export var start_contrast: float = 3.0

@export_group("Presets")
@export_range(0.0, 1.0) var small_sepia: float = 0.65
@export var small_saturation: float = 0.3
@export var small_contrast: float = 2.4
@export var small_time: float = 2.0
@export_range(0.0, 1.0) var half_sepia: float = 0.3
@export var half_saturation: float = 0.5
@export var half_contrast: float = 1.6
@export var half_time: float = 4.0
@export_range(0.0, 1.0) var full_sepia: float = 0.0
@export var full_saturation: float = 1.0
@export var full_contrast: float = 1.0
@export var full_time: float = 3.0

var _env: Environment
var _gradient: Gradient
var _sepia: float = 1.0
var _tween: Tween


func _ready() -> void:
	if world_environment == null or world_environment.environment == null:
		push_error("ColorReturnGimmick: assign a WorldEnvironment with an Environment")
		return
	# Duplicate so we never write into the shared resource file.
	_env = world_environment.environment.duplicate()
	world_environment.environment = _env

	# 1D color-correction ramp: black -> mid -> white, tinted by the sepia amount.
	_gradient = Gradient.new()
	_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_gradient.colors = PackedColorArray([Color.BLACK, Color.GRAY, Color.WHITE])
	var tex := GradientTexture1D.new()
	tex.gradient = _gradient
	tex.width = 256

	_env.adjustment_enabled = true
	_env.adjustment_color_correction = tex
	_env.adjustment_saturation = start_saturation
	_env.adjustment_contrast = start_contrast
	_set_sepia(start_sepia)

	# Wait a frame so the runner has joined its group, whatever the tree order.
	await get_tree().process_frame
	if runner == null:
		runner = DialogueRunner.find(self)
	if runner == null:
		push_error("ColorReturnGimmick: no DialogueRunner found")
		return
	runner.event_fired.connect(_on_event)


func _set_sepia(amount: float) -> void:
	_sepia = amount
	_gradient.set_color(0, Color.BLACK.lerp(shadow_tint, amount))
	_gradient.set_color(1, Color.GRAY.lerp(mid_tint, amount))
	_gradient.set_color(2, Color.WHITE.lerp(highlight_tint, amount))


func _on_event(key: String, value: String) -> void:
	if key != event_key:
		return
	var sepia := full_sepia
	var sat := full_saturation
	var con := full_contrast
	var time := 3.0
	match value.strip_edges().to_lower():
		"small":
			sepia = small_sepia
			sat = small_saturation
			con = small_contrast
			time = small_time
		"half":
			sepia = half_sepia
			sat = half_saturation
			con = half_contrast
			time = half_time
		"full":
			sepia = full_sepia
			sat = full_saturation
			con = full_contrast
			time = full_time
		_:
			if value.is_valid_float():
				# 0-1 blends between the start look and the full look.
				var t := clampf(value.to_float(), 0.0, 1.0)
				sepia = lerpf(start_sepia, full_sepia, t)
				sat = lerpf(start_saturation, full_saturation, t)
				con = lerpf(start_contrast, full_contrast, t)
			else:
				push_warning("ColorReturnGimmick: unknown value '%s'" % value)
				return
	set_look(sepia, sat, con, time)


func set_look(sepia: float, saturation: float, contrast: float, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	# Never go backwards: sepia only fades, color only grows, contrast only relaxes.
	sepia = minf(sepia, _sepia)
	saturation = maxf(saturation, _env.adjustment_saturation)
	contrast = minf(contrast, _env.adjustment_contrast)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_set_sepia, _sepia, sepia, time)
	_tween.tween_property(_env, "adjustment_saturation", saturation, time)
	_tween.tween_property(_env, "adjustment_contrast", contrast, time)
