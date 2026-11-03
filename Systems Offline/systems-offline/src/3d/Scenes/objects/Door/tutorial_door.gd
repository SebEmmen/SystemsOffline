
extends Node3D

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

@export_group("Tutorial")
@export var requires_key: bool = false

var is_open: bool = false
var is_moving: bool = false
var is_unlocked: bool = false

var left_closed_position: Vector3
var right_closed_position: Vector3
var left_handle_original_position: Vector3
var right_handle_original_position: Vector3

var hide_timer_version: int = 0

var locked: bool:
	get:
		return not is_unlocked
	set(value):
		is_unlocked = not value

func _ready() -> void:
	left_closed_position = left_door.position
	right_closed_position = right_door.position
	left_handle_original_position = left_handle.position
	right_handle_original_position = right_handle.position

	is_unlocked = not requires_key


func open_door() -> void:
	print("open_door")
	if is_open or is_moving:
		return

	if not is_unlocked:
		print("Tutorial Door is locked. A key is required.")
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
	is_unlocked = true

	left_handle.get_node("Cylinder").set_instance_shader_parameter("activated", 1.0)
	right_handle.get_node("Cylinder").set_instance_shader_parameter("activated", 1.0)


func lock_door() -> void:
	is_unlocked = false
