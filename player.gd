extends CharacterBody3D
class_name Player

@onready var mesh : Node3D = $Mesh
@onready var animation_player : AnimationPlayer = $Mesh/AnimationPlayer
@onready var animation_tree : AnimationTree = $AnimationTree
@onready var playback : AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var FootstepSFX: SFXPlayer = $FootstepSFX
@onready var FlySFX: SFXPlayer = $FlySFX
## Optional: add an SFXPlayer called "CallSFX" and the bird will chirp on calls.
@onready var CallSFX: SFXPlayer = get_node_or_null("CallSFX")

# --- Ground ---
const WALK_SPEED = 1.0
const WALK_ACCEL = 10.0
const ROTATION_SPEED = 5.0

const TAKEOFF_VELOCITY = 2.5      # first hop off the ground
const FLAP_VELOCITY = 1.2         # added by each mid-air flap
const MAX_RISE_SPEED = 2.2        # flapping can't push you up faster than this
const FLAP_INTERVAL = 0.28        # seconds between flaps while holding jump
const MAX_STAMINA = 8.0           # number of flaps before you can only glide
const STAMINA_REGEN = 3.0         # per second, only on the ground
const AIR_SPEED = 3.5
const AIR_ACCEL = 4.0             # lower = more inertia, wider turns
const AIR_DRAG = 1.0              # how slowly you lose speed with no input
const GRAVITY_SCALE = 0.25        # same as the old get_gravity()/4
const MAX_FALL_SPEED = 3.0
const GLIDE_FALL_SPEED = 0.5      # sink rate when wings are out
const GLIDE_BRAKE = 6.0           # how quickly a fall turns into a glide

# --- Landing flare (wings flare, nose up, just before touchdown) ---
const FLARE_HEIGHT = 0.35
const FLARE_FALL_SPEED = 0.3
const FLARE_BRAKE = 8.0
const FLARE_PITCH = deg_to_rad(-35.0)

# --- Body language ---
const GROUND_LEAN_ANGLE = deg_to_rad(15.0)
const AIR_LEAN_ANGLE = deg_to_rad(45.0)
const AIR_TURN_SPEED = 3.5
const LEAN_SMOOTHING = 6.0
const MAX_PITCH = deg_to_rad(30.0)
const FLAP_KICK = deg_to_rad(-20.0)
const FLAP_KICK_DECAY = 7.0
const GLIDE_WOBBLE = deg_to_rad(3.0)
# Flip to -1.0 if the bird pitches the wrong way.
const PITCH_SIGN = 1.0

# --- Idle behaviours ---
const IDLE_ACTION_MIN = 3.0
const IDLE_ACTION_MAX = 7.0
const ACTIONS = {
	"peck": "Peck",
	"preen": "Preen",
	"scratch_ground": "Scratch",
	"call": "Call",
}
const ACTION_POOL = ["peck", "peck", "preen", "scratch_ground", "call"]

const animations = {
	"call": ["A_Call_01", "A_Call_02", "A_Call_03"],
	"flutter": ["A_Flutter"],
	"fly": ["A_Fly"],
	"hop": ["A_Hop_01", "A_Hop_02", "A_Hop_03"],
	"idle": ["A_Idle_01", "A_Idle_02", "A_Idle_03"],
	"peck": ["A_PeckGround_01", "A_PeckGround_02", "A_PeckGround_03"],
	"preen": ["A_Preen_01", "A_Preen_02", "A_Preen_03"],
	"scratch_ground": ["A_ScratchGround_01", "A_ScratchGround_02", "A_ScratchGround_03"]
}

var input_direction : Vector3 = Vector3.ZERO
var direction : Vector3 = Vector3.ZERO
var input_locked = false

var footstep_cooldown: float = 0.0
var stamina: float = MAX_STAMINA
var flap_cooldown: float = 0.0
var flap_kick: float = 0.0
var gliding: bool = false
var flaring: bool = false
var was_on_floor: bool = true
var wobble_time: float = 0.0

var current_state: String = ""
var state_cache: Dictionary = {}
var warned_states: Dictionary = {}

var action_name: String = ""
var last_action: String = ""
var action_timer: float = 0.0
var idle_time: float = 0.0
var next_action_at: float = 4.0

var base_mesh_scale: Vector3
var squash_tween: Tween


func _ready() -> void:
	base_mesh_scale = mesh.scale
	stamina = MAX_STAMINA
	_schedule_next_action()


func _physics_process(delta: float) -> void:
	_player_movement(delta)
	_player_lean(delta)
	_player_actions(delta)
	_player_animation()
	_player_sounds(delta)


