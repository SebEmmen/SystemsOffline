extends RigidBody3D

@export var push_force: float = 3.0
@export var upward_force: float = 1.0
@export var directional: String = "z"

func fall_off() -> void:
	freeze = false
	var direction = Vector3.ZERO
	match directional:
		"z":
			direction = global_transform.basis.z.normalized()
		"x": 
			direction = global_transform.basis.x.normalized()
	
	var impulse = direction * push_force + Vector3.UP * upward_force

	apply_central_impulse(impulse)
	apply_torque_impulse(global_transform.basis.x * 0.5)
