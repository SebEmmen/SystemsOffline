class_name UnlockableComponent
extends InteractableComponent

enum UnlockableType{
	DOOR,
	COVER
}

@export var unlockable_type: UnlockableType

#region Unlockable Specific Variables
@export_group("Unlockable")
@onready var default_position: Vector3 = object_ref.position
@export var locked: bool = true
@onready var open: bool = false
#endregion


#region Cover Specific Variables
@export_group("Cover")
@export var cover_fade_duration: float = 0.5
@export var keypad: KeypadComponent
@export var key: Node3D
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	match unlockable_type:
		UnlockableType.COVER:
			ready_cover()

func interact() -> void:
	match unlockable_type:
		UnlockableType.DOOR:
			interact_door()
		UnlockableType.COVER:
			open_cover()

#region Door Functions

# Interact Function for Door

func interact_door() -> void:
	if locked:
		print("Door is locked!")
		Notification.locked_notification()
		return
	if can_interact:
		can_interact = false
		is_interacting = !is_interacting
	var target_pos = default_position + Vector3(2.95, 0, 0)
	if is_interacting:
		move_door(target_pos, 1.0)
	else:
		move_door(default_position, 1.0)
	await get_tree().create_timer(1.0).timeout
	can_interact = true

func move_door(position: Vector3, time: float) -> void:
	var tween_door = create_tween()
	tween_door.tween_property(object_ref, "position", position, time)
	

# Unlocks the door
func unlock_door() -> void:
	locked = false
	print("Door unlocked!")

func _on_area_3d_body_exited(body: Node3D) -> void:
	if !locked:	
		if body.is_in_group("player"): # or your player check
			print("player detected!")
			interact_door()
#endregion

#region Cover Functions

func ready_cover() -> void:
	keypad.can_interact = false

# Interact calls to this funtion
func open_cover() -> void:
	if locked and not Inventory.has_item("tutorial_key"):
		Notification.locked_notification()
		print("You need to find the key to access the keypad!")
		return
	
	locked = !locked
	# prevent player from moving if they can open 
	is_interacting = !is_interacting
	player.disable_controls()
	
	if object_ref == null:
		print("Error keypad_cover == null")
		return

	var tween := create_tween()
	
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	
	tween.tween_property(
		object_ref,
		"rotation:x",
		deg_to_rad(-160.0),
		cover_fade_duration
	)

	await tween.finished
	
	is_interacting = !is_interacting
	player.enable_controls()
	
	keypad.can_interact = true


func whiplash() -> void:
	print("Whiplash!")

	var original_rotation := player_camera.rotation.x

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Quickly look down
	tween.tween_property(
		player_camera,
		"rotation:x",
		original_rotation + deg_to_rad(10.0),
		0.15
	)

	# Return to the original rotation
	tween.tween_property(
		player_camera,
		"rotation:x",
		original_rotation,
		0.4
	)

	await tween.finished


#endregion



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
