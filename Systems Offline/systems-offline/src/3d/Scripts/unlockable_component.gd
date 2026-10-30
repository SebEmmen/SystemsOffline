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
@export var pivot_left: Node3D
@export var pivot_right: Node3D
@export var cover_body: StaticBody3D

@export_group("Key Animation")
@export var key_start: Marker3D
@export var key_insert: Marker3D
@export var key_turn: Marker3D
@export var key_hanger_target: Marker3D
@export var key_arc_height: float = 0.8


var closed_left_rotation: float
var closed_right_rotation: float

var original_collision_layer: int
var original_collision_mask: int
#endregion

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_setup_audio_players()

	match unlockable_type:
		UnlockableType.COVER:
			if pivot_left == null or pivot_right == null or cover_body == null:
				push_error("Cover is missing required node references!")
				return

			closed_left_rotation = pivot_left.rotation.z
			closed_right_rotation = pivot_right.rotation.z

			original_collision_layer = cover_body.collision_layer
			original_collision_mask = cover_body.collision_mask

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
	play_primary_se()
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
			move_door(default_position, 0.4)
			is_interacting = !is_interacting
#endregion

#region Cover Functions

func ready_cover() -> void:
	keypad.can_interact = false

# Interact calls to this funtion


func open_cover() -> void:
	if is_interacting or open:
		return

	if locked and not Inventory.has_item("tutorial_key"):
		Notification.locked_notification()
		return

	if not key or not key_start or not key_insert \
	or not key_turn or not key_hanger_target:
		push_error("Key cinematic references are missing!")
		return

	is_interacting = true
	can_interact = false
	keypad.can_interact = false
	player.disable_controls()

	# 1. Show key in front of keypad
	key.global_transform = key_start.global_transform
	key.show()

	await get_tree().create_timer(0.25).timeout

	# 2. Insert key
	await move_key_to(key_insert, 0.8)

	await get_tree().create_timer(0.2).timeout

	# 3. Turn key
	await move_key_to(key_turn, 0.5)

	await get_tree().create_timer(0.25).timeout

	# 4. Open cover
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		pivot_left,
		"rotation:z",
		deg_to_rad(160.0),
		cover_fade_duration
	)

	tween.tween_property(
		pivot_right,
		"rotation:z",
		deg_to_rad(-160.0),
		cover_fade_duration
	)

	await tween.finished

	cover_body.set_deferred("collision_layer", 0)
	cover_body.set_deferred("collision_mask", 0)

	# 5. Fly key to hanger
	await fly_key_to_hanger()

	# 6. Leave key hanging
	key.global_transform = key_hanger_target.global_transform

	# 7. Restore gameplay
	locked = false
	open = true
	is_interacting = false
	can_interact = true
	keypad.can_interact = true
	player.enable_controls()



func close_cover() -> void:
	if is_interacting:
		return

	is_interacting = true
	keypad.can_interact = false

	tween_cover()

	cover_body.set_deferred(
		"collision_layer", original_collision_layer
	)
	cover_body.set_deferred(
		"collision_mask", original_collision_mask
	)

	is_interacting = false

func tween_cover():
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		pivot_left,
		"rotation:z",
		closed_left_rotation,
		cover_fade_duration
	)

	tween.tween_property(
		pivot_right,
		"rotation:z",
		closed_right_rotation,
		cover_fade_duration
	)

	await tween.finished

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


func move_key_to(target: Marker3D, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		key,
		"global_transform",
		target.global_transform,
		duration
	)

	await tween.finished


func _update_key_flight(
	progress: float,
	start: Transform3D,
	target: Transform3D
) -> void:
	var position := start.origin.lerp(
		target.origin, progress
	)

	# Parabolic arc, highest at the midpoint
	position += Vector3.UP * (
		4.0 * key_arc_height * progress * (1.0 - progress)
	)

	var rotation := start.basis.slerp(
		target.basis, progress
	)

	key.global_transform = Transform3D(rotation, position)


func fly_key_to_hanger() -> void:
	var start := key.global_transform
	var target := key_hanger_target.global_transform

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(
		Callable(self, "_update_key_flight").bind(start, target),
		0.0,
		1.0,
		1.2
	)

	await tween.finished

#endregion



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
