# RoadTheme.gd
# Add as a direct child of a road scene's root node. RoadManager reads it
# when that road becomes active. Leave a field empty to keep the current one.
class_name RoadTheme
extends Node

@export var environment: Environment
@export var environment_time := 4.0

@export var music: AudioStream
## Only used for the very first road (instant start). Later fades follow distance.
@export var music_fade_time := 3.0
@export_range(0.25, 2.0, 0.01) var music_pitch := 1.0
@export var music_sync_position := false
