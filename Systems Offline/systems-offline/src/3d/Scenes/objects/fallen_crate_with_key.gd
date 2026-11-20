
extends Node3D

@export_group("Crate Physics")
@export var crate_body: RigidBody3D
@export var crate_lid: RigidBody3D

@export_group("Debug")
@export var debug_enabled: bool = true


func _ready() -> void:
	# Keep both parts frozen until released.
	crate_body.freeze = true
	crate_lid.freeze = true


func _unhandled_input(event: InputEvent) -> void:
	if not debug_enabled:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_G:
				release_crate()


func release_crate() -> void:
	if not crate_body.freeze and not crate_lid.freeze:
		return

	# Unfreeze both parts.
	crate_body.freeze = false
	crate_lid.freeze = false

	crate_body.sleeping = false
	crate_lid.sleeping = false

	# Move the crate 0.2 meters along the X-axis.
	crate_body.apply_central_impulse(Vector3(-41, 0.0, 0.0))
	crate_lid.apply_central_impulse(Vector3(-5.1, 0.0, 0.0))

	print("DEBUG: Crate released and pushed!")
