extends Node

const SAVE_PATH = "user://savegame.json"
const START_SCENE = "res://src/3d/Scenes/rooms/Room1.tscn"

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
		"player": player.get_save_data()
	}
	print(save_data)


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

	var scene_path: String = save_data["scene"]

	# Load the saved room
	var error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("SaveManager: Could not load saved scene!")
		return

	# Wait until the new scene is ready
	await get_tree().scene_changed

	var player = get_player()

	if player == null:
		push_error("SaveManager: Player not found after loading!")
		return

	# Restore player state
	player.load_save_data(save_data["player"])

	print("Game loaded!")


func new_game() -> void:
	# Clear previous save data
	save_data.clear()

	var error = get_tree().change_scene_to_file(START_SCENE)

	if error != OK:
		push_error("SaveManager: Could not start new game!")
		return

	await get_tree().scene_changed

	# Create a new save using the starting state
	save_game()
