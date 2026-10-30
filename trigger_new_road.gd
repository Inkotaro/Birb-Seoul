# RoadTrigger.gd
# Self-contained: holds the road code list and calls road_manager.break_loop().
extends Node
class_name RoadTrigger

@export var road_manager: RoadManager
## road code -> road scene. If left empty, DEFAULT_ROADS below are loaded at startup.
@export var roads: Dictionary[String, PackedScene] = {}
## Code to switch to when triggered. Leave empty to cycle to the next road.
@export var road_code := ""

@export_group("Triggers")
## Optional input action that fires this trigger (leave empty to disable).
@export var input_action: StringName = &"break_loop"

@export_group("Debug")
@export var debug_cycle_enabled := true
@export var debug_cycle_key: Key = KEY_L   # debug builds only
## Debug: switch roads immediately (skips walking to the border; the world pops).
@export var debug_instant_switch := false
@export var debug_log := true

# Paths instead of preload(): a missing file only prints a warning
# instead of breaking the whole script.
const DEFAULT_ROADS := {
	"seoul_1": "res://roads/seoul_1.tscn",
	"seoul_2": "res://roads/seoul_2.tscn",
	"seoul_3": "res://roads/seoul_3.tscn",
}


func _ready() -> void:
	if roads.is_empty():
		for code in DEFAULT_ROADS:
			var path: String = DEFAULT_ROADS[code]
			if not ResourceLoader.exists(path):
				push_warning("RoadTrigger: '%s' not found, skipping road '%s'." % [path, code])
				continue
			var scene := load(path) as PackedScene
			if scene:
				roads[code] = scene


func _input(event: InputEvent) -> void:
	# has_action() check: is_action_pressed() spams errors if the action isn't in the InputMap
	if input_action != &"" and InputMap.has_action(input_action) \
			and event.is_action_pressed(input_action):
		trigger()
		return

	if debug_cycle_enabled and OS.is_debug_build() \
			and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == debug_cycle_key:
		cycle()


## Switch to `road_code`, or cycle to the next road if it's empty.
func trigger() -> void:
	if road_code == "":
		cycle()
	else:
		break_to(road_code)


## Switch to the road registered under `code`.
func break_to(code: String) -> void:
	if road_manager == null:
		push_warning("RoadTrigger: road_manager is not assigned.")
		return
	if not roads.has(code):
		push_warning("RoadTrigger: unknown road code '%s'. Known: %s" % [code, roads.keys()])
		return
	if debug_log:
		print("[RoadTrigger] %s -> %s" % [current_code(), code])
	road_manager.break_loop(roads[code])   # the manager ignores "already on this road"
	if debug_instant_switch and road_manager.is_breaking():
		road_manager.force_commit()


## Switch to the next road in the dictionary (wraps around).
func cycle() -> void:
	if roads.is_empty():
		push_warning("RoadTrigger: roads list is empty.")
		return
	var keys: Array = roads.keys()
	var i := keys.find(current_code())
	break_to(keys[(i + 1) % keys.size()])


## Code of the road currently active ("" if it isn't in the list).
func current_code() -> String:
	if road_manager == null:
		return ""
	for code in roads:
		if roads[code].resource_path == road_manager.segment_scene.resource_path:
			return code
	return ""
