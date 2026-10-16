#extends MarginContainer
extends Control

@onready var continue_button: TextureButton = $HBoxContainer/VBoxContainer/VBoxContainer/Continue

func _ready() -> void:
	continue_button.disabled = not SaveManager.has_save()

func _on_continue_pressed():
	# Replace with your save file loading logic or main game scene path
	SaveManager.load_game()

func _on_new_game_pressed():
	# Load a fresh game scene
	SaveManager.new_game()

func _on_options_pressed():
	# Load or open options menu overlay/scene
	get_tree().change_scene_to_file("res://src/2d/Scenes/OptionsMenu.tscn")
