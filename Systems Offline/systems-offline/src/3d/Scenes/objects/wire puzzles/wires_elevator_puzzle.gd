extends Node3D

signal puzzle_completed
signal puzzle_exited

var completed := false
var _exiting := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for node in _my_nodes("puzzle_bridges"):
		if node is PuzzleBridge:
			node.bridge_connected.connect(_on_bridge_connected)
			node.bridge_disconnected.connect(check_puzzle_completion)

	for node in _my_nodes("puzzle_wires"):
		if node is PuzzleWire:
			node.wire_connected.connect(_on_wire_connected)
			node.wire_disconnected.connect(check_puzzle_completion)

	print("Bridges: ", _my_nodes("puzzle_bridges").size(),
		" Wires: ", _my_nodes("puzzle_wires").size())


## Group members that live in the same viewport as this puzzle.
func _my_nodes(group: StringName) -> Array:
	return get_tree().get_nodes_in_group(group).filter(
		func(n): return n.get_viewport() == get_viewport()
	)


func _on_bridge_connected(_a: WireSocket, _b: WireSocket) -> void:
	check_puzzle_completion()


func _on_wire_connected(_socket: WireSocket) -> void:
	check_puzzle_completion()


func _is_puzzle_correct() -> bool:
	var bridges := _my_nodes("puzzle_bridges")
	var wires := _my_nodes("puzzle_wires")
	if bridges.is_empty() and wires.is_empty():
		return false

	for bridge in bridges:
		if not (bridge is PuzzleBridge and bridge.is_bridged):
			return false

	for wire in wires:
		if not (wire is PuzzleWire and wire.is_plugged):
			return false
		if wire.connected_socket == null \
				or wire.connected_socket.socket_id != wire.correct_socket_id:
			return false

	return true


func check_puzzle_completion() -> void:
	if completed or not _is_puzzle_correct():
		return

	completed = true
	await get_tree().create_timer(1.0).timeout

	# The player may have unplugged something during the delay
	if not _is_puzzle_correct():
		completed = false
		return

	print("elevator completion check passed, emitting")
	_exiting = true
	puzzle_completed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _exiting:
		return
	# Esc is handled by InspectComponent, so only listen for interact here
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_exit_puzzle()


func _exit_puzzle() -> void:
	if _exiting:
		return
	_exiting = true
	puzzle_exited.emit()
