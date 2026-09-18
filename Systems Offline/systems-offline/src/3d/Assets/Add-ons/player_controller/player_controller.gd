# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

@export var camera: Camera3D
@export var ray: RayCast3D
@export var can_move: bool = true
@export var has_gravity: bool = true
@export var can_sprint: bool = true
@export var can_shrink: bool = false
@export var is_shrunk: bool = false

#region Speeds
@export_group("Speeds")

@export var look_speed: float = 0.002
@export var base_speed: float = 5.0
@export var sprint_speed: float = 7.0
#endregion
#region Input Actions
@export_group("Input Actions")

@export var input_left: String = "move_left"
@export var input_right: String = "move_right"
@export var input_forward: String = "move_forward"
@export var input_back: String = "move_back"
@export var input_sprint: String = "sprint"
#endregion


var mouse_captured: bool = false
var look_rotation: Vector2
var move_speed: float = 0.0

var controls_enabled := true

@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider

@export var my_crosshairs: Array[Control]
@export var my_HUD_labels: Array[Label]


func _ready() -> void:
	check_input_mappings()

	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

	capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return

	# Capture mouse when clicking inside the game
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			capture_mouse()

	# Release mouse with Escape
	if event.is_action_pressed("ui_cancel"):
		release_mouse()

	# Look around
	if mouse_captured and event is InputEventMouseMotion:
		rotate_look(event.relative)



func _physics_process(delta: float) -> void:

	# Apply gravity
	if has_gravity:
		if not is_on_floor():
			velocity += get_gravity() * delta

	# Shrinking
	if can_shrink and controls_enabled and Input.is_action_just_pressed("shrink"):
		var tween = create_tween().set_parallel(true)
		if !is_shrunk:
			is_shrunk = !is_shrunk
			tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.2)
			tween.tween_property(camera, "fov", 110, 0.2)
			tween.tween_property(ray, "scale", Vector3(0.2, 0.2, 0.2), 0.2)

		else:
			is_shrunk = !is_shrunk
			tween.tween_property(self, "scale", Vector3(1, 1, 1), 0.2)
			tween.tween_property(camera, "fov", 75, 0.2)
			tween.tween_property(ray, "scale", Vector3(2.0, 2.0, 2.0), 0.2)



	# Sprinting
	if can_sprint and controls_enabled and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed


	# Movement
	if can_move and controls_enabled:

		var input_dir := Input.get_vector(
			input_left,
			input_right,
			input_forward,
			input_back
		)

		var move_dir := (
			transform.basis *
			Vector3(input_dir.x, 0, input_dir.y)
		).normalized()


		if move_dir:
			velocity.x = move_dir.x * move_speed
			velocity.z = move_dir.z * move_speed

		else:
			velocity.x = move_toward(
				velocity.x,
				0,
				move_speed
			)

			velocity.z = move_toward(
				velocity.z,
				0,
				move_speed
			)

	else:
		velocity.x = 0
		velocity.z = 0


	# Actually move the player
	move_and_slide()

func rotate_look(rot_input: Vector2) -> void:

	look_rotation.x -= rot_input.y * look_speed

	look_rotation.x = clamp(
		look_rotation.x,
		deg_to_rad(-85),
		deg_to_rad(85)
	)

	look_rotation.y -= rot_input.x * look_speed


	# Rotate player left/right
	transform.basis = Basis()
	rotate_y(look_rotation.y)


	# Rotate head up/down
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)


func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false



func disable_controls() -> void:
	controls_enabled = false

	for n in my_crosshairs:
		n.hide()
	for m in my_HUD_labels:
		m.hide()
	

	release_mouse()


func enable_controls() -> void:
	controls_enabled = true

	my_crosshairs[0].show()

	capture_mouse()


func check_input_mappings() -> void:

	if can_move and not InputMap.has_action(input_left):
		push_error(
			"Movement disabled. No InputAction found for input_left: "
			+ input_left
		)
		can_move = false


	if can_move and not InputMap.has_action(input_right):
		push_error(
			"Movement disabled. No InputAction found for input_right: "
			+ input_right
		)
		can_move = false


	if can_move and not InputMap.has_action(input_forward):
		push_error(
			"Movement disabled. No InputAction found for input_forward: "
			+ input_forward
		)
		can_move = false


	if can_move and not InputMap.has_action(input_back):
		push_error(
			"Movement disabled. No InputAction found for input_back: "
			+ input_back
		)
		can_move = false


	if can_sprint and not InputMap.has_action(input_sprint):
		push_error(
			"Sprinting disabled. No InputAction found for input_sprint: "
			+ input_sprint
		)
		can_sprint = false
