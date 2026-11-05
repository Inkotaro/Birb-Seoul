extends Node

signal volume_changed(bus: String, value: float)

const SAVE_PATH := "user://settings.cfg"
const AUDIO_BUSES := ["Master", "Music", "SFX"]
const SAVE_DELAY := 0.5   # saves this long after the last change, so dragging a slider doesn't spam the disk

var _volumes := {}
var _warned := {}
var _save_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for bus in AUDIO_BUSES:
		_volumes[bus] = 1.0

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)

	load_settings()
	for bus in AUDIO_BUSES:
		_apply_volume(bus)


# ---------------------------------------------------------------- volume

## Volume as a linear value from 0.0 (silent) to 1.0 (full).
func get_volume(bus: String) -> float:
	return _volumes.get(bus, 1.0)


func set_volume(bus: String, linear: float) -> void:
	linear = clampf(linear, 0.0, 1.0)
	_volumes[bus] = linear
	_apply_volume(bus)
	volume_changed.emit(bus, linear)
	_save_timer.start()


func _apply_volume(bus: String) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		if not _warned.has(bus):
			_warned[bus] = true
			push_warning("Settings: audio bus '%s' doesn't exist. Add it in the Audio tab." % bus)
		return
	var v: float = _volumes[bus]
	AudioServer.set_bus_mute(idx, v <= 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


# ---------------------------------------------------------------- saving / loading

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # first run: keep defaults
	for bus in AUDIO_BUSES:
		var saved = cfg.get_value("audio", bus.to_lower() + "_volume", 1.0)
		_volumes[bus] = clampf(float(saved), 0.0, 1.0)


func save_now() -> void:
	_save_timer.stop()
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # keep any other sections you add later
	for bus in AUDIO_BUSES:
		cfg.set_value("audio", bus.to_lower() + "_volume", _volumes[bus])
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_error("Settings: failed to save '%s' (error %d)" % [SAVE_PATH, err])


func _notification(what: int) -> void:
	# Make sure a pending change isn't lost if the player closes the game right away
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _save_timer and not _save_timer.is_stopped():
		save_now()
