extends AudioStreamPlayer
class_name SFXPlayer

@export var sounds: Array[AudioStream] = []
@export_range(0.1, 4.0, 0.01) var min_pitch: float = 0.9
@export_range(0.1, 4.0, 0.01) var max_pitch: float = 1.1
func play_sfx(from_position: float = 0.0) -> void:
	if sounds.is_empty():
		push_warning("SFXPlayer has no sounds assigned: ", name)
		return
	stream = sounds.pick_random()
	pitch_scale = randf_range(min_pitch, max_pitch)
	print(stream)
	play(from_position)
