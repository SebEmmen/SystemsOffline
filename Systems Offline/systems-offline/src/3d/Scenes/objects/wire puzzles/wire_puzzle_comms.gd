extends Node3D

signal puzzle_completed
signal puzzle_exited

# Key = WireSocket, Value = PuzzleWire (or null if empty)
var socket_state_map := {}
var completed: bool = false
var _exiting: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	initialize_puzzle_tracking()


## True only for nodes that live in the same viewport as this puzzle.
func _in_this_puzzle(node: Node) -> bool:
	return node.get_viewport() == get_viewport()


func initialize_puzzle_tracking() -> void:
	for node in get_tree().get_nodes_in_group("wire_sockets"):
		if node is WireSocket and _in_this_puzzle(node):
			socket_state_map[node] = null

	for node in get_tree().get_nodes_in_group("puzzle_wires"):
		if node is PuzzleWire and _in_this_puzzle(node):
			node.wire_connected.connect(_on_wire_connected.bind(node))
			node.wire_disconnected.connect(_on_wire_disconnected.bind(node))

	print("Puzzle tracking initialized. Total sockets tracked: ", socket_state_map.size())


func _on_wire_connected(_socket: WireSocket, _wire: PuzzleWire) -> void:
	check_puzzle_completion()


# The bound wire arrives as the only argument.
func _on_wire_disconnected(_wire: PuzzleWire) -> void:
	check_puzzle_completion()


## Rebuilds the map from the wires themselves (the source of truth).
func _rebuild_socket_map() -> void:
	for socket in socket_state_map.keys():
		socket_state_map[socket] = null

	for node in get_tree().get_nodes_in_group("puzzle_wires"):
		if node is PuzzleWire and _in_this_puzzle(node) and node.is_plugged and node.connected_socket != null:
			socket_state_map[node.connected_socket] = node


func _is_puzzle_correct() -> bool:
	_rebuild_socket_map()
	if socket_state_map.is_empty():
		return false

	for socket in socket_state_map.keys():
		var wire: PuzzleWire = socket_state_map[socket]
		if wire == null or wire.correct_socket_id != socket.socket_id:
			return false
	return true


func check_puzzle_completion() -> void:
	if completed or not _is_puzzle_correct():
		return

	completed = true
	await get_tree().create_timer(1.0).timeout

	# The player may have unplugged a wire during the delay
	if not _is_puzzle_correct():
		completed = false
		return

	print("completion check passed, emitting")
	_exiting = true
	puzzle_completed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _exiting:
		return
	# Esc is already handled by InspectComponent, so only listen for interact here
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_exit_puzzle()


func _exit_puzzle() -> void:
	if _exiting:
		return
	_exiting = true
	puzzle_exited.emit()
