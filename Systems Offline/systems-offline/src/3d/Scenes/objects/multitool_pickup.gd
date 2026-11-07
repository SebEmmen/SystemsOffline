
extends Node3D

var interaction_type: InteractableComponent.InteractionType = \
	InteractableComponent.InteractionType.PICKUP

@export var can_interact: bool = true



func interact() -> void:
	if not can_interact:
		return

	var equipment := get_tree().get_first_node_in_group(
		"multitool_equipment"
	)

	if equipment == null:
		push_warning("Multitool equipment system not found.")
		return

	# Collect the Multitool.
	equipment.collect_multitool()
	can_interact = false

	# Show the pickup notification immediately.
	Notification.show_pickup_notification("Multitool")

	# Show the equipment hint after the pickup message.
	Notification.show_message_after_delay(
		"Press '1' to view the Multitool",
		true,
		2.1
	)

	# Remove the world model.
	queue_free()
