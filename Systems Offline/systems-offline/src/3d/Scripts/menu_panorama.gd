extends Node3D

## Manages the 3D panoramic background for the Main Menu,
## including cinematic camera drift, interactive mouse parallax,
## viewpoint switching, and full 360-degree panorama mode.

@export var sweep_speed: float = 0.04
@export var parallax_strength: Vector2 = Vector2(0.08, 0.05)
@export var smoothing: float = 4.0

@onready var camera: Camera3D = $Camera3D
@onready var emergency_light: OmniLight3D = $Lighting/EmergencyLight
@onready var particles: CPUParticles3D = $AtmosphereParticles

# Viewpoint presets (position, rotation_degrees)
const VIEWPOINTS = [
	{
		"name": "Observation Deck",
		"pos": Vector3(0.0, 2.2, 3.8),
		"rot": Vector3(-5.0, 0.0, 0.0)
	},
	{
		"name": "Control Terminal",
		"pos": Vector3(-2.2, 1.6, 0.8),
		"rot": Vector3(-8.0, 35.0, 0.0)
	},
	{
		"name": "Storage Sector",
		"pos": Vector3(2.5, 1.8, 1.2),
		"rot": Vector3(-6.0, -40.0, 0.0)
	},
	{
		"name": "Panorama Vista",
		"pos": Vector3(0.0, 3.2, 6.0),
		"rot": Vector3(2.0, 180.0, 0.0)
	}
]

var current_view_index: int = 0
var target_cam_pos: Vector3 = Vector3(0.0, 2.2, 3.8)
var base_cam_rot: Vector3 = Vector3(-5.0, 0.0, 0.0)

var mouse_offset: Vector2 = Vector2.ZERO
var target_parallax: Vector2 = Vector2.ZERO
var current_parallax: Vector2 = Vector2.ZERO

var is_panoramic_mode: bool = false
var pan_look_rotation: Vector2 = Vector2.ZERO
var sweep_time: float = 0.0

var pulse_time: float = 0.0

func _ready() -> void:
	set_viewpoint(0, true)
	if camera:
		pan_look_rotation = Vector2(base_cam_rot.y, base_cam_rot.x)

func _process(delta: float) -> void:
	sweep_time += delta
	pulse_time += delta

	# Emergency beacon pulse (slow, tense sci-fi heartbeat)
	if emergency_light:
		var pulse = (sin(pulse_time * 2.5) + 1.0) * 0.5
		emergency_light.light_energy = lerp(0.8, 3.5, pulse * pulse)

	if is_panoramic_mode:
		# Free 360 look in panoramic mode
		camera.position = camera.position.lerp(target_cam_pos, delta * 3.0)
		camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, pan_look_rotation.y, delta * 12.0)
		camera.rotation_degrees.y = lerp(camera.rotation_degrees.y, pan_look_rotation.x, delta * 12.0)
		camera.rotation_degrees.z = 0.0
	else:
		# Cinematic panoramic sweep + subtle mouse parallax
		var sweep_yaw = sin(sweep_time * sweep_speed) * 8.0 # gentle +/- 8 degree panoramic sway
		var sweep_pitch = cos(sweep_time * sweep_speed * 0.7) * 2.0
		
		current_parallax = current_parallax.lerp(target_parallax, delta * smoothing)

		var final_rot_x = base_cam_rot.x + sweep_pitch - (current_parallax.y * parallax_strength.y * 57.2958)
		var final_rot_y = base_cam_rot.y + sweep_yaw - (current_parallax.x * parallax_strength.x * 57.2958)

		camera.position = camera.position.lerp(target_cam_pos, delta * smoothing)
		camera.rotation_degrees.x = lerp(camera.rotation_degrees.x, final_rot_x, delta * smoothing)
		camera.rotation_degrees.y = lerp(camera.rotation_degrees.y, final_rot_y, delta * smoothing)
		camera.rotation_degrees.z = 0.0

func update_mouse_position(normalized_pos: Vector2) -> void:
	# normalized_pos ranges from (-1, -1) to (1, 1) relative to screen center
	target_parallax = normalized_pos

func set_panoramic_mode(enabled: bool) -> void:
	is_panoramic_mode = enabled
	if enabled:
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
