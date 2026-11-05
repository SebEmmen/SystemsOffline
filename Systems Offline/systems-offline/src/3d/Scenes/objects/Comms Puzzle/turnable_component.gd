class_name TurnableComponent
extends InteractableComponent

signal dial_turned(angle_degrees: float)

enum TurnType {
	DIAL
}

@export var turn_type: TurnType = TurnType.DIAL

@export_group("Inspect")
@export var inspect_camera: Camera3D

@export_group("Dial")
## The node that spins (your "Rotation Dial")
@export var dial_pivot: Node3D
@export var turn_axis: Vector3 = Vector3.UP
## 0 = free rotation, otherwise snaps to multiples of this many degrees
@export var snap_degrees: float = 0.0
@export var turn_sensitivity: float = 1.0
## Only start a drag if the click lands within this many pixels of the dial center (0 = anywhere)
@export var grab_radius_px: float = 0.0

var can_turn := false
var _dragging := false
var _last_mouse_angle := 0.0


@export var monitor: InspectComponent

func _ready() -> void:
	monitor.monitor_entered.connect(func(): can_turn = true; is_interacting = true)
	monitor.monitor_exited.connect(func(): can_turn = false; is_interacting = false; _dragging = false)
	_setup_audio_players()


func interact() -> void:
	if not can_interact or is_interacting or is_transitioning:
		return
	enter_inspect()


func get_interaction_message() -> String:
	return "Press [E] to use"


func enter_inspect() -> void:
	is_interacting = true
	player.disable_controls()
	player.visible = false

	# Must be VISIBLE (or HIDDEN), not CAPTURED, or mouse position won't update
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await get_tree().process_frame
	await transition(player_camera, inspect_camera)
	can_turn = true  # only now can the dial be touched


func exit_inspect() -> void:
	if not can_turn or is_transitioning:
		return

	can_turn = false
	_dragging = false
	await transition(inspect_camera, player_camera)
	player.visible = true
	is_interacting = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	player.enable_controls()


func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or is_transitioning or not can_turn:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		exit_inspect()
		get_viewport().set_input_as_handled()
		return

	if dial_pivot == null:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _mouse_on_dial():
				_dragging = true
				_last_mouse_angle = _get_mouse_angle()
		elif _dragging:
			_dragging = false
			_apply_snap()

	elif event is InputEventMouseMotion and _dragging:
		var current := _get_mouse_angle()
		var delta := wrapf(current - _last_mouse_angle, -PI, PI) * turn_sensitivity
		_last_mouse_angle = current

		var cam := get_viewport().get_camera_3d()
		var axis_world := (dial_pivot.global_transform.basis * turn_axis).normalized()
		if axis_world.dot(cam.global_transform.basis.z) > 0.0:
			delta = -delta

		dial_pivot.rotate_object_local(turn_axis.normalized(), delta)
		_total_angle += delta
		dial_turned.emit(rad_to_deg(_total_angle))


func _get_dial_center() -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(dial_pivot.global_position)


func _get_mouse_angle() -> float:
	return (get_viewport().get_mouse_position() - _get_dial_center()).angle()


func _mouse_on_dial() -> bool:
	if grab_radius_px <= 0.0:
		return true
	return get_viewport().get_mouse_position().distance_to(_get_dial_center()) <= grab_radius_px
