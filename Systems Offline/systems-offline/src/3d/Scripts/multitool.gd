class_name Multitool
extends InteractableComponent



enum MultitoolPart{
	BODY,
	COMMS,
	GRAVITY,
	STRENGTH,
	SHRINK,
	ARM
}

@export var multitool_part: MultitoolPart
@export var multitool_id: String

func _ready() -> void:
	match multitool_part:
		MultitoolPart.BODY:
			if SaveManager.is_multitool_part_complete("pickup_multitool"):
				queue_free()
			pass
		MultitoolPart.COMMS:
			if !SaveManager.dial_puzzle_completed:
				can_interact = false

func interact() -> void:
	match multitool_part:
		MultitoolPart.BODY:
			body_interact()
		MultitoolPart.COMMS:
			interact_comms()

#region Body functions
func body_interact() -> void:
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
	Notification.show_pickup_notification(item_data)

	# Show the equipment hint after the pickup message.
	Notification.show_message_after_delay(
		"Press '1' to view the Multitool",
		true,
		2.1
	)
	print("Object has been picked up!")
	
	Inventory.add_item(item_data)
	SaveManager.complete_multitool_part("pickup_multitool")
	# Remove the world model.
	queue_free()
#endregion

#region Comms Upgrade functions
func interact_comms() -> void:
	object_ref.visible = false
	Notification.show_pickup_notification(item_data)
	SaveManager.complete_multitool_part(item_data.item_id)
	
	queue_free()
#endregion
