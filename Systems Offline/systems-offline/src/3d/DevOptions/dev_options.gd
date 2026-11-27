extends CanvasLayer

const SECTOR_3 := "res://src/3d/Scenes/rooms/Sector3.tscn"
const KEY_RESOURCES := [
	"res://src/3d/Resources/Tutorial_Key.tres",
	"res://src/3d/Resources/Multitool Key.tres",
]

@onready var _overlay: Control = %Overlay
@onready var _teleport: VBoxContainer = %TeleportCommands
@onready var _utils: VBoxContainer = %UtilsCommands
@onready var _animations: VBoxContainer = %AnimationsCommands
@onready var _search: LineEdit = %Search
@onready var _status: Label = %Status

var _was_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	_overlay.hide()
	if not OS.is_debug_build():
		set_process_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_close_menu)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or _overlay == null:
		return

	var is_space := key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE
	var is_close := _overlay.visible and key.keycode == KEY_ESCAPE
	if not is_space and not is_close:
		return

	get_viewport().set_input_as_handled()
	if key.echo:
		return

	if _overlay.visible:
		_close_menu()
	else:
		_open_menu()


func _on_search_changed(_text: String) -> void:
	if _overlay.visible:
		_refresh()


func _open_menu() -> void:
	_was_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_search.clear()
	_overlay.show()
	_refresh()
	_search.grab_focus()


func _close_menu() -> void:
	if not _overlay.visible:
		return

	_overlay.hide()
	get_tree().paused = _was_paused
	Input.mouse_mode = _previous_mouse_mode


func _refresh() -> void:
	for column in [_teleport, _utils, _animations]:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()

	var scene := get_tree().current_scene
	var player := _get_player()
	var location := str(player.global_position) if player != null else "No player"
	var scene_label := String(scene.name) if scene != null else "No scene"
	_status.text = "%s  |  Player: %s" % [scene_label, location]

	_add_command(_teleport, "Tutorial", _jump_to_spawn.bind("ROOM1_TUT"))
	_add_command(_teleport, "Room 1 Elevator", _jump_to_spawn.bind("ROOM1_ELEVATOR"))
	_add_command(_teleport, "Room 2 Elevator", _jump_to_spawn.bind("ROOM2_ELEVATOR"))
	_add_command(_teleport, "Engine Room", _jump_to_spawn.bind("ROOM2_ENGINE"))
	_add_command(_teleport, "Sector 3", _load_scene.bind(SECTOR_3))

	for node in get_tree().get_nodes_in_group("dev_teleport"):
		var marker := node as Marker3D
		if marker != null and scene != null and scene.is_ancestor_of(marker):
			_add_command(
				_teleport,
				String(marker.name).capitalize(),
				_jump_to_marker.bind(marker)
			)

	var solvers: Array[Dictionary] = []
	var doors: Array[Dictionary] = []
	if scene != null:
		_list_scene_commands(scene, scene, solvers, doors)

	_add_dropdown(_utils, "Solver", solvers)
	_add_dropdown(_utils, "Unlock Door", doors)

	var items: Array[Dictionary] = [
		{"label": "Grab All Keys", "action": _grab_all_keys},
		{"label": "Get Multitool", "action": _give_multitool},
	]
	_add_dropdown(_utils, "Items", items)

	_add_command(_utils, "Unlock All Quests", _unlock_all_quests)
	_add_command(_utils, "Copy Player Position", _copy_position)
	_add_command(_utils, "Restart Scene", _restart_scene)




func _get_solver_label(puzzle: Node) -> String:
	var script := puzzle.get_script() as Script
	if script != null:
		match script.resource_path.get_file().to_lower():
			"wires_elevator_puzzle.gd":
				return "Solve Elevator Wires"
			"wire_puzzle_comms.gd":
				return "Solve Comms Wires"
			"comms_puzzle.gd":
				return "Solve Comms Dials"
			"enginepuzzle3d.gd", "pipe_puzzle.gd":
				return "Solve Pipe Puzzle"
			"bird_matrix_puzzle.gd":
				return "Solve Bird Puzzle"
			"math_puzzle.gd":
				return "Solve Math Puzzle"

	return "Solve " + String(puzzle.name).capitalize()


func _solve_keypad(keypad: KeypadComponent) -> void:
	if not is_instance_valid(keypad) or keypad.fixed or keypad.is_finishing:
		return

	if keypad.is_transitioning or keypad.cover.is_interacting:
		_status.text = "Wait for the keypad or cover animation to finish."
		return

	if not is_instance_valid(keypad.player):
		_status.text = "The keypad has no player assigned."
		return

	_close_menu()

	# Bypass the cover requirement for this dev command.
	if not keypad.is_interacting:
		keypad.can_interact = true
		await keypad.enter_button_keypad()

	if not is_instance_valid(keypad) or not keypad.is_interacting:
		return

	keypad.entered_code = keypad.correct_code
	keypad.check_code()


