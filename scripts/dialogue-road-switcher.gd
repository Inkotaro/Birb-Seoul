class_name DialogueRoadSwitcher
extends Node
## Switches the road when the dialogue fires a `road` event.
## The event value is the road code registered in RoadTrigger.roads, e.g.
##     key: road     value: petshop
## Use the value `next` (or leave it empty) to cycle to the next road.
## Codes are matched exactly first, then ignoring upper/lower case.
## When a road switch starts, a sound is played from a child AudioStreamPlayer
## (AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D). Add one as a child of
## this node and assign its stream; the first one found is used unless you pick another.

## The RoadTrigger that holds the road list. Required.
@export var road_trigger: RoadTrigger
## Optional. If empty, the runner is found through DialogueRunner.find().
@export var runner: DialogueRunner
@export var event_key: String = "road"
## Finish the swap immediately instead of waiting for the player to walk to the border.
## The world pops, so use it under a black screen / cutscene.
@export var instant_switch: bool = false
## Optional. Leave empty to use the first audio player child of this node.
@export var sound_player: Node

var _sound  # the audio player that gets played (untyped: works for 1D / 2D / 3D players)


func _ready() -> void:
	# Wait a frame so the runner exists, whatever the tree order.
	await get_tree().process_frame
	if runner == null:
		runner = DialogueRunner.find(self)
	if runner == null:
		push_error("DialogueRoadSwitcher: no DialogueRunner found")
		return
	if road_trigger == null:
		push_error("DialogueRoadSwitcher: road_trigger is not assigned")
		return
	_sound = sound_player if sound_player != null else _find_child_player()
	runner.event_fired.connect(_on_event)


func _on_event(key: String, value: String) -> void:
	if key != event_key or road_trigger == null:
		return

	var code := value.strip_edges()
	if code.is_empty() or code.to_lower() == "next":
		road_trigger.cycle()
	else:
		var resolved := _resolve_code(code)
		if resolved.is_empty():
			push_warning("DialogueRoadSwitcher: unknown road '%s'. Known: %s" \
				% [value, road_trigger.roads.keys()])
			return
		road_trigger.break_to(resolved)

	_play_sound()

	var manager := road_trigger.road_manager
	if instant_switch and manager != null and manager.is_breaking():
		manager.force_commit()


## Exact match first, then case-insensitive. Returns "" if nothing matches.
func _resolve_code(code: String) -> String:
	if road_trigger.roads.has(code):
		return code
	var lower := code.to_lower()
	for known in road_trigger.roads:
		if String(known).to_lower() == lower:
			return known
	return ""


func _find_child_player() -> Node:
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			return child
	return null


func _play_sound() -> void:
	if _sound != null and is_instance_valid(_sound):
		_sound.play()  # restarts the sound if it's already playing
