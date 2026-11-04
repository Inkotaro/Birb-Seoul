extends Button
@onready var setting_menu =$"../../../SettingMenu"




func _on_pressed() -> void:
	setting_menu.show()
