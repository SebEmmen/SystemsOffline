extends Node2D

@onready var grid_spots = [
	$"Grid 1x2", $"Grid 2x2", $"Grid 2x3", $"Grid 3x1",
	$"Grid 3x2", $"Grid 3x3", $"Grid 4x2", $"Grid 4x3"
]
@onready var moves_remaining_label := $Label
@onready var buttons = [$Button2, $Button3]

@export var max_moves := 5
@export var rotate_time := 0.7      # seconds per rotation
@export var reset_time := 0.9       # seconds for the reset animation
@export var reset_delay := 0.5      # pause before resetting

var moves_remaining := 0
var busy := false
var initial_rotations := []

func _ready() -> void:
	for g in grid_spots:
		initial_rotations.append(g.rotation_degrees)
	moves_remaining = max_moves
	update_moves_label()

func update_moves_label() -> void:
	moves_remaining_label.text = "Button presses remaining: " + str(moves_remaining)

func set_busy(value: bool) -> void:
	busy = value
	Piece.locked = value
	_update_buttons()

func _update_buttons() -> void:
	# dim while animating, or when out of moves (pieces can still be dragged)
	var dim := busy or moves_remaining <= 0
	for b in buttons:
		if b == null:
			continue
		b.modulate.a = 0.5 if dim else 1.0
		for c in b.find_children("*", "BaseButton", true, false):
			c.disabled = busy   # only truly disabled during animations

# each entry: [slot number (1-based), degrees]
func do_move(rotations: Array) -> void:
	if busy:
		return

	# out of moves: this press resets the board instead
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
		var node: Node2D = grid_spots[r[0] - 1]
		tw.tween_property(node, "rotation_degrees", node.rotation_degrees + r[1], rotate_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	set_busy(false)   # unlocks pieces again, even at 0 moves

func reset_board() -> void:
	var pieces := get_tree().get_nodes_in_group("pieces")
	# free every slot first so pieces can't block each other
	for p in pieces:
		p.release()

	var tw := create_tween().set_parallel(true)
	for i in grid_spots.size():
		var g: Node2D = grid_spots[i]
		# shortest path back to the starting angle (no multi-spin unwinding)
		var diff := wrapf(initial_rotations[i] - g.rotation_degrees, -180.0, 180.0)
		tw.tween_property(g, "rotation_degrees", g.rotation_degrees + diff, reset_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for p in pieces:
		p.return_to_start(reset_time)

	await tw.finished
	# snap grids to their exact starting angles to avoid float drift
	for i in grid_spots.size():
		grid_spots[i].rotation_degrees = initial_rotations[i]
	moves_remaining = max_moves
	update_moves_label()


func _on_button_pressed2() -> void:
	do_move([[3, 90], [7, 90]])

func _on_button_pressed3() -> void:
	do_move([[1, -90], [8, -90]])
