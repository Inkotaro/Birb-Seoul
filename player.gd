extends CharacterBody3D

@onready var mesh : Node3D = $Mesh 
@onready var animation_player : AnimationPlayer = $Mesh/AnimationPlayer
@onready var animation_tree : AnimationTree = $AnimationTree
@onready var playback = animation_tree.get("parameters/playback")

const SPEED = 2.0
const JUMP_VELOCITY = 4.5
const LEAN_SPEED = 8.0
const MAX_LEAN_ANGLE = deg_to_rad(25.0)
const ROTATION_SPEED = 5
const MAX_DOUBLE_JUMP = 2
var current_double_jump = 0
var input_direction : Vector3 = Vector3.ZERO
var direction : Vector3 = Vector3.ZERO

const animations = {
	"call": ["A_Call_01", "A_Call_02", "A_Call_03"],
	"flutter": ["A_Flutter"],
	"fly": ["A_Fly"],
	"hop": ["A_Hop_01", "A_Hop_02","A_Hop_03"],
	"idle": ["A_Idle_01", "A_Idle_02", "A_Idle_03"],
	"peck": ["A_PeckGround_01","A_PeckGround_02", "A_PeckGround_03"],
	"preen": ["A_Preen_01", "A_Preen_02", "A_Preen_03"],
	"scratch_ground": ["A_ScratchGround_01", "A_ScratchGround_02", "A_ScratchGround_03"]
}

func _physics_process(delta: float) -> void:
	_player_movement(delta)
	_player_animation(delta)
	
func _player_movement(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity()/2 * delta
	else:
		current_double_jump = 0

	if Input.is_action_just_pressed("ui_accept") and current_double_jump <= MAX_DOUBLE_JUMP:
		velocity.y = JUMP_VELOCITY
		current_double_jump += 1
		
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	input_direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if input_direction:
		velocity.x = input_direction.x * SPEED
		velocity.z = input_direction.z * SPEED
		direction = input_direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	# lean movement
	var target_lean = 0.0
	if input_direction.length_squared() > 0:
		var target_rotation = atan2(input_direction.x, input_direction.z)
		var angle_diff = wrapf(target_rotation - mesh.rotation.y, -PI, PI)
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rotation, ROTATION_SPEED * delta)
		target_lean = -clamp(angle_diff * 2.0, -1.0, 1.0) * MAX_LEAN_ANGLE
	mesh.rotation.z = lerp_angle(mesh.rotation.z, target_lean, LEAN_SPEED * delta)
	move_and_slide()

func _get_animation(anim_name: String) -> String:
	if animations.has(anim_name):
		return animations[anim_name][randi() % animations[anim_name].size()]
	return ""

func _player_animation(delta: float) -> void:
	if not is_on_floor():
		var anim_to_play = _get_animation("fly")
		animation_tree.set("parameters/Fly/animation", anim_to_play)
		playback.travel("Fly")
	elif input_direction.length_squared() > 0:
		var anim_to_play = _get_animation("hop")
		animation_tree.set("parameters/Hop/animation", anim_to_play)
		playback.travel("Hop")
	else:
		var anim_to_play = _get_animation("idle")
		animation_tree.set("parameters/Idle/animation", anim_to_play)
		playback.travel("Idle")
