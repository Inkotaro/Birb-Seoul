class_name DialogueCameraSwitcher
extends Node
## Switches PhantomCameras when the dialogue fires a `camera` event.
## Cameras are every PhantomCamera in the "gameplay-camera" group, looked up live,
## so cameras added or removed at runtime work.
## The event value is the camera node's name, or `default` for the camera that was
## active when the timeline started.
## If several cameras share the requested name, the one closest to the current
## camera is used.

const CAMERA_GROUP := "gameplay-camera"

## Optional. If empty, the runner is found through DialogueRunner.find().
@export var runner: DialogueRunner
@export var event_key: String = "camera"
## Go back to the starting camera when the timeline ends.
@export var restore_on_finish: bool = true
## Priority given to the active camera. Others are set to 0.
@export var active_priority: int = 10

var _return_cam: Node = null  # camera that was active when the timeline started
var _active: Node = null      # camera this script last switched to


func _ready() -> void:
	# Wait a frame so the runner exists, whatever the tree order.
	await get_tree().process_frame
	if runner == null:
		runner = DialogueRunner.find(self)
	if runner == null:
		push_error("DialogueCameraSwitcher: no DialogueRunner found")
		return
	runner.timeline_started.connect(_on_timeline_started)
	runner.event_fired.connect(_on_event)
	runner.timeline_finished.connect(_on_timeline_finished)


## Looked up fresh every time, so dynamically added cameras are included.
func _get_cameras() -> Array[Node]:
	var out: Array[Node] = []
	for cam in get_tree().get_nodes_in_group(CAMERA_GROUP):
		if cam is PhantomCamera3D or cam is PhantomCamera2D:
			out.append(cam)
	return out


## The camera with the highest priority right now (the one currently in control).
func _get_top_camera() -> Node:
	var top: Node = null
	for cam in _get_cameras():
		if top == null or cam.priority > top.priority:
			top = cam
	return top


## Among cameras with this name, returns the one closest to the current camera.
func _find_closest_named(cam_name: String) -> Node:
	var reference := _get_top_camera()
	var best: Node = null
	var best_dist := INF
	for cam in _get_cameras():
		if String(cam.name).to_lower() != cam_name:
			continue
		var d := _distance(reference, cam)
		# `best == null` keeps the first match when distance can't be measured.
		if best == null or d < best_dist:
			best = cam
			best_dist = d
	return best


func _distance(a: Node, b: Node) -> float:
	if a is Node3D and b is Node3D:
		return a.global_position.distance_to(b.global_position)
	if a is Node2D and b is Node2D:
		return a.global_position.distance_to(b.global_position)
	return INF


func _on_timeline_started(_timeline: String = "") -> void:
	_return_cam = _get_top_camera()
	_active = _return_cam


func _on_event(key: String, value: String) -> void:
	if key != event_key:
		return
	var cam_name := value.strip_edges().to_lower()
	if cam_name.is_empty() or cam_name == "default":
		switch_to(_return_cam)
		return
	var target := _find_closest_named(cam_name)
	if target == null:
		push_warning("DialogueCameraSwitcher: no camera named '%s' in group '%s'" % [value, CAMERA_GROUP])
		return
	switch_to(target)


func _on_timeline_finished(_timeline: String = "") -> void:
	if restore_on_finish:
		switch_to(_return_cam)
	_return_cam = null
	_active = null


func switch_to(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	if target == _active:
		return
	# If the starting camera was never captured (event without a start), capture it now.
	if _return_cam == null or not is_instance_valid(_return_cam):
		_return_cam = _get_top_camera()
	for cam in _get_cameras():
		cam.priority = 0
	target.priority = active_priority
	_active = target
