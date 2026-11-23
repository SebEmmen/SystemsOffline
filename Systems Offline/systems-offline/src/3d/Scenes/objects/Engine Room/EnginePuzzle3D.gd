extends Node3D

@onready var grid_spots = [
	$"Grid 1x2", $"Grid 2x2", $"Grid 2x3", $"Grid 3x1", $"Grid 3x3", $"Grid 4x2", $"Grid 4x3"
]

@onready var moves_remaining_label := $Label3D
@onready var buttons = [$Button, $Button2]
@onready var reset_button = $Reset

@export var max_moves := 5
@export var rotate_time := 0.7
@export var reset_time := 0.9
@export var reset_delay := 0.5

var moves_remaining := 0
var busy := false
var initial_rotations := []
var initial_button_rotations := []

func _ready() -> void:
	for g in grid_spots:
		initial_rotations.append(g.rotation_degrees.y)
	for b in buttons:
		initial_button_rotations.append(b.rotation_degrees.y)
	moves_remaining = max_moves
	update_moves_label()

	# Connect the 3D buttons (each has the pressed-signal script on its Area3D)
	$Button/Area3D.pressed.connect(_on_button_pressed_a)
	$Button2/Area3D.pressed.connect(_on_button_pressed_b)
	$Reset/Area3D.pressed.connect(_on_reset_button_pressed)

func update_moves_label() -> void:
	moves_remaining_label.text = "Button presses remaining: " + str(moves_remaining)

func set_busy(value: bool) -> void:
	busy = value
	Piece3D.locked = value
	_update_buttons()

func _update_buttons() -> void:
	var dim := busy or moves_remaining <= 0
	for b in buttons:
		b.get_node("Area3D").disabled = busy
		_dim_meshes(b, dim)
	reset_button.get_node("Area3D").disabled = busy
	_dim_meshes(reset_button, busy)

func _dim_meshes(root: Node, dim: bool) -> void:
	for m in root.find_children("*", "GeometryInstance3D", true, false):
		m.transparency = 0.5 if dim else 0.0

func do_move(rotations: Array, button: Node3D, button_degrees: float) -> void:
	if busy:
		return

	if moves_remaining <= 0:
		set_busy(true)
		await reset_board()
		set_busy(false)
		return

	set_busy(true)
	moves_remaining -= 1
	update_moves_label()

	var tw := create_tween().set_parallel(true)
	for r in rotations:
		var node: Node3D = grid_spots[r[0] - 1]
		tw.tween_property(node, "rotation_degrees:y",
			node.rotation_degrees.y + r[1], rotate_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(button, "rotation_degrees:y",
		button.rotation_degrees.y + button_degrees, rotate_time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	set_busy(false)

func reset_board() -> void:
	var pieces := get_tree().get_nodes_in_group("pieces")
	for p in pieces:
		p.release()

	var tw := create_tween().set_parallel(true)
	for i in grid_spots.size():
		var g: Node3D = grid_spots[i]
		var diff := wrapf(initial_rotations[i] - g.rotation_degrees.y, -180.0, 180.0)
		tw.tween_property(g, "rotation_degrees:y",
			g.rotation_degrees.y + diff, reset_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in buttons.size():
		var b: Node3D = buttons[i]
		var diff := wrapf(initial_button_rotations[i] - b.rotation_degrees.y, -180.0, 180.0)
		tw.tween_property(b, "rotation_degrees:y",
			b.rotation_degrees.y + diff, reset_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for p in pieces:
		p.return_to_start(reset_time)

	await tw.finished
	for i in grid_spots.size():
		grid_spots[i].rotation_degrees.y = initial_rotations[i]
	for i in buttons.size():
		buttons[i].rotation_degrees.y = initial_button_rotations[i]
	moves_remaining = max_moves
	update_moves_label()

# $Button = old Button2, $Button2 = old Button3. Swap the bodies if they feel backwards.
func _on_button_pressed_a() -> void:
	do_move([[3, 90], [6, 90]], $Button, 90)

func _on_button_pressed_b() -> void:
	do_move([[1, -90], [7, -90]], $Button2, -90)

func _on_reset_button_pressed() -> void:
	if busy:
		return
	set_busy(true)
	await reset_board()
	set_busy(false)
