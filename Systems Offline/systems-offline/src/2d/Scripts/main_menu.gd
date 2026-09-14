#extends MarginContainer


extends Control

func _on_continue_pressed():
	get_tree().change_scene_to_file("res://src/3d/Scenes/rooms/Room1.tscn")

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://src/3d/Scenes/rooms/Room1.tscn")

#func _on_options_pressed():
	## Load or open options menu overlay/scene
	#get_tree().change_scene_to_file("res://src/2d/Scenes/OptionsMenu.tscn")
