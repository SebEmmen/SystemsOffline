extends Node3D

@export var left_door: Node3D
@export var right_door: Node3D
@export var slide_distance: float = 1.5
@export var slide_duration: float = 1.0

var is_open: bool = false
var is_moving: bool = false

var left_closed_position: Vector3
var right_closed_position: Vector3


func _ready() -> void:
	left_closed_position = left_door.position
	right_closed_position = right_door.position


func open_door() -> void:
	if is_open or is_moving:
		return

	is_moving = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# Left panel slides left
	tween.tween_property(
		left_door,
		"position",
		left_closed_position + Vector3.LEFT * slide_distance,
		slide_duration
	)

	# Right panel slides right
	tween.tween_property(
		right_door,
		"position",
		right_closed_position + Vector3.RIGHT * slide_distance,
		slide_duration
	)

	await tween.finished

	is_open = true
	is_moving = false
