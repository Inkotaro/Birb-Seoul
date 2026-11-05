extends Control
## Settings panel with Master / Music / SFX volume sliders.
## Assign the nodes below in the Inspector. Values are stored by the "Settings" autoload
## (settings.gd), which also saves them to user://settings.cfg.
##
## To add Music and SFX: duplicate your existing slider row twice, then assign the new
## HSliders to the matching slots.

@export var exit_button: Button
@export var master_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider

@export_group("SFX preview (optional)")
## Played (on the SFX bus) when you release the SFX slider, so you can hear the level.
@export var sfx_preview: AudioStream

var _settings: Node
var _sliders := {}  # bus name -> HSlider
var _preview_player: AudioStreamPlayer


func _ready() -> void:
	hide()

	_settings = get_node_or_null("/root/Settings")
	if _settings == null:
		push_error("SettingsMenu: add settings.gd as an autoload named 'Settings' (Project Settings -> Globals).")

	_bind(master_slider, "Master")
	_bind(music_slider, "Music")
	_bind(sfx_slider, "SFX")

	if sfx_slider and sfx_preview:
		_preview_player = AudioStreamPlayer.new()
		_preview_player.bus = "SFX"
		_preview_player.stream = sfx_preview
		add_child(_preview_player)
		sfx_slider.drag_ended.connect(func(_changed: bool): _preview_player.play())

	if exit_button:
		exit_button.pressed.connect(close)

	visibility_changed.connect(_on_visibility_changed)


func close() -> void:
	hide()


func _bind(slider: HSlider, bus: String) -> void:
	if slider == null:
		return
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	_sliders[bus] = slider
	slider.value_changed.connect(func(v: float):
		if _settings:
			_settings.set_volume(bus, v))
	_refresh_slider(bus)


func _refresh_slider(bus: String) -> void:
	var slider: HSlider = _sliders[bus]
	if _settings:
		slider.set_value_no_signal(_settings.get_volume(bus))


func _on_visibility_changed() -> void:
	if visible:
		for bus in _sliders:
			_refresh_slider(bus)  # always show the real current values
	elif _settings:
		_settings.save_now()  # saved whenever the panel closes, however it was closed
