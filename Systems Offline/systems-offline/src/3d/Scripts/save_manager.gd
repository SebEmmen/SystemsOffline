extends Node

const SAVE_PATH = "user://savegame.json"
const START_SCENE = "res://src/3d/Scenes/rooms/Room1.tscn"
const SETTINGS_FILE = "user://settings.json"
const DEFAULT_FOV := 75.0

var return_scene: String = ""

#region Multitool Progress
var multitool: Dictionary = {}
#endregion

#region Comms Puzzles
#Dial Puzzle
var dial_puzzle_completed: bool = false

# Wires
var current_puzzle_id: String = ""
# id -> { completed, cover_removed, cover_pos, cover_rot }
var puzzles: Dictionary = {}
#endregion

#region Tutorial Puzzle
var tutorial_puzzle_completed: bool = false
# Keypad

# Key
#endregion


var in_subscene = false

var return_player_state: Dictionary = {}
# Call this before leaving the room for a sub-scene (puzzle)
var save_data: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func get_player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func save_game() -> void:
	var player = get_player()

	if player == null:
		push_error("SaveManager: Player not found!")
		return

	save_data = {
		"scene": get_tree().current_scene.scene_file_path,
		"player": player.get_save_data(),
		"tutorial_puzzle_completed": tutorial_puzzle_completed,
		"dial_puzzle_completed": dial_puzzle_completed,
		"puzzles": _puzzles_to_json(),
		"multitool": _multitool_to_json()
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("SaveManager: Could not create save file!")
		return

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()

	print("Game saved!")


func load_game() -> void:
	if not has_save():
		print("No save file found!")
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		push_error("SaveManager: Could not open save file!")
		return

	var loaded_data = JSON.parse_string(file.get_as_text())
	file.close()

	if not loaded_data is Dictionary:
		push_error("SaveManager: Invalid save file!")
		return

	if not loaded_data.has("scene") or not loaded_data.has("player"):
		push_error("SaveManager: Missing save data!")
		return

	save_data = loaded_data

	tutorial_puzzle_completed = save_data.get("tutorial_puzzle_completed", false)
	dial_puzzle_completed = save_data.get("dial_puzzle_completed", false)
	_puzzles_from_json(save_data.get("puzzles", {}))
	_multitool_from_json(save_data.get("multitool", {}))

	var error = get_tree().change_scene_to_file(save_data["scene"])

	if error != OK:
		push_error("SaveManager: Could not load saved scene!")
		return

	await get_tree().scene_changed

	var player = get_player()

	if player == null:
		push_error("SaveManager: Player not found after loading!")
		return

	player.load_save_data(save_data["player"])

	print("Game loaded!")
	print("Loaded tutorial flag: ", tutorial_puzzle_completed, " raw: ", save_data.get("tutorial_puzzle_completed"))


func _puzzles_to_json() -> Dictionary:
	var out := {}
	for id in puzzles:
		var p: Dictionary = puzzles[id]
		out[id] = {
			"completed": p["completed"],
			"cover_removed": p["cover_removed"],
			"cover_pos": [p["cover_pos"].x, p["cover_pos"].y, p["cover_pos"].z],
			"cover_rot": [p["cover_rot"].x, p["cover_rot"].y, p["cover_rot"].z],
		}
	return out

func _puzzles_from_json(data: Dictionary) -> void:
	puzzles.clear()
	for id in data:
		var d: Dictionary = data[id]
		var pos: Array = d.get("cover_pos", [0, 0, 0])
		var rot: Array = d.get("cover_rot", [0, 0, 0])
		puzzles[id] = {
			"completed": d.get("completed", false),
			"cover_removed": d.get("cover_removed", false),
			"cover_pos": Vector3(pos[0], pos[1], pos[2]),
			"cover_rot": Vector3(rot[0], rot[1], rot[2]),
		}
		
func _multitool_to_json() -> Dictionary:
	var out := {}
	for id in multitool:
		var m: Dictionary = multitool[id]
		out[id] = {
			"completed": m["completed"]
		}
	return out

func _multitool_from_json(data: Dictionary) -> void:
	multitool.clear()
	for id in data:
		var d: Dictionary = data[id]
		multitool[id] = {
			"completed": d.get("completed", false)
		}

func enter_subscene(scene_path: String, puzzle_id: String, cover: RigidBody3D = null) -> void:
	var player = get_player()
	if player == null:
		push_error("SaveManager: Player not found!")
		return

	current_puzzle_id = puzzle_id
	if cover != null:
		set_cover_transform(puzzle_id, cover.global_transform)

	return_scene = get_tree().current_scene.scene_file_path
	return_player_state = player.get_save_data()
	in_subscene = true
	get_tree().change_scene_to_file(scene_path)


func return_from_subscene() -> void:
	if return_scene == "":
		push_error("SaveManager: No scene to return to!")
		return

	var error = get_tree().change_scene_to_file(return_scene)

	if error != OK:
		push_error("SaveManager: Could not return to scene!")
		return

	await get_tree().scene_changed

	var player = get_player()

	if player == null:
		push_error("SaveManager: Player not found after returning!")
		return

	player.load_save_data(return_player_state)

	# Persist to disk only now, with everything up to date
	save_game()


func reset_progress() -> void:
	save_data.clear()

	tutorial_puzzle_completed = false
	dial_puzzle_completed = false

	puzzles.clear()
	multitool.clear()

	current_puzzle_id = ""
	return_scene = ""
	return_player_state = {}
	in_subscene = false

func _reset_fov_setting() -> void:
	var data := {}
	if FileAccess.file_exists(SETTINGS_FILE):
		var f = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				data = parsed

	data["fov"] = DEFAULT_FOV

	var out = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(data, "\t"))
		out.close()

func new_game() -> void:
	reset_progress()
	_reset_fov_setting()  

	var error = get_tree().change_scene_to_file(START_SCENE)

	if error != OK:
		push_error("SaveManager: Could not start new game!")
		return

	await get_tree().scene_changed

	# Give the new scene's nodes a frame to finish _ready()
	await get_tree().process_frame

	save_game()

#region Multitool Progress
func _multitool(id: String) -> Dictionary:
	if not multitool.has(id):
		multitool[id] = {
			"completed": false,
		}
	return multitool[id]

func is_multitool_part_complete(id: String) -> bool:
	return _multitool(id)["completed"]

func complete_multitool_part(id: String) -> void:
	var m := _multitool(id)
	m["completed"] = true
#endregion


#region Puzzle state
func _puzzle(id: String) -> Dictionary:
	if not puzzles.has(id):
		puzzles[id] = {
			"completed": false,
			"cover_removed": false,
			"cover_pos": Vector3.ZERO,
			"cover_rot": Vector3.ZERO,
		}
	return puzzles[id]

func is_puzzle_completed(id: String) -> bool:
	return _puzzle(id)["completed"]

func complete_puzzle(id: String) -> void:
	var p := _puzzle(id)
	p["completed"] = true
	p["cover_removed"] = false

func is_cover_removed(id: String) -> bool:
	return _puzzle(id)["cover_removed"]

func set_cover_transform(id: String, t: Transform3D) -> void:
	var p := _puzzle(id)
	p["cover_removed"] = true
	p["cover_pos"] = t.origin
	p["cover_rot"] = t.basis.orthonormalized().get_euler()

func get_cover_transform(id: String) -> Transform3D:
	var p := _puzzle(id)
	return Transform3D(Basis.from_euler(p["cover_rot"]), p["cover_pos"])
#endregion
