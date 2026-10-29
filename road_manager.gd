# RoadManager.gd (Node3D)
extends Node3D
class_name RoadManager

signal road_changed(new_scene: PackedScene)

@export var player: Node3D
@export var pcam: PhantomCamera3D
@export var segment_scene: PackedScene
@export var road_mesh_name := "" 

@export_group("Road switch")
@export var view_margin := 2.0 

@export_group("Camera damping blend")
@export var fade_distance := 20.0
@export var static_distance := 6.0
@export var min_damping := 0.0001

# order: 0 = left (view only), 1 = center (main), 2 = right (view only)
var segments: Array[Node3D] = []
var segment_length := 0.0
var origin_offset := 0.0

var _default_damping_enabled := false
var _default_damping_value := Vector3.ZERO

# road switch state
var _breaking := false
var _pending_scene: PackedScene
var _pending_length := 0.0
var _pending_offset := 0.0
var _old_view_boxes: Array[AABB] = []
var _static_frames := 0


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


func _physics_process(_delta: float) -> void:
	_update_camera_damping()   # first, so it's already static when the wrap happens
	_check_commit()
	_wrap_player()

func break_loop(new_scene: PackedScene) -> void:
	if _breaking or new_scene == null:
		return
	_breaking = true
	_pending_scene = new_scene

	var old_right := segments[2]
	var new_road := new_scene.instantiate() as Node3D
	add_child(new_road)

	var box := _get_segment_aabb(new_road)
	_pending_length = box.size.x
	_pending_offset = box.position.x

	new_road.global_position = Vector3(
		segment_length - _pending_offset,
		old_right.global_position.y,
		old_right.global_position.z)

	segments[2] = new_road
	old_right.queue_free()

	_old_view_boxes.clear()
	for i in 2:
		var seg := segments[i]
		var local_box := _get_segment_aabb(seg, false)
		var world_box: AABB = seg.global_transform * local_box
		_old_view_boxes.append(world_box.grow(view_margin))


func _check_commit() -> void:
	if not _breaking:
		return
	
	if player.global_position.x < segment_length:
		return
	
	if _old_road_visible():
		return
	_commit_new_road()


func _old_road_visible() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	var planes := cam.get_frustum()
	for box in _old_view_boxes:
		if _aabb_in_frustum(box, planes):
			return true
	return false


func _aabb_in_frustum(box: AABB, planes: Array[Plane]) -> bool:
	for plane in planes:
		var all_outside := true
		for i in 8:
			if not plane.is_point_over(box.get_endpoint(i)):
				all_outside = false
				break
		if all_outside:
			return false
	return true


func _commit_new_road() -> void:
	var shift := -segment_length
	_shift_x(player, shift)
	_shift_x(pcam, shift)
	for n in get_tree().get_nodes_in_group("loop_wrap"):
		_shift_x(n as Node3D, shift)

	if _default_damping_enabled:
		pcam.follow_damping = false
		_static_frames = 2

	var new_road := segments[2]
	_shift_x(new_road, shift)

	segments[0].queue_free()
	segments[1].queue_free()

	segment_length = _pending_length
	origin_offset = _pending_offset

	var left := _spawn_segment(_pending_scene, -1, new_road)
	var right := _spawn_segment(_pending_scene, 1, new_road)
	segments = [left, new_road, right]

	_breaking = false
	_old_view_boxes.clear()
	road_changed.emit(_pending_scene)
	segment_scene = _pending_scene
	_pending_scene = null


func _spawn_segment(scene: PackedScene, slot: int, ref: Node3D) -> Node3D:
	var seg := scene.instantiate() as Node3D
	add_child(seg)
	seg.global_position = Vector3(
		slot * segment_length - origin_offset,
		ref.global_position.y,
		ref.global_position.z)
	return seg

func _update_camera_damping() -> void:
	if not _default_damping_enabled:
		return

	if _static_frames > 0:
		_static_frames -= 1
		pcam.follow_damping = false
		return

	var x := player.global_position.x
	
	var dist_to_edge := x if _breaking else minf(x, segment_length - x)

	var blend := 1.0 - smoothstep(static_distance, fade_distance, dist_to_edge)

	if blend >= 1.0:
		pcam.follow_damping = false
	else:
		pcam.follow_damping = true
		var static_value := Vector3.ONE * min_damping
		pcam.follow_damping_value = _default_damping_value.lerp(static_value, blend)

func _wrap_player() -> void:
	var x := player.global_position.x
	var shift := 0.0
	if x >= segment_length and not _breaking:
		shift = -segment_length
	elif x < 0.0:
		shift = segment_length
	if shift == 0.0:
		return

	_shift_x(player, shift)
	_shift_x(pcam, shift)
	for n in get_tree().get_nodes_in_group("loop_wrap"):
		_shift_x(n as Node3D, shift)


func _shift_x(n: Node3D, amount: float) -> void:
	var p := n.global_position
	p.x += amount
	n.global_position = p   # y and z untouched


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
	return result
