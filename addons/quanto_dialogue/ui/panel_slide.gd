class_name DialoguePanelSlide
extends Node
## Slides a panel up from the bottom of the screen when the parent
## DialogueRunner starts a timeline, and back down when it finishes.

@export var panel: Control
@export var duration: float = 0.45
@export var trans: Tween.TransitionType = Tween.TRANS_BACK
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var extra_offset: float = 20.0  # extra distance past the screen edge

var _shown_y: float
var _hidden_y: float
var _progress: float = 0.0  # 0 = hidden, 1 = shown
var _tween: Tween


func _ready() -> void:
	var runner := get_parent() as DialogueRunner
	if runner == null:
		push_error("DialogPanelSlide must be a child of a DialogueRunner")
		return
	runner.timeline_started.connect(show_panel)
	runner.timeline_finished.connect(hide_panel)

	# Wait one frame so anchors/containers have laid the panel out.
	await get_tree().process_frame
	_shown_y = panel.position.y
	var screen_h := panel.get_viewport_rect().size.y
	_hidden_y = _shown_y + (screen_h - panel.global_position.y) + extra_offset
	_apply(0.0)


func show_panel() -> void:
	_animate_to(1.0)


func hide_panel() -> void:
	_animate_to(0.0)


func _animate_to(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(trans).set_ease(ease_type)
	# Slide out with a cleaner curve than the overshooting "back" used for sliding in.
	if target == 0.0:
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_method(_apply, _progress, target, duration)


func _apply(t: float) -> void:
	_progress = t
	panel.position.y = lerpf(_hidden_y, _shown_y, t)
