extends DarkButton

@onready var setting_menu: Control = get_node_or_null("%SettingMenu")

func _on_activated() -> void:
	if setting_menu:
		setting_menu.show()
	else:
		push_warning("SettingButton: couldn't find %SettingMenu in this scene.")
