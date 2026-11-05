extends Control
func _ready() -> void:
	hide()
	

func _on_button_pressed() -> void:
	hide()

func _on_h_slider_value_changed(value: float) -> void:
	_update_bus_volume("Master", value)

func _on_sfx_slider_value_changed(value: float) -> void:
	_update_bus_volume("SFX", value)

func _on_music_slider_value_changed(value: float) -> void:
	_update_bus_volume("Music", value)

func _update_bus_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	
	if bus_index == -1:
		print("Peringatan: Bus '%s' tidak ditemukan di AudioServer!" % bus_name)
		return
	if value <= 0.0001:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
