extends Node
# on an Area3D, or wherever your event fires
@export var road_manager: RoadManager
@export var next_road: PackedScene

func _on_body_entered(body):
	if body.is_in_group("player"):
		road_manager.break_loop(next_road)
