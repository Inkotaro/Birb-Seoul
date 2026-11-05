# RoadManager.gd (Node3D)
extends Node3D
class_name RoadManager

signal road_changed(new_scene: PackedScene)

enum ThemeTrigger { ON_BREAK, ON_CROSS_BOUNDARY, ON_COMMIT }

@export var player: Node3D
@export var pcam: PhantomCamera3D
@export var segment_scene: PackedScene
@export var road_mesh_name := ""

@export_group("Road switch")
## Grows each auto-generated visibility notifier by this much (world units).
@export var view_margin := 2.0
## Commit the swap anyway once the player is this far past the border.
## Always capped at half the new road's length so the player can never run off its end.
## 0 = use only that cap.
@export var force_commit_distance := 50.0
## Rendered frames to wait after creating the notifiers before trusting is_on_screen().
@export var notifier_warmup_frames := 3

@export_group("Camera damping blend")
## Camera is fully loose (default damping) at this distance from a border or further.
@export var fade_distance := 20.0
## Camera is fully stiff (no lag) at this distance from a border or closer.
@export var static_distance := 6.0
@export var min_damping := 0.0001
## How fast the camera becomes stiff when approaching a border (blend units per second).
@export var damping_in_speed := 6.0
## How fast the camera loosens again after the border (blend units per second).
@export var damping_out_speed := 1.5

@export_group("Theme (environment + music)")
@export var environment_tweener: EnvironmentTweener
@export var music_crossfader: MusicCrossfader
## ON_BREAK: start blending as soon as the new road is spawned.
## ON_CROSS_BOUNDARY: when the player reaches the new road.
## ON_COMMIT: when the old road is gone and the swap is finalized.
@export var theme_trigger := ThemeTrigger.ON_CROSS_BOUNDARY
@export_subgroup("Music distance fade")
## Music starts fading this far BEFORE the road border (world units).
@export var music_fade_before := 25.0
## New music reaches full volume this far AFTER the border.
@export var music_fade_after := 15.0
## true: old song hits silence at the border, THEN the new song fades in (no overlap).
## false: both songs overlap across the whole range.
@export var music_sequential := true

@export_group("Debug")
## Prints what the road switch is doing / waiting for in the Output panel.
@export var debug_log := true

# order: 0 = left (view only), 1 = center (main), 2 = right (view only)
var segments: Array[Node3D] = []
var segment_length := 0.0
var origin_offset := 0.0

var _default_damping_enabled := false
var _default_damping_value := Vector3.ZERO
var _damping_blend := 1.0

# road switch state
var _breaking := false
var _break_id := 0
var _pending_scene: PackedScene
var _pending_length := 0.0
var _pending_offset := 0.0
var _log_timer := 0.0
var _crossed := false   # player has entered the new road during this switch

# pre-built neighbours of the incoming road (so commit doesn't instantiate anything)
var _prep_right: Node3D   # already in the tree, parked behind the new road
var _prep_left: Node3D    # instantiated but NOT in the tree until commit

# visibility check with real nodes
var _view_notifiers: Array[VisibleOnScreenNotifier3D] = []
var _auto_notifiers: Array[VisibleOnScreenNotifier3D] = []   # the ones we created (we free these)
var _notifiers_built_frame := 0

# theme state
var _pending_theme: RoadTheme
var _theme_applied := true
var _music_blending := false
var _music_border_x := 0.0


func _ready() -> void:
	for i in 3:
		var seg := segment_scene.instantiate() as Node3D
		add_child(seg)
		segments.append(seg)

	var box := _get_segment_aabb(segments[1])
	segment_length = box.size.x
	origin_offset = box.position.x

	for i in 3:
		var p := segments[i].global_position
		p.x = (i - 1) * segment_length - origin_offset
		segments[i].global_position = p

	_default_damping_enabled = pcam.follow_damping
	_default_damping_value = pcam.follow_damping_value

	# Starting road's theme, applied instantly
	_apply_theme(_find_theme(segments[1]), true)


func _physics_process(delta: float) -> void:
	_log_waiting(delta)
	_update_camera_damping(delta)   # first, so it's already stiff when the wrap happens
	_track_crossing()
	_check_theme_trigger()
	_update_music_blend()
	_check_commit()
	_wrap_player()


