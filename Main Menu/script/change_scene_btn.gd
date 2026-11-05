extends DarkButton
## Start button: the only button that changes scene.

@export_file("*.tscn") var target_scene_path: String = "res://main.tscn"


func _ready() -> void:
	super()
	# Start with this button selected (when the menu is already visible, e.g. no splash).
	# With the splash screen the menu is hidden at this point; splash_screen.gd focuses
	# the first button once the menu has slid in.
	if is_visible_in_tree():
		grab_focus.call_deferred()


func _on_activated() -> void:
	if target_scene_path == "":
		print("Error: Target scene belum diisi di Inspector!")
		return

	# Fade through the SceneTransition autoload if it exists, otherwise change instantly
	var transition := get_node_or_null("/root/SceneTransition")
	if transition:
		transition.change_scene(target_scene_path)
	else:
		get_tree().change_scene_to_file(target_scene_path)
