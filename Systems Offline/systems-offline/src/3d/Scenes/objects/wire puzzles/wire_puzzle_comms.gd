extends Node3D

# Dictionary to track state: Key = WireSocket, Value = PuzzleWire (or null if empty)
var socket_state_map := {}
func _ready() -> void:
	# Ensure the mouse is visible for the puzzle UI
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Initialize tracking for sockets and wires
	initialize_puzzle_tracking()

func initialize_puzzle_tracking() -> void:
	# 1. Register all sockets as initially empty (null)
	for node in get_tree().get_nodes_in_group("wire_sockets"):
		if node is WireSocket:
			socket_state_map[node] = null

	# 2. Listen for connection/disconnection signals from all wires
	for node in get_tree().get_nodes_in_group("puzzle_wires"):
		if node is PuzzleWire:
			# Bind the wire reference so we know exactly which wire connected
			node.wire_connected.connect(_on_wire_connected.bind(node))
			node.wire_disconnected.connect(_on_wire_disconnected.bind(node))
			
	print("Puzzle tracking initialized. Total sockets tracked: ", socket_state_map.size())

# Triggered when a wire successfully snaps to a socket
func _on_wire_connected(socket: WireSocket, wire: PuzzleWire) -> void:
	socket_state_map[socket] = wire
	print("Socket [ID: ", socket.socket_id, "] connected to Wire [Correct ID: ", wire.correct_socket_id, "]")
	
	check_puzzle_completion()

# Triggered when any wire is unplugged
func _on_wire_disconnected() -> void:
	# Refresh the map by checking which sockets are currently unoccupied
	for socket in socket_state_map.keys():
		if not socket.occupied:
			socket_state_map[socket] = null
			
	print("A wire was unplugged. Re-evaluating connections...")
	check_puzzle_completion()

func check_puzzle_completion() -> void:
	var all_correct = true
	
	# Check every tracked socket
	for socket in socket_state_map.keys():
		var plugged_wire = socket_state_map[socket]
		
		# A socket is valid only if it has a wire AND that wire's ID matches the socket's ID
		if plugged_wire == null or plugged_wire.correct_socket_id != socket.socket_id:
			all_correct = false
			break

	# If all sockets are correctly filled, the puzzle is solved!
	if all_correct and socket_state_map.size() > 0:
		print("SUCCESS: All sockets correctly connected!")
		
		# 1. Save progress globally via SaveManager
		SaveManager.wire_puzzle_solved = true
		SaveManager.save_game() # Optional: saves the puzzle state to disk
		
		# 2. Short delay so the player can see the final connected state
		await get_tree().create_timer(1.0).timeout
		
		# 3. Reset mouse capture for your 3D room
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		# 4. Dynamically grab the room we came from, with Room1 as a safety fallback
		var return_scene = SaveManager.save_data.get("previous_scene", "res://src/3d/Scenes/rooms/Room1.tscn")
		
		# 5. Switch back to the exact room you were standing in
		#get_tree().change_scene_to_file(return_scene)
		SaveManager.load_game()
#func _unhandled_input(event: InputEvent) -> void:
	#if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		#SaveManager.load_game()
		#return
