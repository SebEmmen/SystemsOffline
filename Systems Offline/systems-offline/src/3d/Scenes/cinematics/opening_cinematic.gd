
extends Node

@export_group("References")
@export var player: CharacterBody3D
@export var forcefield: MeshInstance3D
@export var fallen_crate: Node3D


@export_group("Camera")
@export var turn_duration: float = 1.5
@export var turn_angle: float = 180.0

@export_group("Debug")
@export var debug_enabled: bool = true

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var starting_rotation: float
var camera_tween: Tween
var cinematic_active: bool = false
var forcefield_tween: Tween


@export var forcefield_hum: AudioStreamPlayer3D



func start_forcefield_hum() -> void:
	if forcefield_hum == null:
		push_warning("ForcefieldHum is not assigned!")
		return

	if not forcefield_hum.playing:
		forcefield_hum.play()
		print("Forcefield hum started")







func _ready() -> void:
	var should_play_intro: bool = SaveManager.play_opening_cinematic

	# Initialize the material.
	setup_forcefield()

	# Always start with the forcefield invisible.
	set_forcefield_parameters(0.0, 0.0)

	await get_tree().process_frame

	if should_play_intro:
		SaveManager.play_opening_cinematic = false
		start_cinematic()






func _unhandled_input(event: InputEvent) -> void:
	if not debug_enabled:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_P:
			start_cinematic()




func start_cinematic() -> void:
	if cinematic_active or player == null:
		return

	cinematic_active = true

	# Reset the forcefield before every cinematic.
	set_forcefield_parameters(0.0, 0.0)

	# Stop the previous activation animation if it is running.
	if forcefield_tween and forcefield_tween.is_running():
		forcefield_tween.kill()

	# Stop the humming sound so it can restart.
	if forcefield_hum:
		forcefield_hum.stop()

	starting_rotation = player.rotation.y

	player.disable_controls()
	animation_player.play("Opening")






func look_behind() -> void:
	rotate_player(starting_rotation + PI, true)


func look_forward() -> void:
	# Turn to 30 degrees right of the starting direction.
	rotate_player(starting_rotation - deg_to_rad(30.0), false)
	drop_crate()


func look_straight_ahead() -> void:
	# Return to the original starting direction.
	rotate_player(starting_rotation, true)



func drop_crate() -> void:
	if fallen_crate == null:
		push_warning("OpeningCinematic: Fallen crate not assigned!")
		return

	print("release_crate called")
	fallen_crate.release_crate()





func rotate_player(target_rotation: float, left: bool) -> void:
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_EXPO)
	camera_tween.set_ease(Tween.EASE_IN_OUT)

	var current_rotation: float = player.rotation.y
	var angle_difference: float = wrapf(
		target_rotation - current_rotation,
		-PI,
		PI
	)

	if left:
		if angle_difference < 0.0:
			angle_difference += TAU
	else:
		if angle_difference > 0.0:
			angle_difference -= TAU

	camera_tween.tween_property(
		player,
		"rotation:y",
		current_rotation + angle_difference,
		turn_duration
	)




func finish_cinematic() -> void:
	if camera_tween and camera_tween.is_running():
		camera_tween.kill()

	player.rotation.y = starting_rotation

	# Synchronize the player's internal mouse-look rotation.
	var head: Node3D = player.get_node("Head")
	player.set("look_rotation", Vector2(head.rotation.x, player.rotation.y))

	cinematic_active = false
	player.enable_controls()
	SaveManager.save_game()
	

func set_forcefield_activation(
	progress: float,
	flicker: float
) -> void:
	if forcefield == null:
		return

	var material := forcefield.get_active_material(0) as ShaderMaterial

	if material == null:
		return

	material.set_shader_parameter(
		"activation_progress",
		progress
	)

	material.set_shader_parameter(
		"activation_flicker",
		flicker
	)


var forcefield_material: ShaderMaterial


func setup_forcefield() -> void:
	if forcefield == null:
		push_warning("Forcefield not assigned!")
		return

	forcefield_material = forcefield.get_active_material(0).duplicate() as ShaderMaterial
	forcefield.set_surface_override_material(0, forcefield_material)

	if SaveManager.play_opening_cinematic:
		set_forcefield_parameters(0.0, 0.0)
	else:
		set_forcefield_parameters(1.0, 1.0)


func set_forcefield_parameters(
	progress: float,
	flicker: float
) -> void:
	if forcefield_material == null:
		return

	forcefield_material.set_shader_parameter("activation", 1.0)
	forcefield_material.set_shader_parameter("activation_progress", progress)
	forcefield_material.set_shader_parameter("activation_flicker", flicker)


func activate_forcefield() -> void:
	start_forcefield_hum()
	if forcefield_material == null:
		return

	forcefield_tween = create_tween()
	var tween := forcefield_tween

	# Brief startup flicker.
	tween.tween_method(
		func(value: float):
			set_forcefield_parameters(0.02, value),
		0.0, 1.0, 0.12
	)

	tween.tween_method(
		func(value: float):
			set_forcefield_parameters(0.02, value),
		1.0, 0.0, 0.08
	)

	tween.tween_method(
		func(value: float):
			set_forcefield_parameters(0.02, value),
		0.0, 1.0, 0.12
	)

	# Diagonal activation wave.
	tween.tween_method(
		func(value: float):
			set_forcefield_parameters(value, 1.0),
		0.02, 1.0, 0.65
	)

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
