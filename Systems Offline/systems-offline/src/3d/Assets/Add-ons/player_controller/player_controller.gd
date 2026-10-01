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
@export var can_gravity_invert: bool = true
@export var gravity_invert: bool = false


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
#region Save System

func get_save_data() -> Dictionary:
	return {
		"position": [
			global_position.x,
			global_position.y,
			global_position.z
		],

		"rotation": [
			rotation.x,
			rotation.y,
			rotation.z
		],

		"head_rotation": [
			head.rotation.x,
			head.rotation.y,
			head.rotation.z
		],

		"is_shrunk": is_shrunk,
		"gravity_invert": gravity_invert
	}


func load_save_data(data: Dictionary) -> void:

	# Restore position
	var pos = data.get("position", [0, 0, 0])
	global_position = Vector3(pos[0], pos[1], pos[2])

	# Restore player rotation
	var rot = data.get("rotation", [0, 0, 0])
	rotation = Vector3(rot[0], rot[1], rot[2])

	# Restore head rotation
	var head_rot = data.get("head_rotation", [0, 0, 0])
	head.rotation = Vector3(head_rot[0], head_rot[1], head_rot[2])

	# Synchronize mouse movement
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

	# Restore shrinking
	is_shrunk = data.get("is_shrunk", false)

	if is_shrunk:
		scale = Vector3.ONE * 0.1
		camera.fov = 110
		ray.scale = Vector3.ONE * 0.2
	else:
		scale = Vector3.ONE
		camera.fov = 75
		ray.scale = Vector3.ONE * 2.0

	# Restore gravity
	gravity_invert = data.get("gravity_invert", false)

	if gravity_invert:
		up_direction = Vector3.DOWN
	else:
		up_direction = Vector3.UP

	velocity = Vector3.ZERO
	gravity_flipping = false
	left_surface = false
	controls_enabled = true

#endregion
#region Step
const MAX_STEP_HEIGHT = 0.5 # Raycasts length should match this. StairsAhead one should be slightly longer.
var _snapped_to_stairs_last_frame := false
var _last_frame_was_on_floor = -INF
#endregion


var mouse_captured: bool = false
var look_rotation: Vector2
var move_speed: float = 0.0
var gravity_flipping := false
var left_surface := false
var current_move_dir := Vector3.ZERO

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
	if is_on_floor(): _last_frame_was_on_floor = Engine.get_physics_frames()

	# Apply gravity
	if has_gravity and not gravity_invert:
		if not is_on_floor():
			velocity += get_gravity() * delta
			
	if has_gravity and gravity_invert:
		if not is_on_ceiling():
			velocity += get_gravity() * delta * -1

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

	# Gravity invert
	if can_gravity_invert and controls_enabled and Input.is_action_just_pressed("gravity_invert"):
		if is_on_floor() or is_on_ceiling():
			gravity_invert = !gravity_invert
			up_direction = Vector3.DOWN if gravity_invert else Vector3.UP

			gravity_flipping = true
			left_surface = false
			controls_enabled = false
		else:
			print("Must be on floor or ceiling!")

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

		current_move_dir = (
			transform.basis *
			Vector3(input_dir.x, 0, input_dir.y)
		).normalized()


		if current_move_dir:
			velocity.x = current_move_dir.x * move_speed
			velocity.z = current_move_dir.z * move_speed

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
	_snap_down_to_stairs_check()

	# Regain controls after gravity flip
	if gravity_flipping:
		# First wait until we've actually left the old surface
		if not is_on_floor() and not is_on_ceiling():
			left_surface = true

		# Only restore controls after leaving and landing again
		if left_surface and (is_on_floor() or is_on_ceiling()):
			gravity_flipping = false
			left_surface = false
			controls_enabled = true
		
func rotate_look(rot_input: Vector2) -> void:

	look_rotation.x -= rot_input.y * look_speed

	look_rotation.x = clamp(
		look_rotation.x,
		#deg_to_rad(-85),
		#deg_to_rad(85)
		deg_to_rad(-50),
		deg_to_rad(100)
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
	
func toggle_mouse() -> void:
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)



func disable_controls() -> void:
	controls_enabled = false
	for n in my_crosshairs:
		n.hide()
	for m in my_HUD_labels:
		m.hide()
	

	release_mouse()


func enable_controls() -> void:
	controls_enabled = true
	for n in my_crosshairs:
		n.show()
	for m in my_HUD_labels:
		m.show()


	capture_mouse()

