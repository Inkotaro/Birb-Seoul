extends CanvasLayer
## Simple fade transition: fades to a color, swaps the scene, fades back in.
##
## Setup: Project Settings -> Globals (Autoload) -> add this script with the name "SceneTransition".
## Use:   SceneTransition.change_scene("res://scenes/game.tscn")

const FADE_COLOR := Color.BLACK
const FADE_OUT_TIME := 0.4   # screen going dark
const HOLD_TIME := 0.05      # how long it stays fully dark
const FADE_IN_TIME := 0.4    # screen coming back

var _busy := false
var _rect: ColorRect


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_rect = ColorRect.new()
	_rect.color = FADE_COLOR
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 0.0
	add_child(_rect)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP  # block clicks while fading

	# Load in the background while the screen fades out
	ResourceLoader.load_threaded_request(path)
	var fade_out := create_tween()
	fade_out.tween_property(_rect, "modulate:a", 1.0, FADE_OUT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_out.finished

	var status := ResourceLoader.load_threaded_get_status(path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_tree().paused = false  # leaving a paused game (e.g. pause menu) must not freeze the next scene
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path) as PackedScene)
		# The new scene is created at the end of the frame; wait for it to exist
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		push_error("SceneTransition: could not load '%s'" % path)

	await get_tree().create_timer(HOLD_TIME).timeout

	var fade_in := create_tween()
	fade_in.tween_property(_rect, "modulate:a", 0.0, FADE_IN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await fade_in.finished

	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
