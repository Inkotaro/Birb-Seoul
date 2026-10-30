extends Control
@onready var exit_btn = $MarginContainer/MarginContainer2/VBoxContainer2/HBoxContainer/Button
@onready var volume_slider = $MarginContainer/MarginContainer2/VBoxContainer2/VBoxContainer/HSlider
func _ready() -> void:
	hide()
	



func _on_button_pressed() -> void:
	hide()


func _on_h_slider_value_changed(value: float) -> void:
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
