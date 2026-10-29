extends RigidBody3D

@export var push_force: float = 2.0

func _physics_process(_delta: float) -> void:
	for body in get_colliding_bodies():
		if body is CharacterBody3D:
			var direction := global_position - body.global_position
			direction.y = 0.0

			if direction.length_squared() > 0.001:
				apply_central_impulse(
					direction.normalized() * push_force
				)
