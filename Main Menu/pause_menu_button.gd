class_name PauseMenuButton
extends DarkButton
## One script for every button in the pause menu. Pick the Action in the Inspector.

enum Action { RESUME, SETTINGS, MAIN_MENU }

@export var action: Action = Action.RESUME


func _on_activated() -> void:
	var menu := _find_pause_menu()
	if menu == null:
		push_warning("PauseMenuButton '%s' must be inside a PauseMenu node." % name)
		return

	match action:
		Action.RESUME:
			menu.close()
		Action.SETTINGS:
			menu.open_settings()
		Action.MAIN_MENU:
			menu.go_to_main_menu()


func _find_pause_menu() -> PauseMenu:
	var n := get_parent()
	while n:
		if n is PauseMenu:
			return n
		n = n.get_parent()
	return null