func is_flying() -> bool:
	return not is_on_floor()


# ---------------------------------------------------------------- movement

func _player_movement(delta: float) -> void:
	var on_floor := is_on_floor()

	var input_vector := Vector2.ZERO
	if not input_locked:
		input_vector = Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
	input_direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var has_input := input_direction.length_squared() > 0.0
	if has_input:
		direction = input_direction

	var jump_pressed := not input_locked and Input.is_action_just_pressed("jump")
	var jump_held := not input_locked and Input.is_action_pressed("jump")

	flap_cooldown = maxf(flap_cooldown - delta, 0.0)
	if on_floor:
		stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
	_check_flare()

	# Take off from the ground, or keep flapping in the air.
	if on_floor and jump_pressed:
		velocity.y = TAKEOFF_VELOCITY
		_flap_effects()
	elif not on_floor and (jump_pressed or jump_held) and flap_cooldown <= 0.0 and stamina >= 1.0:
		stamina -= 1.0
		velocity.y = minf(maxf(velocity.y, 0.0) + FLAP_VELOCITY, MAX_RISE_SPEED)
		_flap_effects()

	# Gliding: wings out while falling and either steering or holding jump.
	gliding = not on_floor and velocity.y <= 0.0 and (jump_held or has_input)

	# Vertical motion
	if not on_floor:
		if flaring:
			velocity.y = move_toward(velocity.y, -FLARE_FALL_SPEED, FLARE_BRAKE * delta)
		elif gliding:
			velocity.y = move_toward(velocity.y, -GLIDE_FALL_SPEED, GLIDE_BRAKE * delta)
		else:
			velocity.y = maxf(velocity.y + get_gravity().y * GRAVITY_SCALE * delta, -MAX_FALL_SPEED)

	# Horizontal motion with inertia in the air
	var max_speed := WALK_SPEED if on_floor else AIR_SPEED
	var target := Vector2(input_direction.x, input_direction.z) * max_speed if has_input else Vector2.ZERO
	var accel := WALK_ACCEL
	if not on_floor:
		accel = AIR_ACCEL if has_input else AIR_DRAG
	if flaring:
		target *= 0.5
		accel = AIR_ACCEL
	var h := Vector2(velocity.x, velocity.z).move_toward(target, accel * delta)
	velocity.x = h.x
	velocity.z = h.y

	var pre_land_speed := -velocity.y
	move_and_slide()
	if is_on_floor() and not was_on_floor:
		_on_land(pre_land_speed)
	was_on_floor = is_on_floor()


func _flap_effects() -> void:
	flap_cooldown = FLAP_INTERVAL
	flap_kick = FLAP_KICK
	FlySFX.play_sfx()


