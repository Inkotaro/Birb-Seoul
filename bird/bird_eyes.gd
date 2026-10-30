extends Sprite3D

@export var no_depth := false:
	set(value):
		no_depth = value
		_apply_depth()

@export_group("Blink")
@export var min_interval := 2.0
@export var max_interval := 6.0
@export_range(0.0, 1.0) var squish_amount := 0.1   # 0.1 = squish to 10% height
@export var close_time := 0.06
@export var open_time := 0.1
@export_range(0.0, 1.0) var double_blink_chance := 0.2

var _base_scale: Vector3


func _ready() -> void:
	_base_scale = scale
	_apply_depth()
	_blink_loop()


func _apply_depth() -> void:
	var mat := material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("no_depth", no_depth)


func _blink_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(min_interval, max_interval)).timeout
		if not is_inside_tree():
			return
		await _blink()
		if randf() < double_blink_chance:
			await _blink()


func _blink() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale:y", _base_scale.y * squish_amount, close_time)
	tw.tween_property(self, "scale:y", _base_scale.y, open_time)
	await tw.finished
