class_name CinematicBars
extends Control
## Tweens existing bars in when the parent DialogueRunner starts a timeline
## and out when it finishes. Bars should be laid out in their SHOWN position.

@onready var top_bar: Control = $TopBar
@onready var bottom_bar: Control = $BottomBar
@export var duration: float = 0.5
@export var trans: Tween.TransitionType = Tween.TRANS_CUBIC
@export var ease_type: Tween.EaseType = Tween.EASE_OUT

var _top_shown: float
var _bottom_shown: float
var _top_hidden: float
var _bottom_hidden: float
var _progress: float = 0.0  # 0 = hidden, 1 = shown
var _tween: Tween


func _ready() -> void:
	var runner := get_parent() as DialogueRunner
	if runner == null:
		push_error("CinematicBars must be a child of a DialogueRunner")
		return

	# Remember where the bars sit in the editor, then park them off-screen.
	_top_shown = top_bar.position.y
	_bottom_shown = bottom_bar.position.y
	_top_hidden = _top_shown - top_bar.size.y
	_bottom_hidden = _bottom_shown + bottom_bar.size.y
	_apply(0.0)

	runner.timeline_started.connect(show_bars)
	runner.timeline_finished.connect(hide_bars)


func show_bars() -> void:
	_animate_to(1.0)


func hide_bars() -> void:
	_animate_to(0.0)


func _animate_to(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(trans).set_ease(ease_type)
	_tween.tween_method(_apply, _progress, target, duration)


func _apply(t: float) -> void:
	_progress = t
	top_bar.position.y = lerpf(_top_hidden, _top_shown, t)
	bottom_bar.position.y = lerpf(_bottom_hidden, _bottom_shown, t)
