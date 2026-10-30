extends Button
@export_file("*.tscn") var target_scene_path: String


func _on_pressed() -> void:
	if target_scene_path != "":
		get_tree().change_scene_to_file(target_scene_path)
	else:
		print("Error: Target scene belum diisi di Inspector!")
	