func _solve_elevator_station(station: Node) -> void:
	if not is_instance_valid(station) or station.get("fixed"):
		return

	_close_menu()
	station.call_deferred("_on_puzzle_completed")


func _solve_puzzle(puzzle: Node) -> void:
	if not is_instance_valid(puzzle):
		return

	_close_menu()
	_apply_puzzle_solution.call_deferred(puzzle)


func _apply_puzzle_solution(puzzle: Node) -> void:
	if not is_instance_valid(puzzle):
		return

	if puzzle.has_method("debug_solve"):
		puzzle.call("debug_solve")
	elif puzzle.has_method("mark_solved"):
		if puzzle.get("can_interact"):
			puzzle.call("mark_solved")
	elif puzzle is DialPuzzle2D:
		var dial_puzzle := puzzle as DialPuzzle2D
		for dial in dial_puzzle.dials:
			dial.rotation_degrees = dial.letter_rotations[dial.correct_index]
		dial_puzzle.call("_on_check_pressed")
	elif puzzle is MathPuzzle2D:
		if not puzzle.get("is_solved"):
			puzzle.set("is_locked", false)
			puzzle.set("values", puzzle.get("solution").duplicate())
			puzzle.call("submit")
	elif puzzle.has_signal("puzzle_solved"):
		if not puzzle.get("solved"):
			puzzle.set("solved", true)
			var check_button := puzzle.get("check_button") as BaseButton
			if check_button != null:
				check_button.disabled = true
			puzzle.emit_signal("puzzle_solved")
	elif puzzle.has_signal("puzzle_completed"):
		if puzzle.has_method("check_puzzle_completion"):
			if puzzle.get("completed"):
				return
			puzzle.set("completed", true)
			puzzle.set("_exiting", true)
		elif puzzle.has_method("check_solution"):
			if puzzle.get("finished"):
				return
			puzzle.set("finished", true)
		puzzle.emit_signal("puzzle_completed")
	elif puzzle.has_signal("solved"):
		puzzle.emit_signal("solved")


func _unlock_door(door: UnlockableComponent) -> void:
	if not is_instance_valid(door):
		return

	_close_menu()
	door.call_deferred("unlock_door")


func _grab_all_keys() -> void:
	for path in KEY_RESOURCES:
		var key := load(path) as ItemData
		if key != null and not Inventory.has_item(key.item_id):
			Inventory.add_item(key)

	_status.text = "Tutorial Key and Multitool Key added to inventory."


func _give_multitool() -> void:
	var equipment := get_tree().get_first_node_in_group("multitool_equipment")
	if equipment == null or not equipment.has_method("collect_multitool"):
		_status.text = "The current player has no Multitool holder."
		return

	equipment.call("collect_multitool")
	if not SaveManager.is_multitool_part_complete("pickup_multitool"):
		SaveManager.complete_multitool_part("pickup_multitool")

	_status.text = "Multitool granted. Close the menu and press 1 to equip it."


func _unlock_all_quests() -> void:
	if not QuestManager.has_method("debug_unlock_all_quests"):
		_status.text = "QuestManager is missing debug_unlock_all_quests()."
		return

	QuestManager.call("debug_unlock_all_quests")
	_status.text = "All quests and objectives are visible in the journal."


func _jump_to_spawn(spawn_name: String) -> void:
	var script := SaveManager.get_script() as Script
	var constants := script.get_script_constant_map()
	var spawn_ids: Dictionary = constants.get("Spawn", {})
	var spawns: Dictionary = constants.get("SPAWNS", {})
	var spawn_id: int = spawn_ids.get(spawn_name, -1)
	if not spawns.has(spawn_id):
		_status.text = "Spawn unavailable: " + spawn_name
		return

	var spawn: Dictionary = spawns[spawn_id]
	var current := get_tree().current_scene
	var player := _get_player()
	_close_menu()

	if current != null and current.scene_file_path == spawn["scene"] and player != null:
		var target := Transform3D(
			Basis(Vector3.UP, deg_to_rad(float(spawn["yaw"]))),
			spawn["position"]
		)
		_move_player(player, target)
	else:
		SaveManager.call_deferred("change_room", spawn_id)


func _jump_to_marker(marker: Marker3D) -> void:
	var player := _get_player()
	if player == null or not is_instance_valid(marker):
		_status.text = "A player and a valid marker are required."
		return

	_close_menu()
	_move_player(player, marker.global_transform.orthonormalized())


