class_name PauseMenu
extends Control

@export_file("*.tscn") var main_menu_scene_path: String
@export var fade_time := 0.2

@onready var setting_menu: Control = get_node_or_null("SettingMenu")

var _open := false
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()

	if _open and setting_menu and setting_menu.visible:
		setting_menu.hide()
		_focus_first_button()
	else:
		toggle_pause()


func toggle_pause() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	get_tree().paused = true
	visible = true
	_fade_to(1.0)
	_focus_first_button()


func close() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	if setting_menu:
		setting_menu.hide()
	await _fade_to(0.0)
	if not _open:
		visible = false


func open_settings() -> void:
	if setting_menu:
		setting_menu.show()
	else:
		push_warning("PauseMenu: no child node named 'SettingMenu' found.")


func go_to_main_menu() -> void:
	if main_menu_scene_path == "":
		print("Err : Scene not found!")
		return
		
	var transition := get_node_or_null("/root/SceneTransition")
	if transition:
		transition.change_scene(main_menu_scene_path)
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file(main_menu_scene_path)

func _fade_to(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished


func _focus_first_button() -> void:
	var buttons := find_children("*", "Button", true, false)
	for b in buttons:
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return
