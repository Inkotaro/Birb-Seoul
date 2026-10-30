extends Control
@export var duration: float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, duration)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
