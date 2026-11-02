extends Node

const SAVE_PATH = "user://savegame.json"
const START_SCENE = "res://src/3d/Scenes/rooms/Room1.tscn"

var wire_puzzle_completed: bool = false
var return_scene: String = ""
var wire_cover_removed: bool = false
var wire_cover_transform: Transform3D = Transform3D.IDENTITY
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
		"wire_puzzle_completed": wire_puzzle_completed,
		"wire_cover": {
			"removed": wire_cover_removed,
			"position": [wire_cover_transform.origin.x, wire_cover_transform.origin.y, wire_cover_transform.origin.z],
			"rotation": [wire_cover_transform.basis.get_euler().x, wire_cover_transform.basis.get_euler().y, wire_cover_transform.basis.get_euler().z]
		}
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

	
	wire_puzzle_completed = save_data.get("wire_puzzle_completed", false)

	var cover_data: Dictionary = save_data.get("wire_cover", {})
	wire_cover_removed = cover_data.get("removed", false)
	if wire_cover_removed:
		var p: Array = cover_data.get("position", [0, 0, 0])
		var r: Array = cover_data.get("rotation", [0, 0, 0])
		wire_cover_transform = Transform3D(
			Basis.from_euler(Vector3(r[0], r[1], r[2])),
			Vector3(p[0], p[1], p[2])
		)

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




func enter_subscene(scene_path: String, cover: RigidBody3D = null) -> void:
	var player = get_player()
	if player == null:
		push_error("SaveManager: Player not found!")
		return

	if cover != null:
		wire_cover_removed = true
		wire_cover_transform = cover.global_transform

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


func new_game() -> void:
	save_data.clear()
	wire_puzzle_completed = false

	var error = get_tree().change_scene_to_file(START_SCENE)

	if error != OK:
		push_error("SaveManager: Could not start new game!")
		return

	await get_tree().scene_changed

	save_game()
