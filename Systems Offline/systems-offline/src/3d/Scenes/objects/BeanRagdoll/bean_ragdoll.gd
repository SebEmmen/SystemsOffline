
extends RigidBody3D

@export_group("Crush Physics")
@export var launch_force: float = 14.0
@export var upward_force: float = 5.0
@export var tumble_force: float = 12.0

func activate_crush(direction: Vector3) -> void:
	# Make sure the ragdoll is awake.
	sleeping = false

	# Give the bean forward and upward momentum.
	var launch_direction: Vector3 = direction.normalized()

	linear_velocity = (
		launch_direction * launch_force
		+ Vector3.UP * upward_force
	)

	# Spin the bean as it flies through the air.
	angular_velocity = Vector3(
		randf_range(-tumble_force, tumble_force),
		randf_range(-tumble_force * 0.3, tumble_force * 0.3),
		randf_range(-tumble_force, tumble_force)
	)