func _move_player(player: CharacterBody3D, target: Transform3D) -> void:
	target.basis = target.basis.scaled_local(player.global_transform.basis.get_scale())
	player.global_transform = target
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _load_scene(path: String) -> void:
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_status.text = "Could not load scene: " + error_string(error)
		return

	_close_menu()


func _restart_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null and not scene.scene_file_path.is_empty():
		_load_scene(scene.scene_file_path)


func _play_animation(animator: AnimationPlayer, animation: StringName) -> void:
	if not is_instance_valid(animator) or not animator.has_animation(animation):
		return

	_close_menu()
	animator.stop()
	animator.play(animation)


func _copy_position() -> void:
	var player := _get_player()
	if player != null:
		DisplayServer.clipboard_set(str(player.global_position))
		_status.text = "Copied: %s" % str(player.global_position)


func _get_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _add_dropdown(
	column: VBoxContainer, title: String, entries: Array[Dictionary]
) -> void:
	var menu := MenuButton.new()
	menu.text = title + " ▾"
	menu.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var popup := menu.get_popup()
	var actions: Array[Callable] = []
	for entry in entries:
		var label: String = entry["label"]
		if _matches_search(title + " " + label):
			popup.add_item(label, actions.size())
			actions.append(entry["action"])

	if actions.is_empty():
		menu.free()
		return

	popup.window_input.connect(_on_dropdown_input.bind(popup))
	popup.id_pressed.connect(func(id: int) -> void: actions[id].call())
	column.add_child(menu)


func _on_dropdown_input(event: InputEvent, popup: PopupMenu) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or not is_menu_open():
		return

	var is_space := key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE
	if not is_space:
		return

	popup.set_input_as_handled()
	if key.echo:
		return

	popup.hide()
	_close_menu()


func is_menu_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible


func _list_scene_commands(
	scene: Node,
	node: Node,
	solvers: Array[Dictionary],
	doors: Array[Dictionary]
) -> void:
	if node is AnimationPlayer:
		var animator := node as AnimationPlayer
		for animation in animator.get_animation_list():
			var label := "Play " + String(animation).capitalize()
			if _matches_search(label):
				var button := _add_button(
					_animations, label, _play_animation.bind(animator, animation)
				)
				button.tooltip_text = str(scene.get_path_to(animator))

	if node is UnlockableComponent:
		var door := node as UnlockableComponent
		if door.unlockable_type == UnlockableComponent.UnlockableType.DOOR:
			var door_name := String(door.name).capitalize()
			if door_name == "Door" and door.get_parent() != null:
				door_name = String(door.get_parent().name).capitalize() + " Door"

			doors.append({
				"label": "Unlock " + door_name,
				"action": _unlock_door.bind(door),
			})

	if node is KeypadComponent:
		var keypad := node as KeypadComponent
		if not keypad.fixed and not keypad.correct_code.is_empty():
			solvers.append({
				"label": "Enter Keypad Code (" + keypad.correct_code + ")",
				"action": _solve_keypad.bind(keypad),
			})
	elif node is InspectComponent:
		var station := node as InspectComponent
		if station.puzzle_id == "elevator":
			if not station.fixed and not station.is_interacting:
				solvers.append({
					"label": "Solve Elevator Wires",
					"action": _solve_elevator_station.bind(station),
				})
		elif (
			station.puzzle_id == "comms"
			or station.puzzle_scene == "uid://lvydm5j7dvmt"
		):
			if not station.fixed and not SaveManager.is_puzzle_completed("comms"):
				solvers.append({
					"label": "Solve Comms Wires",
					"action": _solve_comms_station.bind(station),
				})
	elif (
		node.has_method("debug_solve")
		or node.has_method("mark_solved")
		or node.has_signal("solved")
		or node.has_signal("puzzle_solved")
		or node.has_signal("puzzle_completed")
	):
		solvers.append({
			"label": _get_solver_label(node),
			"action": _solve_puzzle.bind(node),
		})

	for child in node.get_children():
		_list_scene_commands(scene, child, solvers, doors)


func _solve_comms_station(station: InspectComponent) -> void:
	if not is_instance_valid(station) or station.fixed:
		return
	if SaveManager.is_puzzle_completed("comms"):
		return

	_close_menu()

	# The monitor checks this ID when deciding whether to power on.
	if station.puzzle_id.is_empty():
		station.puzzle_id = "comms"

	station.call_deferred("_on_puzzle_completed")


func _matches_search(label: String) -> bool:
	var query := _search.text.strip_edges().to_lower()
	return query.is_empty() or label.to_lower().contains(query)


func _add_command(column: VBoxContainer, label: String, action: Callable) -> void:
	if _matches_search(label):
		_add_button(column, label, action)


func _add_button(parent: Container, label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = label
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(action)
	parent.add_child(button)
	return button
