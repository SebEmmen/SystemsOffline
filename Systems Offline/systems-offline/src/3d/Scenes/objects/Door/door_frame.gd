
extends StaticBody3D

@export var sliding_door: Node3D

var interaction_type: InteractableComponent.InteractionType = InteractableComponent.InteractionType.BUTTON


func interact() -> void:
	if sliding_door:
		sliding_door.close_door()


func get_interaction_message() -> String:
	if sliding_door and sliding_door.is_open:
		return "Press E to close door"

	return ""