func _check_flare() -> void:
	flaring = false
	if is_on_floor() or velocity.y >= 0.0:
		return
	var query := PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.DOWN * FLARE_HEIGHT,
		collision_mask,
		[get_rid()]
	)
	flaring = not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _on_land(impact_speed: float) -> void:
	gliding = false
	flaring = false
	if impact_speed > 0.4:
		FootstepSFX.play_sfx()
	if impact_speed > 0.8:
		if squash_tween != null and squash_tween.is_valid():
			squash_tween.kill()
		mesh.scale = base_mesh_scale * Vector3(1.12, 0.85, 1.12)
		squash_tween = create_tween()
		squash_tween.tween_property(mesh, "scale", base_mesh_scale, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# -------------------------------------------------------------------- lean

func _player_lean(delta: float) -> void:
	wobble_time += delta
	var airborne := not is_on_floor()
	var smooth := 1.0 - exp(-LEAN_SMOOTHING * delta)

	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	var h_speed := h_vel.length()

	# In the air the bird faces where it is actually travelling.
	var face := Vector3.ZERO
	if airborne and h_speed > 0.4:
		face = h_vel / h_speed
	elif input_direction.length_squared() > 0.0:
		face = input_direction

	var target_roll := 0.0
	if face != Vector3.ZERO:
		var target_rotation := atan2(face.x, face.z)
		var angle_diff := wrapf(target_rotation - mesh.rotation.y, -PI, PI)
		var turn := AIR_TURN_SPEED if airborne else ROTATION_SPEED
		mesh.rotation.y = lerp_angle(mesh.rotation.y, target_rotation, clampf(turn * delta, 0.0, 1.0))
		var max_lean := AIR_LEAN_ANGLE if airborne else GROUND_LEAN_ANGLE
		target_roll = -clampf(angle_diff * 1.5, -1.0, 1.0) * max_lean

	var target_pitch := 0.0
	if airborne:
		# Align the body with the flight path: climb = nose up, dive = nose down.
		var path_angle := atan2(velocity.y, maxf(h_speed, 1.0))
		target_pitch = -clampf(path_angle, -MAX_PITCH, MAX_PITCH)
		if flaring:
			target_pitch = FLARE_PITCH
		if gliding:
			target_roll += sin(wobble_time * 2.5) * GLIDE_WOBBLE

	flap_kick = lerpf(flap_kick, 0.0, 1.0 - exp(-FLAP_KICK_DECAY * delta))
	target_pitch += flap_kick

	mesh.rotation.z = lerp_angle(mesh.rotation.z, target_roll, smooth)
	mesh.rotation.x = lerp_angle(mesh.rotation.x, target_pitch * PITCH_SIGN, smooth)


# ------------------------------------------------------------ idle actions

func _player_actions(delta: float) -> void:
	var moving := not is_on_floor() \
		or input_direction.length_squared() > 0.0 \
		or Vector2(velocity.x, velocity.z).length() > 0.3
	var call_pressed := not input_locked \
		and InputMap.has_action("call") \
		and Input.is_action_just_pressed("call")

	if moving:
		action_name = ""
		idle_time = 0.0
		if call_pressed:
			_call_sound()
		return

	if call_pressed:
		_start_action("call")
		return

	if action_name != "":
		action_timer -= delta
		if action_timer <= 0.0:
			action_name = ""
			idle_time = 0.0
			_schedule_next_action()
		return

	idle_time += delta
	if idle_time >= next_action_at:
		_start_action(_pick_action())


func _pick_action() -> String:
	var pick: String = ACTION_POOL[randi() % ACTION_POOL.size()]
	var tries := 0
	while pick == last_action and tries < 6:
		pick = ACTION_POOL[randi() % ACTION_POOL.size()]
		tries += 1
	return pick


func _start_action(key: String) -> void:
	var state: String = ACTIONS[key]
	if not _has_state(state):
		_warn_missing(state)
		action_name = ""
		idle_time = 0.0
		_schedule_next_action()
		return

	var clip := _get_animation(key)
	action_name = key
	last_action = key
	action_timer = 2.0
	if animation_player.has_animation(clip):
		action_timer = animation_player.get_animation(clip).length
	if key == "call":
		_call_sound()

	# Force the state change even if the same action plays twice in a row.
	current_state = ""
	_set_state(state, key, clip)


func _schedule_next_action() -> void:
	next_action_at = randf_range(IDLE_ACTION_MIN, IDLE_ACTION_MAX)


func _call_sound() -> void:
	if CallSFX != null:
		CallSFX.play_sfx()


# -------------------------------------------------------------- animation

func _get_animation(anim_name: String) -> String:
	if animations.has(anim_name):
		return animations[anim_name][randi() % animations[anim_name].size()]
	return ""


func _has_state(state: String) -> bool:
	if not state_cache.has(state):
		var root := animation_tree.tree_root as AnimationNodeStateMachine
		state_cache[state] = root != null and root.has_node(state)
	return state_cache[state]


func _warn_missing(state: String) -> void:
	if not warned_states.has(state):
		warned_states[state] = true
		push_warning("Player: AnimationTree has no '%s' state, skipping it." % state)


func _set_state(state: String, anim_key: String, clip: String = "") -> void:
	if state == current_state:
		return
	if not _has_state(state):
		_warn_missing(state)
		if state == "Flutter":
			state = "Fly"
			anim_key = "fly"
		else:
			state = "Idle"
			anim_key = "idle"
		clip = ""
		if state == current_state or not _has_state(state):
			return
	if clip == "":
		clip = _get_animation(anim_key)
	current_state = state
	animation_tree.set("parameters/%s/animation" % state, clip)
	playback.travel(state)


func _player_animation() -> void:
	if action_name != "":
		return
	if not is_on_floor():
		if flaring:
			_set_state("Flutter", "flutter")
		else:
			_set_state("Fly", "fly")
	elif input_direction.length_squared() > 0.0:
		_set_state("Hop", "hop")
	else:
		_set_state("Idle", "idle")

func _player_sounds(delta: float) -> void:
	footstep_cooldown += delta * 3.0
	if velocity.length() > 0.5 and is_on_floor() and footstep_cooldown >= 1.0:
		FootstepSFX.play_sfx()
		footstep_cooldown = 0.0
