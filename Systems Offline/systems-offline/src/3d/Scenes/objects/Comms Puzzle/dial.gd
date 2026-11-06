class_name Dial2D
extends TextureRect
## Drag to rotate, snaps to the closest rotation in `letter_rotations`.

signal dial_turned(angle_degrees: float)
signal dial_snapped(index: int)

## Dial rotation (in degrees) at which each letter sits in the window.
## Entry 0 = letter 0, entry 1 = letter 1, etc. Edit per dial in the inspector.
@export var letter_rotations: Array[float] = [0.0, 72.0, 144.0, 216.0, 288.0]
## Which entry of letter_rotations is the correct one.
@export var correct_index: int = 0
@export var snap_duration: float = 0.2
@export var click_sound: AudioStreamPlayer
## 0 = auto (radius of the dial)
@export var grab_radius_px: float = 0.0

@export_group("Debug")
@export var debug_always_active := false
@export var debug_print := false

var can_turn := false
var current_index := 0

var _dragging := false
var _last_mouse_angle := 0.0
var _tween: Tween




func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	can_turn = debug_always_active
	current_index = _closest_index()   # editor rotation decides the start letter
	rotation_degrees = letter_rotations[current_index]


func _input(event: InputEvent) -> void:
	if not can_turn:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _on_dial(event.position):
			if _tween:
				_tween.kill()
			_dragging = true
			_last_mouse_angle = _angle_to(event.position)
			if debug_print: print(name, ": grabbed")
		elif not event.pressed and _dragging:
			_dragging = false
			_snap()

	elif event is InputEventMouseMotion and _dragging:
		var a := _angle_to(event.position)
		rotation += wrapf(a - _last_mouse_angle, -PI, PI)
		_last_mouse_angle = a
		dial_turned.emit(rotation_degrees)


func _center() -> Vector2:
	return get_global_transform() * (size / 2.0)


func _angle_to(p: Vector2) -> float:
	return (p - _center()).angle()


func _on_dial(p: Vector2) -> bool:
	var r := grab_radius_px
	if r <= 0.0:
		r = minf(size.x, size.y) / 2.0 * get_global_transform().get_scale().x
	return p.distance_to(_center()) <= r


## Index of the letter_rotations entry nearest the current rotation.
func _closest_index() -> int:
	var best := 0
	var best_diff := INF
	for i in letter_rotations.size():
		var d := absf(wrapf(deg_to_rad(letter_rotations[i]) - rotation, -PI, PI))
		if d < best_diff:
			best_diff = d
			best = i
	return best


func _snap() -> void:
	current_index = _closest_index()
	# shortest way round to the target
	var diff := wrapf(deg_to_rad(letter_rotations[current_index]) - rotation, -PI, PI)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation", rotation + diff, snap_duration)
	await _tween.finished
	if click_sound:
		click_sound.play()
	if debug_print: print(name, ": snapped to ", current_index)
	dial_snapped.emit(current_index)


func stop_and_snap() -> void:
	_dragging = false
	if _tween:
		_tween.kill()
	current_index = _closest_index()
	rotation_degrees = letter_rotations[current_index]


func is_correct() -> bool:
	return current_index == correct_index
