class_name Dial2D
extends TextureRect

signal dial_turned(angle_degrees: float)
signal dial_snapped(index: int, symbol: String)

@export var positions: int = 5
@export var symbols: Array[String] = []
@export var snap_duration: float = 0.2
@export var turn_sensitivity: float = 1.0
## Click must land within this many viewport pixels of the dial center (0 = anywhere)
@export var grab_radius_px: float = 150.0
@export var click_sound: AudioStreamPlayer

@export_group("Debug")
@export var debug_always_active := false

var can_turn := false
var current_index: int = 0

var _dragging := false
var _last_mouse_angle := 0.0
var _angle := 0.0          # radians, relative to the resting rotation
var _rest_rotation := 0.0  # rotation set in the editor
var _mouse_pos := Vector2.ZERO
var _snap_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0
	_rest_rotation = rotation
	can_turn = debug_always_active


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse_pos = event.position   # keep tracking even when inactive

	if not can_turn or SaveManager.dial_puzzle_completed:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _mouse_on_dial():
				if _snap_tween:
					_snap_tween.kill()
				_dragging = true
				_last_mouse_angle = _get_mouse_angle()
		elif _dragging:
			_dragging = false
			_snap()

	elif event is InputEventMouseMotion and _dragging:
		var current := _get_mouse_angle()
		var delta := wrapf(current - _last_mouse_angle, -PI, PI) * turn_sensitivity
		_last_mouse_angle = current
		_set_angle(_angle + delta)
		dial_turned.emit(rad_to_deg(_angle))


func _get_center() -> Vector2:
	return get_global_rect().get_center()


func _get_mouse_angle() -> float:
	return (_mouse_pos - _get_center()).angle()


func _mouse_on_dial() -> bool:
	if grab_radius_px <= 0.0:
		return true
	return _mouse_pos.distance_to(_get_center()) <= grab_radius_px


func _set_angle(a: float) -> void:
	_angle = a
	rotation = _rest_rotation + a


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
	if click_sound:
		click_sound.play()
	dial_snapped.emit(current_index, get_current_symbol())


func _snap_immediately() -> void:
	var step := TAU / positions
	var target_step := roundi(_angle / step)
	_set_angle(target_step * step)
	current_index = wrapi(target_step, 0, positions)


func stop_and_snap() -> void:
	_dragging = false
	if _snap_tween:
		_snap_tween.kill()
	_snap_immediately()


func get_current_symbol() -> String:
	if current_index < symbols.size():
		return symbols[current_index]
	return str(current_index)
