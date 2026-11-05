@tool
class_name TypewriterConfig
extends Resource

@export_group("Speed Settings")
@export var characters_per_second: float = 30.0
@export var punctuation_pause: float = 0.15  # not used by the runner yet

@export_group("Behaviour")
@export var allow_skip: bool = true

@export_group("Audio")
@export var type_sound: AudioStream
@export_range(1, 10) var characters_per_sound: int = 1
