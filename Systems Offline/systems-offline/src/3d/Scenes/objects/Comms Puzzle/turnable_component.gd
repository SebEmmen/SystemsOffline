class_name TurnableComponent
extends InteractableComponent

signal dial_turned(angle_degrees: float)
signal dial_snapped(index: int, symbol: String)

enum TurnType {
	DIAL
}

@export var turn_type: TurnType = TurnType.DIAL

@export_group("Monitor")
## The InspectComponent (type MONITOR) on the monitor this dial belongs to
@export var monitor: InspectComponent

@export_group("Dial")
## The node that spins (your "Rotation Dial")
@export var dial_pivot: Node3D
@export var turn_axis: Vector3 = Vector3.UP
## Number of stops around the dial
@export var positions: int = 8
## One entry per stop, e.g. ["A", "B", "C", ...]
@export var symbols: Array[String] = []
@export var snap_duration: float = 0.2
@export var turn_sensitivity: float = 1.0
## Only start a drag if the click is within this many pixels of the dial center (0 = anywhere)
@export var grab_radius_px: float = 0.0

@export_group("Debug")
## Tick to test the dial scene on its own, without a monitor
@export var debug_always_active := false

var can_turn := false
var current_index: int = 0

var _dragging := false
var _last_mouse_angle := 0.0
var _angle := 0.0   # radians, absolute
var _initial_basis: Basis
var _snap_tween: Tween


func _ready() -> void:
	_setup_audio_players()

	if dial_pivot:
		_initial_basis = dial_pivot.transform.basis
	else:
		push_warning("TurnableComponent: 'dial_pivot' is not assigned on " + name)

	if monitor:
		monitor.monitor_entered.connect(_on_monitor_entered)
		monitor.monitor_exited.connect(_on_monitor_exited)
	elif not debug_always_active:
		push_warning("TurnableComponent: 'monitor' is not assigned on " + name)

	if debug_always_active:
		is_interacting = true
		can_turn = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# The monitor handles interaction, so the dial itself is never interacted with directly
func interact() -> void:
	pass


func _on_monitor_entered() -> void:
	is_interacting = true
	can_turn = true


func _on_monitor_exited() -> void:
	can_turn = false
	is_interacting = false
	_dragging = false
	if _snap_tween:
		_snap_tween.kill()
	_snap_immediately()


func _unhandled_input(event: InputEvent) -> void:
	if not is_interacting or not can_turn or dial_pivot == null:
		return
	if SaveManager.dial_puzzle_completed:
		return   # solved, dial is locked

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _mouse_on_dial():
				if _snap_tween:
					_snap_tween.kill()   # grab it mid-snap
				_dragging = true
				_last_mouse_angle = _get_mouse_angle()
		elif _dragging:
			_dragging = false
			_snap()

	elif event is InputEventMouseMotion and _dragging:
		var current := _get_mouse_angle()
		var delta := wrapf(current - _last_mouse_angle, -PI, PI) * turn_sensitivity
		_last_mouse_angle = current

		# Flip direction depending on which way the axis faces the camera
		var cam := get_viewport().get_camera_3d()
		var axis_world := (dial_pivot.global_transform.basis * turn_axis).normalized()
		if axis_world.dot(cam.global_transform.basis.z) > 0.0:
			delta = -delta

		_set_angle(_angle + delta)
		dial_turned.emit(rad_to_deg(_angle))


#region Rotation helpers
func _set_angle(a: float) -> void:
	_angle = a
	dial_pivot.transform.basis = _initial_basis * Basis(turn_axis.normalized(), a)


func _get_dial_center() -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(dial_pivot.global_position)


func _get_mouse_angle() -> float:
	return (get_viewport().get_mouse_position() - _get_dial_center()).angle()


func _mouse_on_dial() -> bool:
	if grab_radius_px <= 0.0:
		return true
	return get_viewport().get_mouse_position().distance_to(_get_dial_center()) <= grab_radius_px
#endregion


#region Snapping
func _snap() -> void:
	var step := TAU / positions
	var target_step := roundi(_angle / step)
	var target := target_step * step

	if _snap_tween:
		_snap_tween.kill()
	_snap_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_method(_set_angle, _angle, target, snap_duration)
	await _snap_tween.finished

	current_index = wrapi(target_step, 0, positions)
	play_primary_se()   # click sound, optional
	dial_snapped.emit(current_index, get_current_symbol())


# Used if the player leaves mid-snap, so the dial never rests between stops
func _snap_immediately() -> void:
	var step := TAU / positions
	var target_step := roundi(_angle / step)
	_set_angle(target_step * step)
	current_index = wrapi(target_step, 0, positions)


func get_current_symbol() -> String:
	if current_index < symbols.size():
		return symbols[current_index]
	return str(current_index)
#endregion
