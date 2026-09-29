extends Control

@onready var continue_button: TextureButton = $HBoxContainer/VBoxContainer/VBoxContainer/Continue

func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save()


func _on_continue_pressed() -> void:
	SaveManager.load_game()


func _on_new_game_pressed() -> void:
	SaveManager.new_game()


func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://src/2d/Scenes/OptionsMenu.tscn")
