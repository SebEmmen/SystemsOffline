
extends Camera3D

@export var follow_speed: float = 4.0
@export var camera_offset: Vector3 = Vector3(0.0, 2.5, 5.0)

var target: Node3D


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var desired_position: Vector3 = target.global_position + camera_offset

	global_position = global_position.lerp(
		desired_position,
		clampf(follow_speed * delta, 0.0, 1.0)
	)

	look_at(target.global_position, Vector3.UP)
