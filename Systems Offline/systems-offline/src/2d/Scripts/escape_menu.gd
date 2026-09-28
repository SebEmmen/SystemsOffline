extends Control

@onready var ui_manager: UI_Manager = get_parent()

func _on_resume_button_pressed() -> void:
	ui_manager.close_menu()

func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/2d/Scenes/MainMenu.tscn")
