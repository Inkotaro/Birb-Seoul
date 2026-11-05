extends Node3D

var player: QuantoDialoguePlayer


func _ready() -> void:
	player = get_tree().get_first_node_in_group("quanto-dialogue-player") as QuantoDialoguePlayer
	if player == null:
		push_error("No node in group 'quanto-dialogue-player'")


func _on_interactable_interacted(interactor: Node3D) -> void:
	player = get_tree().get_first_node_in_group("quanto-dialogue-player") as QuantoDialoguePlayer
	if player == null:
		return
	player.timeline_finished.connect(
		func(_id): InteractionManager.finish_interaction(),
		CONNECT_ONE_SHOT
	)
	print(player)
	player.play("cafe")