func break_loop(new_scene: PackedScene) -> void:
	if new_scene == null:
		return
	if _breaking:
		# Already crossing, or same target: ignore.
		# Otherwise the player hasn't reached the new road yet, so swap the pending road.
		if _crossed:
			_log("ignored: you're already entering the new road, wait for the swap to finish.")
			return
		if new_scene == _pending_scene:
			_log("ignored: already switching to that road. WALK RIGHT past x=%.1f to enter it." % segment_length)
			return
		_log("cancelled the pending road, switching to another one.")
		_cancel_break()
	if new_scene == segment_scene:
		_log("ignored: already on this road.")
		return
	_breaking = true
	_break_id += 1
	_crossed = false
	_pending_scene = new_scene

	var old_right := segments[2]
	var new_road := new_scene.instantiate() as Node3D
	add_child(new_road)

	var box := _get_segment_aabb(new_road)
	if box.size.x <= 0.01:
		push_error("RoadManager: couldn't measure the length of '%s'. It needs a MeshInstance3D (and road_mesh_name must match one, or be empty)." % new_scene.resource_path)
		new_road.queue_free()
		_breaking = false
		_pending_scene = null
		return
	_pending_length = box.size.x
	_pending_offset = box.position.x
	_log("switching to %s (length %.1f). Walk right past x=%.1f (player x=%.1f) to enter it." \
		% [new_scene.resource_path, _pending_length, segment_length, player.global_position.x])

	new_road.global_position = Vector3(
		segment_length - _pending_offset,
		old_right.global_position.y,
		old_right.global_position.z)

	segments[2] = new_road
	old_right.queue_free()

	# Visibility notifiers on the OLD road (segments 0 and 1)
	_build_view_notifiers()

	# Theme of the incoming road
	_pending_theme = _find_theme(new_road)
	_theme_applied = false
	_begin_music_blend(_pending_theme)
	if theme_trigger == ThemeTrigger.ON_BREAK:
		_apply_pending_theme()

	# Instantiate the new road's neighbours now, one per frame, so commit is cheap
	_prepare_neighbors(new_scene, _break_id)


func _log(msg: String) -> void:
	if debug_log:
		print("[RoadManager] ", msg)


func _log_waiting(delta: float) -> void:
	if not debug_log or not _breaking:
		return
	_log_timer += delta
	if _log_timer < 1.0:
		return
	_log_timer = 0.0
	var msg := "waiting: player x=%.1f, border x=%.1f, entered new road=%s" \
		% [player.global_position.x, segment_length, _crossed]
	if _crossed:
		msg += ", old road still on screen=%s" % _old_road_visible()
	_log(msg)


## Debug helper: finish a pending switch immediately (the world pops, no transition).
func force_commit() -> void:
	if not _breaking:
		return
	if _music_blending and music_crossfader:
		music_crossfader.finish_blend()
		_music_blending = false
	_commit_new_road()
	_wrap_player()


func is_breaking() -> bool:
	return _breaking


func _track_crossing() -> void:
	if _breaking and player.global_position.x >= segment_length:
		_crossed = true


## Player hasn't entered the new road yet: drop it and restore the normal right segment.
func _cancel_break() -> void:
	_break_id += 1   # stops any pending _prepare_neighbors coroutine

	var pending_road := segments[2]
	pending_road.visible = false
	pending_road.queue_free()
	segments[2] = _spawn_segment(segment_scene, 1, segments[1])

	_discard_prepared()
	_clear_view_notifiers()

	if _theme_applied:   # environment was already switched (ON_BREAK), switch it back
		_apply_theme(_find_theme(segments[1]), false, false)
	if _music_blending:
		_music_blending = false
		if music_crossfader:
			music_crossfader.cancel_blend()

	_breaking = false
	_crossed = false
	_pending_scene = null
	_pending_theme = null
	_theme_applied = true


func _check_commit() -> void:
	if not _breaking:
		return

	var x := player.global_position.x
	if x < segment_length:
		return

	# Failsafe: commit anyway before the player can run off the end of the new road
	var limit := _pending_length * 0.5
	if force_commit_distance > 0.0:
		limit = minf(limit, force_commit_distance)
	var forced := x >= segment_length + limit
	if not forced and _old_road_visible():
		return
	_commit_new_road()


# ---------- On-screen check (real VisibleOnScreenNotifier3D nodes) ----------
#
# Best setup: put your own VisibleOnScreenNotifier3D node(s) in the road scene and size their
# AABB to the part of the road that must be off screen before the swap. If a road scene has
# none, one is generated per mesh (skipping meshes in group "ignore_loop_visibility").

func _build_view_notifiers() -> void:
	_clear_view_notifiers()

	# 1) Notifiers you placed in the editor (old left + old center segments)
	for i in 2:
		for n in segments[i].find_children("*", "VisibleOnScreenNotifier3D", true, false):
			_view_notifiers.append(n as VisibleOnScreenNotifier3D)

	# 2) None placed: generate one per mesh
	if _view_notifiers.is_empty():
		for i in 2:
			for node in segments[i].find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.mesh == null or not mi.is_visible_in_tree():
					continue
				if mi.is_in_group("ignore_loop_visibility"):
					continue
				var vn := VisibleOnScreenNotifier3D.new()
				vn.aabb = mi.get_aabb().grow(view_margin)
				mi.add_child(vn)   # child of the mesh: follows it, freed with it
				_auto_notifiers.append(vn)
				_view_notifiers.append(vn)

	_notifiers_built_frame = Engine.get_frames_drawn()


