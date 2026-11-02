
extends StaticBody3D

@export var sliding_door: Node3D

var interaction_type: InteractableComponent.InteractionType = InteractableComponent.InteractionType.BUTTON


func interact() -> void:
	if sliding_door:
		sliding_door.open_door()


func get_interaction_message() -> String:
	return "Press E to open door"
