extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pressed.connect(_on_quit_btn_pressed)

func _on_quit_btn_pressed() -> void:
	get_tree().quit()
