extends Node3D

# Key = WireSocket, Value = PuzzleWire (or null if empty)
var socket_state_map := {}
var completed: bool = false
var _exiting: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	initialize_puzzle_tracking()


func initialize_puzzle_tracking() -> void:
	for node in get_tree().get_nodes_in_group("wire_sockets"):
		if node is WireSocket:
			socket_state_map[node] = null

	for node in get_tree().get_nodes_in_group("puzzle_wires"):
		if node is PuzzleWire:
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
		if node is PuzzleWire and node.is_plugged and node.connected_socket != null:
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
	print("SUCCESS: All sockets correctly connected!")

	# Short delay so the player can see the final connected state
	await get_tree().create_timer(1.0).timeout

	# The player may have unplugged a wire during the delay
	if not _is_puzzle_correct():
		completed = false
		return

	SaveManager.wire_puzzle_completed = true
	_exit_puzzle()
	print("Exited to main room")
	

func _unhandled_input(event: InputEvent) -> void:
	if _exiting:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_exit_puzzle()


func _exit_puzzle() -> void:
	if _exiting:
		return
	_exiting = true
	print("exit_puzzle called from scene: ", get_tree().current_scene.name, " node: ", get_path())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SaveManager.return_from_subscene()
	
