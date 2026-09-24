class_name UnlockableComponent
extends InteractableComponent

enum UnlockabelType{
	DOOR,
	COVER
}

@export var unlockable_type: UnlockabelType

#region Unlockable Specific Variables
@export_group("Unlockable")
@onready var default_position: Vector3 = object_ref.position
@export var locked: bool = true
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func interact() -> void:
	match unlockable_type:
		UnlockabelType.DOOR:
			interact_door()

#region Door Functions

# Interact Function for Door

func interact_door() -> void:
	if locked:
		print("Door is locked!")
		return
	if can_interact:
		can_interact = false
		is_interacting = !is_interacting
	var tween_door = create_tween()
	var target_pos = default_position + Vector3(2.95, 0, 0)
	if is_interacting:
		tween_door.tween_property(object_ref, "position", target_pos, 1.0)
	else:
		tween_door.tween_property(object_ref, "position", default_position, 1.0)
	await get_tree().create_timer(1.0).timeout
	can_interact = true

# Unlocks the door
func unlock_door() -> void:
	locked = false
	print("Door unlocked!")
	
#endregion

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
