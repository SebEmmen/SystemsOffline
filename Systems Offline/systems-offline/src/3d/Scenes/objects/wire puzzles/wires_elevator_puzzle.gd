extends Node3D

var completed := false
var _exiting := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	for node in get_tree().get_nodes_in_group("puzzle_bridges"):
		if node is PuzzleBridge:
			node.bridge_connected.connect(_on_bridge_connected)
			node.bridge_disconnected.connect(check_puzzle_completion)

	print("Tracking bridges: ", get_tree().get_nodes_in_group("puzzle_bridges").size())


func _on_bridge_connected(_a: WireSocket, _b: WireSocket) -> void:
	check_puzzle_completion()


func _is_puzzle_correct() -> bool:
	var bridges := get_tree().get_nodes_in_group("puzzle_bridges")
	if bridges.is_empty():
		return false
	for bridge in bridges:
		if not (bridge is PuzzleBridge and bridge.is_connected):
			return false
	return true


func check_puzzle_completion() -> void:
	if completed or not _is_puzzle_correct():
		return

	completed = true
	print("SUCCESS: All bridges connected!")

	# Let the player see the core light animation finish
	await get_tree().create_timer(1.0).timeout

	# The player may have unplugged a bridge during the delay
	if not _is_puzzle_correct():
		completed = false
		return

	SaveManager.complete_puzzle(SaveManager.current_puzzle_id)
	_exit_puzzle()


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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SaveManager.return_from_subscene()