func _clear_view_notifiers() -> void:
	for vn in _auto_notifiers:
		if is_instance_valid(vn):
			vn.queue_free()
	_auto_notifiers.clear()
	_view_notifiers.clear()


func _old_road_visible() -> bool:
	# A fresh notifier needs a few rendered frames before is_on_screen() is reliable.
	if Engine.get_frames_drawn() - _notifiers_built_frame < notifier_warmup_frames:
		return true
	for vn in _view_notifiers:
		if is_instance_valid(vn) and vn.is_on_screen():
			return true
	return false


# ---------- Pre-building the incoming road's neighbours ----------

func _prepare_neighbors(scene: PackedScene, id: int) -> void:
	await get_tree().process_frame
	if id != _break_id or not _breaking:
		return
	# Right neighbour: safe to add right away, it sits far beyond the new road
	var new_road := segments[2]
	_prep_right = scene.instantiate() as Node3D
	add_child(_prep_right)
	_prep_right.global_position = Vector3(
		new_road.global_position.x + _pending_length,
		new_road.global_position.y,
		new_road.global_position.z)

	await get_tree().process_frame
	if id != _break_id or not _breaking:
		return
	# Left neighbour would overlap the old road, so only instantiate it (not in the tree yet)
	_prep_left = scene.instantiate() as Node3D


func _discard_prepared() -> void:
	if is_instance_valid(_prep_right):
		_prep_right.queue_free()
	if is_instance_valid(_prep_left):
		_prep_left.free()   # never entered the tree
	_prep_right = null
	_prep_left = null


func _commit_new_road() -> void:
	var shift := -segment_length
	_log("COMMIT: now on %s" % _pending_scene.resource_path)
	_music_border_x += shift   # old border becomes x = 0 after the world shift
	_shift_world(shift)
	# Camera damping is NOT touched here: the camera is already stiff near the border
	# and player + camera are shifted together, so there is nothing to snap.

	var new_road := segments[2]
	_shift_x(new_road, shift)

	# Old segments: hide + disable now, free one per frame (freeing big scenes hitches)
	var old_nodes: Array[Node3D] = [segments[0], segments[1]]
	for n in old_nodes:
		n.visible = false
		n.process_mode = Node.PROCESS_MODE_DISABLED
	_clear_view_notifiers()
	_free_staggered(old_nodes)

	segment_length = _pending_length
	origin_offset = _pending_offset

	var left := _spawn_segment(_pending_scene, -1, new_road, _prep_left)
	var right := _spawn_segment(_pending_scene, 1, new_road, _prep_right)
	_prep_left = null
	_prep_right = null
	segments = [left, new_road, right]

	_apply_pending_theme()   # no-op if it already started earlier
	_pending_theme = null

	_breaking = false
	_crossed = false
	segment_scene = _pending_scene
	road_changed.emit(segment_scene)
	_pending_scene = null


func _free_staggered(nodes: Array[Node3D]) -> void:
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()
		await get_tree().process_frame


## Places a segment in its slot. Pass an already-instantiated node to avoid the instantiate() cost.
func _spawn_segment(scene: PackedScene, slot: int, ref: Node3D, existing: Node3D = null) -> Node3D:
	var seg := existing if is_instance_valid(existing) else scene.instantiate() as Node3D
	if not seg.is_inside_tree():
		add_child(seg)
	seg.global_position = Vector3(
		slot * segment_length - origin_offset,
		ref.global_position.y,
		ref.global_position.z)
	seg.reset_physics_interpolation()
	return seg


# ---------- Theme ----------

func _find_theme(root: Node) -> RoadTheme:
	if root is RoadTheme:
		return root
	for c in root.get_children():
		var found := _find_theme(c)
		if found:
			return found
	return null


func _check_theme_trigger() -> void:
	if not _breaking or _theme_applied:
		return
	if theme_trigger == ThemeTrigger.ON_CROSS_BOUNDARY \
			and player.global_position.x >= segment_length:
		_apply_pending_theme()


func _apply_pending_theme() -> void:
	if _theme_applied:
		return
	_theme_applied = true
	_apply_theme(_pending_theme, false, false)   # environment only, music follows distance


