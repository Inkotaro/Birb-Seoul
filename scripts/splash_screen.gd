extends Control
## Splash sequence: Godot logo -> Studio logo -> Title logo -> slide up to main menu.
##
## Attach to the root Control of your splash scene and set that scene as the Main Scene.
## Build your OWN logos and menu as Control nodes that are direct children of this root,
## then assign them in the Inspector. The script never creates a logo or menu for you;
## it only hides them, animates them in order, and slides the menu in at the end.

signal sequence_finished

@export_group("Logo Nodes (Control)")
@export var godot_logo: Control   ## shown first
@export var studio_logo: Control  ## shown second
@export var title_logo: Control   ## shown last, then slides up with the splash

@export_group("Main Menu (Control)")
## Slides up from below at the end. Leave empty to just slide the splash away.
@export var main_menu: Control

@export_group("Timing")
@export var start_delay := 0.5          ## black pause before the first logo
@export var fade_time := 0.9            ## fade in / fade out length for each logo
@export var hold_time := 1.4            ## fully visible time for each logo
@export_range(0.0, 2.0) var crossfade_overlap := 0.45  ## how much a logo fades out while the next fades in
@export var title_fade_time := 1.2
@export var title_hold_time := 1.6
@export var slide_time := 1.1

@export_group("Motion")
@export var logo_scale_from := 0.94     ## logos slowly drift from this scale...
@export var logo_scale_to := 1.03       ## ...to this scale while visible
@export var title_scale_from := 1.12
@export_range(0.0, 0.5) var title_parallax := 0.12  ## title leads the slide by this fraction of screen height

var _stage: Control
var _tweens: Array[Tween] = []
var _sliding := false
var _skipping := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_stage()
	_adopt(godot_logo, "godot_logo")
	_adopt(studio_logo, "studio_logo")
	_adopt(title_logo, "title_logo")
	if _ok(main_menu):
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	_sequence()


# ---------------------------------------------------------------- setup

func _ok(n: Variant) -> bool:
	return n != null and is_instance_valid(n)


func _build_stage() -> void:
	# Black stage that covers the menu and slides away at the end.
	_stage = Control.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(bg)


func _adopt(node: Variant, label: String) -> void:
	# Move the logo onto the stage (so it draws above the black background and slides
	# away with it) and hide it until its turn.
	if node == null:
		return
	if not is_instance_valid(node):
		push_warning("Splash: '%s' points to a node that no longer exists. Re-assign it in the Inspector." % label)
		return
	node.reparent(_stage, false)
	node.visible = true
	node.modulate.a = 0.0


func _new_tween() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _kill_tweens() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()


# ---------------------------------------------------------------- sequence

func _sequence() -> void:
	await get_tree().process_frame # let layout settle so sizes are valid
	for logo in [godot_logo, studio_logo, title_logo]:
		if _ok(logo):
			logo.pivot_offset = logo.size / 2.0

	await get_tree().create_timer(start_delay).timeout
	if _skipping:
		return

	for logo in [godot_logo, studio_logo]:
		if not _ok(logo):
			continue
		await _play_logo(logo)
		if _skipping:
			return

	await _show_title()
	if _skipping:
		return
	await _slide_to_menu()


func _play_logo(node: Control) -> void:
	var total := fade_time * 2.0 + hold_time
	node.scale = Vector2.ONE * logo_scale_from

	# Opacity: ease in, hold, ease out
	var fade := _new_tween()
	fade.tween_property(node, "modulate:a", 1.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_interval(hold_time)
	fade.tween_property(node, "modulate:a", 0.0, fade_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Continuous slow drift across the whole lifetime so the logo never feels static
	var drift := _new_tween()
	drift.tween_property(node, "scale", Vector2.ONE * logo_scale_to, total) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Return early so the next item fades in while this one is still fading out
	await get_tree().create_timer(total - minf(crossfade_overlap, fade_time)).timeout


func _show_title() -> void:
	if _ok(title_logo):
		title_logo.scale = Vector2.ONE * title_scale_from
		var t := _new_tween().set_parallel(true)
		t.tween_property(title_logo, "modulate:a", 1.0, title_fade_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(title_logo, "scale", Vector2.ONE, title_fade_time * 1.6) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await t.finished
		if _skipping:
			return
	await get_tree().create_timer(title_hold_time).timeout


func _slide_to_menu() -> void:
	if _sliding:
		return
	_sliding = true

	# Everything uses the same curve so the splash and the menu stay glued together.
	var t := _new_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_stage, "position:y", -size.y, slide_time)
	if _ok(title_logo):
		# Slight parallax: the title leads the slide for extra depth
		t.tween_property(title_logo, "position:y", title_logo.position.y - size.y * title_parallax, slide_time)
	if _ok(main_menu):
		main_menu.visible = true
		main_menu.position.y = size.y
		t.tween_property(main_menu, "position:y", 0.0, slide_time)
	await t.finished
	_finish()


func _finish() -> void:
	if _ok(main_menu):
		main_menu.process_mode = Node.PROCESS_MODE_INHERIT
		_focus_first_button(main_menu)
	_stage.queue_free()
	sequence_finished.emit()


# ---------------------------------------------------------------- skipping

func _unhandled_input(event: InputEvent) -> void:
	if _skipping or _sliding:
		return
	var pressed := event.is_pressed() and not event.is_echo()
	if pressed and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		_skip()


func _skip() -> void:
	_skipping = true
	_kill_tweens()

	# Quick smooth blend to the title instead of a hard cut
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.25)
	for logo in [godot_logo, studio_logo]:
		if _ok(logo):
			t.tween_property(logo, "modulate:a", 0.0, 0.25)
	if _ok(title_logo):
		t.tween_property(title_logo, "modulate:a", 1.0, 0.25)
		t.tween_property(title_logo, "scale", Vector2.ONE, 0.25)
	await t.finished
	_slide_to_menu()


func _focus_first_button(root: Control) -> void:
	# Give keyboard / gamepad something selected to navigate from
	for b in root.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus()
			return
