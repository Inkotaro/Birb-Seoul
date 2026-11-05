class_name DarkButton
extends Button
## Base class for dark-theme menu buttons: dim text that warms up when selected, a soft
## flickering ember glow behind it, a thin accent line that grows from the center, and two
## small diamond markers that glide in beside the text.
## Hover = focus, so mouse, keyboard and gamepad share a single highlight.
##
## This class only handles the look and feel. It does NOT do anything when pressed on its own:
## inherit it and override _on_activated() to give a button its action:
##
##     extends DarkButton
##     func _on_activated() -> void:
##         get_tree().quit()
##
## The press animation, flash and sound still play automatically; you only provide the action.
## If you override _ready() in a child, call super() first.

@export_group("Colors")
@export var idle_text_color := Color("7d776e")
@export var active_text_color := Color("ece4d3")
@export var accent_color := Color("b3412e")   ## line + markers (ember red)
@export var glow_color := Color("6e1f14")     ## soft light behind the text

@export_group("Style")
@export var font_size := 30
@export_range(0.0, 1.0) var glow_strength := 0.55
@export var line_thickness := 2.0
@export_range(0.0, 0.5) var idle_line_alpha := 0.12  ## faint divider line when not selected
@export var marker_size := 5.0
@export_range(0.0, 0.5) var flicker := 0.12          ## candle-like glow flicker (0 = off)

@export_group("Motion")
@export var anim_time := 0.35
@export var active_scale := 1.04

@export_group("Sound (optional)")
@export var hover_sound: AudioStream
@export var click_sound: AudioStream

var _bg: Control
var _sfx: AudioStreamPlayer
var _tween: Tween
var _active := false
var _time := 0.0
var _flicker_mult := 1.0
var _t := 0.0:      # 0 = idle, 1 = selected
	set(v):
		_t = v
		_apply_state()
var _flash := 0.0:  # click flash, 1 -> 0
	set(v):
		_flash = v
		if _bg:
			_bg.queue_redraw()


func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_ALL
	add_theme_font_size_override("font_size", font_size)

	# Remove the default button look; everything is drawn by _draw_bg()
	var empty := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(style, empty)

	# Drawn BEHIND the button so the text stays on top
	_bg = Control.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.show_behind_parent = true
	_bg.draw.connect(_draw_bg)
	add_child(_bg)

	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)

	mouse_entered.connect(func(): if not disabled: grab_focus())
	focus_entered.connect(func(): _set_active(true))
	focus_exited.connect(func(): _set_active(false))

	set_process(false)
	_apply_state()


func _process(delta: float) -> void:
	# Only runs while selected (or fading out) to drive the flicker
	_time += delta
	if _active and flicker > 0.0:
		_flicker_mult = 1.0 - flicker * (0.5 + 0.25 * (sin(_time * 11.0) + sin(_time * 4.3 + 1.7)))
		_bg.queue_redraw()
	elif not _active and _t < 0.001:
		_flicker_mult = 1.0
		set_process(false)


func _pressed() -> void:
	# Don't override this in children (it plays the feedback); override _on_activated() instead.
	_play(click_sound)

	# Short flash of light + a tiny press-in
	_flash = 1.0
	var flash := create_tween()
	flash.tween_property(self, "_flash", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var punch := create_tween()
	punch.tween_property(self, "scale", Vector2.ONE * active_scale * 0.96, 0.06)
	punch.tween_property(self, "scale", Vector2.ONE * active_scale, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_on_activated()


## Override this in a child script to define what the button does.
func _on_activated() -> void:
	pass


# ---------------------------------------------------------------- animation

func _set_active(on: bool) -> void:
	_active = on
	if on:
		_play(hover_sound)
		set_process(true)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var time := anim_time if on else anim_time * 0.8
	var target := 1.0 if on else 0.0
	_tween.tween_property(self, "_t", target, time) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (active_scale if on else 1.0), time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _apply_state() -> void:
	var c := clampf(_t, 0.0, 1.0)
	var col := idle_text_color.lerp(active_text_color, c)
	for n in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(n, col)
	add_theme_color_override("font_disabled_color", idle_text_color.darkened(0.4))
	if _bg:
		_bg.queue_redraw()


func _play(stream: AudioStream) -> void:
	if stream and _sfx:
		_sfx.stream = stream
		_sfx.play()


# ---------------------------------------------------------------- drawing

func _draw_bg() -> void:
	var c := clampf(_t, 0.0, 1.0)
	var w := size.x
	var h := size.y
	var mid := w * 0.5

	# Faint divider so idle buttons still read as a list
	_bg.draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5),
		Color(idle_text_color, idle_line_alpha * (1.0 - c)), 1.0)

	if c <= 0.001 and _flash <= 0.001:
		return

	# Soft glow: transparent at both edges, strongest in the middle
	var a := (c * glow_strength + _flash * 0.35) * _flicker_mult
	var lit := Color(glow_color, a)
	var clear := Color(glow_color, 0.0)
	_bg.draw_polygon(
		PackedVector2Array([Vector2(0, 0), Vector2(mid, 0), Vector2(mid, h), Vector2(0, h)]),
		PackedColorArray([clear, lit, lit, clear]))
	_bg.draw_polygon(
		PackedVector2Array([Vector2(mid, 0), Vector2(w, 0), Vector2(w, h), Vector2(mid, h)]),
		PackedColorArray([lit, clear, clear, lit]))

	# Accent line growing outward from the center
	var half := mid * c
	_bg.draw_line(Vector2(mid - half, h - 1.0), Vector2(mid + half, h - 1.0),
		Color(accent_color, c), line_thickness)

	# Diamond markers gliding in from further out to sit beside the text
	var text_w := get_theme_font("font").get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var gap := 18.0 + (1.0 - c) * 28.0
	var cy := h * 0.5
	for side in [-1.0, 1.0]:
		var cx: float = mid + side * (text_w * 0.5 + gap)
		_bg.draw_colored_polygon(PackedVector2Array([
			Vector2(cx, cy - marker_size), Vector2(cx + marker_size, cy),
			Vector2(cx, cy + marker_size), Vector2(cx - marker_size, cy),
		]), Color(accent_color, c))
