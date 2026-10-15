extends Node3D

## Loads and displays the actual Room1 level as a living 3D panoramic background.
## Strips player/controller/HUD to prevent input conflicts, and provides
## cinematic panoramic sweeping and responsive mouse parallax.

@export var sweep_speed: float = 0.03
@export var parallax_strength: Vector2 = Vector2(0.06, 0.04)
@export var smoothing: float = 4.0

@onready var camera: Camera3D = $Camera3D

# Room 1 vantage points
const VIEWPOINTS = [
	{
		"name": "Facility Hall",
		"pos": Vector3(-0.5, 2.4, 3.2),
		"rot": Vector3(-7.0, 0.0, 0.0)
	},
	{
		"name": "Control Terminal",
		"pos": Vector3(0.6, 1.8, -4.8),
		"rot": Vector3(-4.0, 35.0, 0.0)
	},
	{
		"name": "Cargo Bay",
		"pos": Vector3(4.5, 2.2, 1.0),
		"rot": Vector3(-6.0, -35.0, 0.0)
	}
]

var current_view_index: int = 0
var target_cam_pos: Vector3 = Vector3(-0.5, 2.4, 3.2)
var base_cam_rot: Vector3 = Vector3(-7.0, 0.0, 0.0)

var target_parallax: Vector2 = Vector2.ZERO
var current_parallax: Vector2 = Vector2.ZERO

var is_panoramic_mode: bool = false
var pan_look_rotation: Vector2 = Vector2.ZERO
var sweep_time: float = 0.0

func _ready() -> void:
	_load_room1()
	set_viewpoint(0, true)

func _load_room1() -> void:
	var room_res = load("res://src/3d/Scenes/rooms/Room1.tscn") as PackedScene
	if not room_res:
		push_error("Room1Panorama: Failed to load Room1.tscn")
		return

	var room_instance = room_res.instantiate()

	# Remove player controller, HUD, UI managers, and inactive transition cameras
	# so that Room 1 acts purely as a pristine 3D background world
	for child_name in ["ProtoController", "HUD", "UI_Manger", "TransitionCamera"]:
		var node = room_instance.get_node_or_null(child_name)
		if node:
			room_instance.remove_child(node)
			node.queue_free()

	add_child(room_instance)

func _process(delta: float) -> void:
	sweep_time += delta

	if is_panoramic_mode:
		camera.position = camera.position.lerp(target_cam_pos, delta * 3.0)
		camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, pan_look_rotation.y, delta * 12.0)
		camera.rotation_degrees.y = lerp(camera.rotation_degrees.y, pan_look_rotation.x, delta * 12.0)
		camera.rotation_degrees.z = 0.0
	else:
		# Subtle cinematic drift
		var sweep_yaw = sin(sweep_time * sweep_speed) * 6.0
		var sweep_pitch = cos(sweep_time * sweep_speed * 0.8) * 1.5

		current_parallax = current_parallax.lerp(target_parallax, delta * smoothing)

		var final_rot_x = base_cam_rot.x + sweep_pitch - (current_parallax.y * parallax_strength.y * 57.2958)
		var final_rot_y = base_cam_rot.y + sweep_yaw - (current_parallax.x * parallax_strength.x * 57.2958)

		camera.position = camera.position.lerp(target_cam_pos, delta * smoothing)
		camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, final_rot_x, delta * smoothing)
		camera.rotation_degrees.y = lerp(camera.rotation_degrees.y, final_rot_y, delta * smoothing)
		camera.rotation_degrees.z = 0.0

func update_mouse_position(normalized_pos: Vector2) -> void:
	target_parallax = normalized_pos

func set_panoramic_mode(enabled: bool) -> void:
	is_panoramic_mode = enabled
	if enabled and camera:
		pan_look_rotation.x = camera.rotation_degrees.y
		pan_look_rotation.y = camera.rotation_degrees.x

func handle_pan_input(relative_motion: Vector2) -> void:
	if not is_panoramic_mode:
		return
	var sens = 0.15
	pan_look_rotation.x -= relative_motion.x * sens
	pan_look_rotation.y = clamp(pan_look_rotation.y - relative_motion.y * sens, -75.0, 75.0)

func set_viewpoint(index: int, instant: bool = false) -> void:
	current_view_index = posmod(index, VIEWPOINTS.size())
	var vp = VIEWPOINTS[current_view_index]
	target_cam_pos = vp["pos"]
	base_cam_rot = vp["rot"]
	if instant and camera:
		camera.position = target_cam_pos
		camera.rotation_degrees = base_cam_rot
		pan_look_rotation = Vector2(base_cam_rot.y, base_cam_rot.x)

func next_viewpoint() -> String:
	set_viewpoint(current_view_index + 1)
	return VIEWPOINTS[current_view_index]["name"]

func get_current_view_name() -> String:
	return VIEWPOINTS[current_view_index]["name"]