func toggle_controls() -> void:
	controls_enabled = !controls_enabled
	toggle_mouse()

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


#region step
func is_surface_too_steep(normal: Vector3) -> bool:
	return normal.angle_to(Vector3.UP) > self.floor_max_angle
	
func _run_body_test_motion(from : Transform3D, motion : Vector3, result = null) -> bool:
	if not result: result = PhysicsTestMotionResult3D.new()
	var params = PhysicsTestMotionParameters3D.new()
	params.from = from
	params.motion = motion
	return PhysicsServer3D.body_test_motion(self.get_rid(), params, result)
	
func _snap_down_to_stairs_check() -> void:
	var did_snap := false
	# Modified slightly from tutorial. I don't notice any visual difference but I think this is correct.
	# Since it is called after move_and_slide, _last_frame_was_on_floor should still be current frame number.
	# After move_and_slide off top of stairs, on floor should then be false. Update raycast incase it's not already.
	%StairsBelowRayCast3D.force_raycast_update()
	var floor_below : bool = %StairsBelowRayCast3D.is_colliding() and not is_surface_too_steep(%StairsBelowRayCast3D.get_collision_normal())
	var was_on_floor_last_frame = Engine.get_physics_frames() == _last_frame_was_on_floor
	if not is_on_floor() and velocity.y <= 0 and (was_on_floor_last_frame or _snapped_to_stairs_last_frame) and floor_below:
		var body_test_result = KinematicCollision3D.new()
		if self.test_move(self.global_transform, Vector3(0,-MAX_STEP_HEIGHT,0), body_test_result):
			#_save_camera_pos_for_smoothing()
			var translate_y = body_test_result.get_travel().y
			self.position.y += translate_y
			apply_floor_snap()
			did_snap = true
	_snapped_to_stairs_last_frame = did_snap
	
func _snap_up_stairs_check(delta) -> bool:
	if not is_on_floor() and not _snapped_to_stairs_last_frame: return false
	# Don't snap stairs if trying to jump, also no need to check for stairs ahead if not moving
	if self.velocity.y > 0 or (self.velocity * Vector3(1,0,1)).length() == 0: return false
	var expected_move_motion = self.velocity * Vector3(1,0,1) * delta
	var step_pos_with_clearance = self.global_transform.translated(expected_move_motion + Vector3(0, MAX_STEP_HEIGHT * 2, 0))
	# Run a body_test_motion slightly above the pos we expect to move to, towards the floor.
	#  We give some clearance above to ensure there's ample room for the player.
	#  If it hits a step <= MAX_STEP_HEIGHT, we can teleport the player on top of the step
	#  along with their intended motion forward.
	var down_check_result = KinematicCollision3D.new()
	if (self.test_move(step_pos_with_clearance, Vector3(0,-MAX_STEP_HEIGHT*2,0), down_check_result)
	and (down_check_result.get_collider().is_class("StaticBody3D") or down_check_result.get_collider().is_class("CSGShape3D"))):
		var step_height = ((step_pos_with_clearance.origin + down_check_result.get_travel()) - self.global_position).y
		# Note I put the step_height <= 0.01 in just because I noticed it prevented some physics glitchiness
		# 0.02 was found with trial and error. Too much and sometimes get stuck on a stair. Too little and can jitter if running into a ceiling.
		# The normal character controller (both jolt & default) seems to be able to handled steps up of 0.1 anyway
		if step_height > MAX_STEP_HEIGHT or step_height <= 0.01 or (down_check_result.get_position() - self.global_position).y > MAX_STEP_HEIGHT: return false
		%StairsAheadRayCast3D.global_position = down_check_result.get_position() + Vector3(0,MAX_STEP_HEIGHT,0) + expected_move_motion.normalized() * 0.1
		%StairsAheadRayCast3D.force_raycast_update()
		if %StairsAheadRayCast3D.is_colliding() and not is_surface_too_steep(%StairsAheadRayCast3D.get_collision_normal()):
			#_save_camera_pos_for_smoothing()
			self.global_position = step_pos_with_clearance.origin + down_check_result.get_travel()
			apply_floor_snap()
			_snapped_to_stairs_last_frame = true
			return true
	return false
	
#func _save_camera_pos_for_smoothing():
	#if _saved_camera_global_pos == null:
		#_saved_camera_global_pos = %CameraSmooth.global_position

#endregion
