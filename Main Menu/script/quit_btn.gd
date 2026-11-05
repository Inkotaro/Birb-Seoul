extends DarkButton
## Example child: a button that quits the game instead of changing scene.

func _on_activated() -> void:
	get_tree().quit()