func _begin_music_blend(theme: RoadTheme) -> void:
	if theme == null or theme.music == null or music_crossfader == null:
		return
	_music_border_x = segment_length
	_music_blending = true
	music_crossfader.begin_blend(theme.music, theme.music_pitch, theme.music_sync_position)


func _update_music_blend() -> void:
	if not _music_blending or music_crossfader == null:
		return
	var x := player.global_position.x
	var w := inverse_lerp(
		_music_border_x - music_fade_before,
		_music_border_x + music_fade_after, x)
	# The border sits at this point of the 0..1 range: old music is silent exactly there
	var total := music_fade_before + music_fade_after
	var split := music_fade_before / total if (music_sequential and total > 0.0) else -1.0
	music_crossfader.set_blend(w, split)
	if w >= 1.0:
		_music_blending = false   # crossfader finishes on its own


func _apply_theme(theme: RoadTheme, instant := false, with_music := true) -> void:
	if theme == null:
		push_warning("RoadManager: no RoadTheme node found in this road scene, so nothing will change.")
		return

	if theme.environment == null:
		push_warning("RoadManager: RoadTheme has no Environment assigned.")
	elif environment_tweener == null:
		push_warning("RoadManager: environment_tweener is not assigned in the Inspector.")
	else:
		environment_tweener.tween_to(
			theme.environment, 0.0 if instant else theme.environment_time)

	if not with_music:
		return

	if theme.music == null:
		push_warning("RoadTheme has no music assigned.")
	elif music_crossfader == null:
		push_warning("RoadManager: music_crossfader is not assigned in the Inspector.")
	else:
		music_crossfader.play_track(
			theme.music, 0.0 if instant else theme.music_fade_time,
			theme.music_sync_position, theme.music_pitch)


# ---------- Camera damping / wrapping ----------

## Camera is stiff (no lag) only near a border and loose everywhere else.
## The blend value is smoothed, so it never jumps (this was the stutter at the swap).
func _update_camera_damping(delta: float) -> void:
	if not _default_damping_enabled:
		return

	var x := player.global_position.x
	# Distance to the nearest border. While crossing into the new road x >= segment_length,
	# so this is <= 0 and the camera stays stiff until the swap is done.
	var dist_to_edge := minf(x, segment_length - x)
	var target := 1.0 - smoothstep(static_distance, fade_distance, dist_to_edge)

	var speed := damping_in_speed if target > _damping_blend else damping_out_speed
	_damping_blend = move_toward(_damping_blend, target, speed * delta)

	if _damping_blend >= 1.0:
		pcam.follow_damping = false
	else:
		pcam.follow_damping = true
		var static_value := Vector3.ONE * min_damping
		pcam.follow_damping_value = _default_damping_value.lerp(static_value, _damping_blend)


func _wrap_player() -> void:
	var x := player.global_position.x
	var shift := 0.0
	# floor/ceil so it still lands inside [0, L) even after a huge jump
	if x < 0.0:
		shift = ceilf(-x / segment_length) * segment_length
	elif x >= segment_length and not _breaking:
		shift = -floorf(x / segment_length) * segment_length
	if shift == 0.0:
		return
	_shift_world(shift)


# Shifts the player, camera and every "loop_wrap" node exactly once each.
# A node is skipped if one of its ancestors is also being shifted (it would move twice).
func _shift_world(shift: float) -> void:
	var candidates: Array[Node3D] = []
	var raw: Array = [player, pcam]
	raw.append_array(get_tree().get_nodes_in_group("loop_wrap"))
	var cam := get_viewport().get_camera_3d()
	if cam:
		raw.append(cam)   # the real Camera3D the PhantomCameraHost drives

	for n in raw:
		var n3 := n as Node3D
		if n3 != null and not candidates.has(n3):
			candidates.append(n3)

	for n3 in candidates:
		var is_child_of_other := false
		for other in candidates:
			if other != n3 and other.is_ancestor_of(n3):
				is_child_of_other = true
				break
		if not is_child_of_other:
			_shift_x(n3, shift)


func _shift_x(n: Node3D, amount: float) -> void:
	var p := n.global_position
	p.x += amount
	n.global_position = p   # y and z untouched
	n.reset_physics_interpolation()   # no smear across the world if interpolation is on


func _get_segment_aabb(root: Node3D, road_only := true) -> AABB:
	var result := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if road_only and road_mesh_name != "" and node.name != road_mesh_name:
			continue
		var mi := node as MeshInstance3D
		var box: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	if first and road_only and road_mesh_name != "":
		push_warning("RoadManager: no mesh named '%s' in '%s', measuring all meshes instead." % [road_mesh_name, root.name])
		return _get_segment_aabb(root, false)
	return result
