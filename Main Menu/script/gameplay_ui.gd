extends Control
@onready var setting_menu = $SettingMenu
@export_file("*tscn") var main_menu_scene_path:String
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and  event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		toggle_pause()

func toggle_pause()->void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	visible = new_pause_state

func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	toggle_pause()



func _on_button_2_pressed() -> void:
	setting_menu.visible = true


func _on_button_3_pressed() -> void:
	if main_menu_scene_path != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(main_menu_scene_path)
	else:
		print("Err : Scene not found!")
