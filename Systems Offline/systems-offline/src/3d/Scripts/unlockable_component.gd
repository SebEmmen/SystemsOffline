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

#region Door Specific Variables
@export_group("Door Panels")
@export var left_door: Node3D
@export var right_door: Node3D
@export var slide_distance: float = 5
@export var slide_duration: float = 2

@export_group("Door Handles")
@export var left_handle: Node3D
@export var right_handle: Node3D
@export var handle_push_distance: float = -0.059
@export var handle_duration: float = 0.25
@export var handle_hide_delay: float = 1.0

@export var left_button_mesh: MeshInstance3D
@export var right_button_mesh: MeshInstance3D
@export var handle_light_on: Array[MeshInstance3D]
@export var handle_light_off: Array[MeshInstance3D]

var is_open: bool = false
var is_moving: bool = false
var left_closed_position: Vector3
var right_closed_position: Vector3
var left_handle_original_position: Vector3
var right_handle_original_position: Vector3

var hide_timer_version: int = 0
#endregion
var audiotimer: bool = false
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

@export var sliding_door: Node3D
@export var needskey_sounds: Array[AudioStream] = []
@onready var needskey_sound_player: AudioStreamPlayer3D = $NeedsKeySoundPlayer

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
		
		UnlockableType.DOOR:
			ready_door()

func interact() -> void:
	match unlockable_type:
		UnlockableType.DOOR:
			interact_door()
		UnlockableType.COVER:
			open_cover()

#region Door Functions

func ready_door() -> void:
	left_closed_position = left_door.position
	right_closed_position = right_door.position
	left_handle_original_position = left_handle.position
	right_handle_original_position = right_handle.position
	toggle_handle_light(!locked, locked)
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
		open_door()
	else:
		close_door()
	await get_tree().create_timer(1.0).timeout
	can_interact = true

func open_door() -> void:
	print("open_door")
	if is_open or is_moving:
		return

	if locked:
		print("Tutorial Door is locked. A key is required.")
		Notification.locked_notification()
		if not audiotimer:
			audiotimer = true
			random_array_se()
			await get_tree().create_timer(2.0).timeout
			audiotimer = false
		return

	is_moving = true

	left_handle.show()
	right_handle.show()

	await animate_handles(true)
	await animate_doors(true)

	is_open = true
	is_moving = false

	hide_handles_after_delay()


func close_door() -> void:
	if not is_open or is_moving:
		return

	is_moving = true

	# Cancel any pending hide timer.
	hide_timer_version += 1

	left_handle.show()
	right_handle.show()

	await animate_doors(false)
	await animate_handles(false)

	is_open = false
	is_moving = false


func animate_handles(push: bool) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	var left_target := left_handle_original_position
	var right_target := right_handle_original_position

	if push:
		left_target.y -= handle_push_distance
		right_target.y += handle_push_distance

	tween.tween_property(
		left_handle,
		"position",
		left_target,
		handle_duration
	)

	tween.tween_property(
		right_handle,
		"position",
		right_target,
		handle_duration
	)

	await tween.finished


func animate_doors(open: bool) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	var left_target := left_closed_position
	var right_target := right_closed_position

	if open:
		left_target += Vector3.LEFT * slide_distance
		right_target += Vector3.RIGHT * slide_distance

	tween.tween_property(
		left_door,
		"position",
		left_target,
		slide_duration
	)

	tween.tween_property(
		right_door,
		"position",
		right_target,
		slide_duration
	)

	await tween.finished


func hide_handles_after_delay() -> void:
	hide_timer_version += 1
	var current_version := hide_timer_version

	await get_tree().create_timer(handle_hide_delay).timeout

	if current_version != hide_timer_version:
		return

	if is_open and not is_moving:
		left_handle.hide()
		right_handle.hide()


func unlock_door() -> void:
	locked = false
	toggle_handle_light(!locked, locked)

	left_handle.get_node("Cylinder").set_instance_shader_parameter("activated", 1.0)
	right_handle.get_node("Cylinder").set_instance_shader_parameter("activated", 1.0)


func toggle_handle_light(on: bool, off: bool) -> void:
	for light in handle_light_on:
		light.visible = on
	for light in handle_light_off:
		light.visible = off
#endregion

#region Cover Functions

func ready_cover() -> void:
	keypad.can_interact = false

	if not key:
		return

	if SaveManager.tutorial_puzzle_completed:
		# Puzzle solved: key is already hanging on the hanger
		key.global_transform = key_hanger_target.global_transform
		key.show()
		locked = false
		can_interact = false
	else:
		key.hide()


func open_cover() -> void:
	if is_interacting or open:
		return
	if keypad and keypad.fixed:
		return


	if locked and not Inventory.has_item("tutorial_key"):
		Notification.locked_notification()
		if not audiotimer:
			audiotimer = true
			random_array_se()
			await get_tree().create_timer(2.0).timeout
			audiotimer = false
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
	keypad.can_interact = not keypad.fixed
	player.enable_controls()



func close_cover() -> void:
	if is_interacting:
		return

	is_interacting = true
	can_interact = false
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
