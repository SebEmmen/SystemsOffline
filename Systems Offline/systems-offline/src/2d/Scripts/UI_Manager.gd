class_name UI_Manager
extends CanvasLayer

enum Menu {
	NONE,
	PAUSE,
	INVENTORY
}

@onready var pause_menu: Control = $PauseMenu
@onready var inventory_ui: Control = $InventoryUI

@export var player: CharacterBody3D

var current_menu: Menu = Menu.NONE
	

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false
	inventory_ui.visible = false


func _get_player() -> CharacterBody3D:
	if player:
		return player
	return get_tree().get_first_node_in_group("player") as CharacterBody3D


func _unhandled_input(event: InputEvent) -> void:
	# ESCAPE
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		match current_menu:
			Menu.NONE:
				open_menu(Menu.PAUSE)

			Menu.PAUSE:
				if pause_menu and pause_menu.has_method("handle_cancel") and pause_menu.handle_cancel():
					return
				close_menu()

			Menu.INVENTORY:
				close_menu()

	# TAB
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		match current_menu:
			Menu.NONE:
				open_menu(Menu.INVENTORY)
				if Inventory.tutorial > 1:
					Notification.show_message("You can right click on objects to inspect them!", false)

			Menu.INVENTORY:
				close_menu()

			Menu.PAUSE:
				# Do nothing while paused
				pass


func open_menu(menu: Menu) -> void:
	current_menu = menu

	match menu:
		Menu.PAUSE:
			pause_menu.visible = true
			inventory_ui.visible = false

		Menu.INVENTORY:
			inventory_ui.visible = true
			pause_menu.visible = false

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var p = _get_player()
	if p and p.has_method("release_mouse"):
		p.release_mouse()


func close_menu() -> void:
	if Inventory.tutorial > 1 and current_menu == Menu.INVENTORY:
		Notification.hide_message()
		Inventory.tutorial = 1
	current_menu = Menu.NONE

	pause_menu.visible = false
	inventory_ui.visible = false

	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Callable(Input, "set_mouse_mode").call_deferred(Input.MOUSE_MODE_CAPTURED)
	var p = _get_player()
	if p and p.has_method("capture_mouse"):
		p.capture_mouse()
		p.call_deferred("capture_mouse")


func _on_resume_button_pressed() -> void:
	close_menu()


func _on_quit_button_pressed() -> void:
	SaveManager.save_game()
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/2d/Scenes/MainMenu.tscn")
